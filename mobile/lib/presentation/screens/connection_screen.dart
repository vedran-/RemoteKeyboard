/// Connection Screen
///
/// Allows users to discover and connect to PCs on the local network.

import 'package:flutter/material.dart';

import '../../application/services/services.dart';

class ConnectionScreen extends StatefulWidget {
  final ConnectionService connectionService;
  final NotificationService notificationService;

  const ConnectionScreen({
    super.key,
    required this.connectionService,
    required this.notificationService,
  });

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  final _ipController = TextEditingController();
  final _nameController = TextEditingController(text: 'My PC');
  final _portController = TextEditingController(text: '8765');

  @override
  void initState() {
    super.initState();
    // Start discovery when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.connectionService.startDiscovery();
    });
  }

  @override
  void dispose() {
    _ipController.dispose();
    _nameController.dispose();
    _portController.dispose();
    super.dispose();
  }

  void _showManualIpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add PC Manually'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'PC Name',
                hintText: 'e.g., Living Room PC',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ipController,
              decoration: const InputDecoration(
                labelText: 'IP Address',
                hintText: 'e.g., 192.168.1.100',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _portController,
              decoration: const InputDecoration(
                labelText: 'Port',
                hintText: '8765',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _addManualDevice();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _addManualDevice() {
    final name = _nameController.text.trim();
    final address = _ipController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 8765;

    if (name.isEmpty || address.isEmpty) {
      widget.notificationService.warning(context, 'Please enter name and IP address');
      return;
    }

    widget.connectionService.addManualDevice(name, address, port: port);
    widget.notificationService.success(context, 'Added $name at $address:$port');
  }

  void _connectToDevice(device) async {
    // Show connecting notification
    widget.notificationService.info(context, 'Connecting to ${device.name}...');

    // Attempt connection
    final success = await widget.connectionService.connectToDevice(device);

    if (success && mounted) {
      widget.notificationService.success(context, 'Connected to ${device.name}');
    } else if (mounted) {
      widget.notificationService.error(context, 'Connection failed. Check PC is running.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect to PC'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              widget.connectionService.startDiscovery();
              widget.notificationService.info(context, 'Scanning for devices...');
            },
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: widget.connectionService,
        builder: (context, _) {
          final devices = widget.connectionService.discoveredDevices;
          final connectionState = widget.connectionService.state;

          return Column(
            children: [
              // Connection status
              if (connectionState.isConnected)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: Colors.green.withOpacity(0.1),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Connected: ${connectionState.connection?.device.name ?? "PC"}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.link_off),
                        onPressed: () {
                          widget.connectionService.disconnect();
                          widget.notificationService.info(context, 'Disconnected');
                        },
                      ),
                    ],
                  ),
                ),

              // Device list
              Expanded(
                child: devices.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        itemCount: devices.length,
                        itemBuilder: (context, index) {
                          final device = devices[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: ListTile(
                              leading: const Icon(Icons.desktop_windows),
                              title: Text(device.name),
                              subtitle: Text(device.address),
                              trailing: connectionState.isConnected &&
                                      connectionState.connection?.device.id == device.id
                                  ? const Icon(Icons.check, color: Colors.green)
                                  : IconButton(
                                      icon: const Icon(Icons.connect_without_contact),
                                      onPressed: () => _connectToDevice(device),
                                    ),
                            ),
                          );
                        },
                      ),
              ),

              // Manual IP entry
              Padding(
                padding: const EdgeInsets.all(16),
                child: OutlinedButton.icon(
                  onPressed: _showManualIpDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Add PC Manually'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.wifi_off,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No PCs found',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Make sure PC app is running\nand on the same WiFi network',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              widget.connectionService.startDiscovery();
              widget.notificationService.info(context, 'Scanning for devices...');
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Scan Again'),
          ),
        ],
      ),
    );
  }
}
