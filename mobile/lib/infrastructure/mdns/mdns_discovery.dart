/// mDNS Discovery Service for Android
///
/// Discovers PC devices on the local network using mDNS/DNS-SD.
/// This implementation uses network scanning as mDNS fallback.

import 'dart:async';
import 'dart:io';

import '../../domain/entities/device.dart';

/// mDNS discovery service for finding PCs on local network
class MDnsDiscovery {
  bool _isDiscovering = false;
  final _deviceController = StreamController<Device>.broadcast();
  final List<Device> _discoveredDevices = [];
  
  /// Stream of discovered devices
  Stream<Device> get deviceStream => _deviceController.stream;
  
  /// List of currently discovered devices
  List<Device> get discoveredDevices => List.unmodifiable(_discoveredDevices);
  
  /// Whether currently discovering
  bool get isDiscovering => _isDiscovering;
  
  /// Start mDNS discovery
  Stream<Device> startDiscovery() {
    if (_isDiscovering) {
      print('[mDNS] Already discovering');
      return _deviceController.stream;
    }
    
    _isDiscovering = true;
    _discoveredDevices.clear();
    
    print('[mDNS] Starting discovery...');
    _startPlatformDiscovery();
    
    return _deviceController.stream;
  }
  
  /// Start platform-specific discovery
  Future<void> _startPlatformDiscovery() async {
    await _scanNetwork();
  }
  
  /// Scan local network for devices
  Future<void> _scanNetwork() async {
    try {
      final subnet = await _getLocalSubnet();
      if (subnet == null) {
        print('[mDNS] Could not determine subnet');
        _isDiscovering = false;
        return;
      }

      print('[mDNS] Scanning subnet $subnet...');
      
      // Scan IP addresses in subnet
      final scanFutures = <Future<void>>[];
      for (int i = 1; i < 255; i++) {
        final ip = '$subnet.$i';
        scanFutures.add(_probeAddress(ip));
        
        // Limit concurrent probes
        if (scanFutures.length >= 50) {
          await Future.wait(scanFutures);
          scanFutures.clear();
        }
      }
      
      // Wait for remaining probes
      if (scanFutures.isNotEmpty) {
        await Future.wait(scanFutures);
      }
      
      print('[mDNS] Scan complete, found ${_discoveredDevices.length} devices');
    } catch (e) {
      print('[mDNS] Scan error: $e');
    } finally {
      _isDiscovering = false;
    }
  }
  
  /// Get local subnet (e.g., "192.168.1")
  Future<String?> _getLocalSubnet() async {
    try {
      final interfaces = await NetworkInterface.list();
      
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
            final parts = addr.address.split('.');
            if (parts.length == 4) {
              return '${parts[0]}.${parts[1]}.${parts[2]}';
            }
          }
        }
      }
    } catch (e) {
      print('[mDNS] Error getting network: $e');
    }
    return null;
  }
  
  /// Probe a single IP address
  Future<void> _probeAddress(String ip) async {
    try {
      final socket = await Socket.connect(
        ip,
        8765,
        timeout: const Duration(milliseconds: 300),
      );
      await socket.close();
      
      final device = Device.fromDiscovery(
        name: 'PC at $ip',
        address: ip,
        port: 8765,
      );
      
      if (!_discoveredDevices.any((d) => d.address == ip)) {
        _discoveredDevices.add(device);
        _deviceController.add(device);
        print('[mDNS] Found: $ip');
      }
    } catch (_) {
      // Connection failed - ignore
    }
  }
  
  /// Stop mDNS discovery
  void stopDiscovery() {
    if (!_isDiscovering) return;
    _isDiscovering = false;
    print('[mDNS] Discovery stopped');
  }
  
  /// Add a device manually
  void addManualDevice(String name, String address, {int port = 8765}) {
    final device = Device.fromDiscovery(name: name, address: address, port: port);
    
    if (!_discoveredDevices.any((d) => d.address == address)) {
      _discoveredDevices.add(device);
      _deviceController.add(device);
      print('[mDNS] Added manual: $name at $address');
    }
  }
  
  /// Clear discovered devices
  void clearDevices() {
    _discoveredDevices.clear();
  }
  
  /// Dispose resources
  void dispose() {
    stopDiscovery();
    _deviceController.close();
  }
}
