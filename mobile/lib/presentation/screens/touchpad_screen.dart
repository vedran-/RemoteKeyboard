/// Touchpad Screen with Screen Capture Display
///
/// Provides a touch-sensitive area for controlling the PC cursor.
/// Can display screen capture from PC when streaming is enabled.

import 'dart:convert';

import 'package:flutter/material.dart';

import '../../application/services/services.dart';
import '../../domain/entities/command.dart';

class TouchpadScreen extends StatefulWidget {
  final CommandService commandService;
  final ConnectionService connectionService;
  final NotificationService notificationService;
  final ScreenStreamService screenStreamService;

  const TouchpadScreen({
    super.key,
    required this.commandService,
    required this.connectionService,
    required this.notificationService,
    required this.screenStreamService,
  });

  @override
  State<TouchpadScreen> createState() => _TouchpadScreenState();
}

class _TouchpadScreenState extends State<TouchpadScreen> {
  String _sensitivityLevel = 'Normal';
  
  // Store touchpad container dimensions for screen streaming
  double? _touchpadWidth;
  double? _touchpadHeight;

  double get _sensitivity {
    switch (_sensitivityLevel.toLowerCase()) {
      case 'low':
        return 0.5;
      case 'normal':
        return 1.0;
      case 'high':
        return 1.5;
      case 'very high':
        return 2.0;
      default:
        return 1.0;
    }
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (!widget.connectionService.isConnected) return;

    final dx = (details.delta.dx * _sensitivity).round();
    final dy = (details.delta.dy * _sensitivity).round();

    widget.commandService.sendMouseMove(dx, dy);
  }

  void _handleTap() {
    if (!widget.connectionService.isConnected) {
      widget.notificationService.warning(context, 'Not connected to PC');
      return;
    }

    widget.commandService.sendQuickClick(MouseButton.left);
    widget.notificationService.command(context, 'Left click');
  }

  void _handleSecondaryTap() {
    if (!widget.connectionService.isConnected) {
      widget.notificationService.warning(context, 'Not connected to PC');
      return;
    }

    widget.commandService.sendQuickClick(MouseButton.right);
    widget.notificationService.command(context, 'Right click');
  }

  void _toggleScreenStreaming() {
    if (widget.screenStreamService.isStreaming) {
      widget.screenStreamService.stopStreaming();
      widget.notificationService.info(context, 'Screen streaming stopped');
    } else {
      // Use actual touchpad container dimensions if available
      int captureWidth, captureHeight;
      
      if (_touchpadWidth != null && _touchpadHeight != null) {
        // Use actual measured dimensions
        captureWidth = _touchpadWidth!.round().clamp(200, 800);
        captureHeight = _touchpadHeight!.round().clamp(200, 800);
        print('[Touchpad] Using measured dimensions: ${captureWidth}x$captureHeight');
      } else {
        // Fallback to estimated dimensions
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;
        captureWidth = (screenWidth * 0.85).round().clamp(200, 800);
        captureHeight = (screenHeight * 0.35).round().clamp(200, 800);
        print('[Touchpad] Using fallback dimensions: ${captureWidth}x$captureHeight');
      }

      widget.screenStreamService.startStreaming(
        captureWidth: captureWidth,
        captureHeight: captureHeight,
        maxDimension: 400,  // Server will downscale if larger
      );
      widget.notificationService.info(context, 'Screen streaming started (${captureWidth}x$captureHeight)');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDisconnected = !widget.connectionService.isConnected;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Touchpad'),
        actions: [
          // Screen streaming toggle
          IconButton(
            icon: Icon(
              widget.screenStreamService.isStreaming
                  ? Icons.screen_share
                  : Icons.screen_share_outlined,
            ),
            onPressed: _toggleScreenStreaming,
            tooltip: widget.screenStreamService.isStreaming
                ? 'Stop screen streaming'
                : 'Start screen streaming',
          ),
          // Sensitivity control
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                _sensitivityLevel = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'Low', child: Text('Low')),
              const PopupMenuItem(value: 'Normal', child: Text('Normal')),
              const PopupMenuItem(value: 'High', child: Text('High')),
              const PopupMenuItem(value: 'Very High', child: Text('Very High')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Connection warning
          if (isDisconnected)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.orange.withOpacity(0.1),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Connect to PC to use touchpad',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.orange[800],
                          ),
                    ),
                  ),
                ],
              ),
            ),

          // Touchpad area with optional screen capture
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Measure actual touchpad container size (minus margins)
                _touchpadWidth = constraints.maxWidth - 32; // 16px margin on each side
                _touchpadHeight = constraints.maxHeight - 32;
                
                return ListenableBuilder(
                  listenable: widget.screenStreamService,
                  builder: (context, _) {
                    final screenFrame = widget.screenStreamService.currentFrame;
                    final isStreaming = widget.screenStreamService.isStreaming;

                    // Debug logging
                    print('[Touchpad] Container size: ${_touchpadWidth}x${_touchpadHeight}');
                    print('[Touchpad] isStreaming: $isStreaming, hasFrame: ${screenFrame != null}');
                    if (screenFrame != null) {
                      print('[Touchpad] Frame size: ${screenFrame.captureWidth}x${screenFrame.captureHeight}, data length: ${screenFrame.data.length}');
                      try {
                        final imageData = base64Decode(screenFrame.data);
                        print('[Touchpad] Decoded image: ${imageData.length} bytes');
                      } catch (e) {
                        print('[Touchpad] ERROR decoding image: $e');
                      }
                    }

                    return GestureDetector(
                      onPanUpdate: _handlePanUpdate,
                      onTap: _handleTap,
                      onSecondaryTap: _handleSecondaryTap,
                      child: Container(
                        margin: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDisconnected
                              ? Theme.of(context).colorScheme.surfaceContainerHighest
                              : Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDisconnected
                                ? Theme.of(context).colorScheme.outlineVariant
                                : Theme.of(context).colorScheme.primary,
                            width: 2,
                          ),
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Screen capture image (if streaming and frame received)
                            if (isStreaming && screenFrame != null && widget.screenStreamService.decodedImage != null)
                              Container(
                                color: Colors.black,  // Background color for letterboxing
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: RawImage(
                                    image: widget.screenStreamService.decodedImage,  // Use cached decoded image
                                    fit: BoxFit.contain,  // Respect aspect ratio
                                    width: screenFrame.captureWidth.toDouble(),
                                    height: screenFrame.captureHeight.toDouble(),
                                  ),
                                ),
                              ),
                            // Overlay for touch controls
                            if (!isStreaming)
                              Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.touch_app,
                                      size: 64,
                                      color: isDisconnected
                                          ? Theme.of(context).colorScheme.onSurfaceVariant
                                          : Theme.of(context).colorScheme.primary,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      isDisconnected
                                          ? 'Connect to PC first'
                                          : 'Touch and drag to move cursor',
                                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                            color: isDisconnected
                                                ? Theme.of(context).colorScheme.onSurfaceVariant
                                                : Theme.of(context).colorScheme.onPrimaryContainer,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            // Cursor indicator (if streaming) - ALWAYS CENTERED
                            // Server always centers cursor in capture, so red dot is always in middle
                            if (isStreaming && screenFrame != null)
                              Positioned(
                                left: screenFrame.captureWidth / 2 - 10,  // Center X (minus half dot size)
                                top: screenFrame.captureHeight / 2 - 10,  // Center Y
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.7),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Mouse buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isDisconnected ? null : _handleTap,
                    icon: const Icon(Icons.mouse),
                    label: const Text('Left Click'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isDisconnected ? null : _handleSecondaryTap,
                    icon: const Icon(Icons.mouse),
                    label: const Text('Right Click'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
