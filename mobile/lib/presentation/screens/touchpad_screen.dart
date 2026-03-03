/// Touchpad Screen with Screen Capture Display
///
/// Provides a touch-sensitive area for controlling the PC cursor.
/// Can display screen capture from PC when streaming is enabled.

import 'dart:convert';
import 'dart:math';

import 'package:flutter/gestures.dart';
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

  // Pinch zoom state
  double _currentZoom = 1.0;
  double _initialZoom = 1.0;

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

  /// Handle pinch zoom gesture
  void _handleScaleStart(ScaleStartDetails details) {
    _initialZoom = _currentZoom;
    // Store initial focal point for pan calculation
    _lastFocalPoint = details.focalPoint;
  }

  /// Handle pinch zoom gesture (and pan for mouse control)
  void _handleScaleUpdate(ScaleUpdateDetails details) {
    if (!widget.screenStreamService.isStreaming) return;

    // Multi-touch (pointerCount > 1) = pinch zoom
    if (details.pointerCount > 1) {
      // Calculate new zoom level based on pinch gesture
      final newZoom = (_initialZoom * details.scale).clamp(0.1, 5.0);

      setState(() {
        _currentZoom = newZoom;
      });

      // Update service with new zoom level (don't notify server continuously during gesture)
      widget.screenStreamService.setZoomLevel(newZoom, notifyServer: false);
    }
    // Single touch (pointerCount == 1) = pan for mouse control
    else {
      // Calculate drag delta from focal point movement
      final delta = details.focalPoint - _lastFocalPoint;
      _lastFocalPoint = details.focalPoint;

      if (!widget.connectionService.isConnected) return;

      final dx = (delta.dx * _sensitivity).round();
      final dy = (delta.dy * _sensitivity).round();

      widget.commandService.sendMouseMove(dx, dy);
    }
  }

  /// Handle pinch gesture end - send final zoom to server
  void _handleScaleEnd(ScaleEndDetails details) {
    // Only handle zoom if pointer count > 1 (multi-touch pinch)
    if (details.pointerCount > 1 && widget.screenStreamService.isStreaming) {
      // Round zoom to nearest 0.25 increment for cleaner values
      final roundedZoom = ((_currentZoom * 4).round() / 4).clamp(0.1, 5.0);

      setState(() {
        _currentZoom = roundedZoom;
      });

      // Send final zoom level to server
      widget.screenStreamService.setZoomLevel(roundedZoom, notifyServer: true);

      widget.notificationService.info(
        context,
        'Zoom: ${(roundedZoom * 100).toInt()}%',
        duration: const Duration(milliseconds: 800),
      );
    }
  }

  // Store last focal point for pan delta calculation
  Offset _lastFocalPoint = Offset.zero;

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
      double width, height;

      if (_touchpadWidth != null && _touchpadHeight != null) {
        // Use actual measured dimensions
        width = _touchpadWidth!;
        height = _touchpadHeight!;
      } else {
        // Fallback to estimated dimensions
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;
        width = screenWidth * 0.85;
        height = screenHeight * 0.35;
      }

      final viewportWidth = width.round();
      final viewportHeight = height.round();

      print('[Touchpad] Container: ${_touchpadWidth?.toStringAsFixed(0) ?? '?'}x${_touchpadHeight?.toStringAsFixed(0) ?? '?'}');
      print('[Touchpad] Viewport: ${viewportWidth}x$viewportHeight (aspect: ${(viewportWidth / viewportHeight).toStringAsFixed(2)}:1)');

      widget.screenStreamService.startStreaming(
        viewportWidth: viewportWidth,
        viewportHeight: viewportHeight,
        zoomLevel: _currentZoom,
      );
      widget.notificationService.info(context, 'Screen streaming started (${viewportWidth}x$viewportHeight)');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDisconnected = !widget.connectionService.isConnected;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Touchpad'),
        actions: [
          // Zoom level indicator and reset (only when streaming)
          if (widget.screenStreamService.isStreaming)
            ListenableBuilder(
              listenable: widget.screenStreamService,
              builder: (context, _) {
                final zoomPercent = (widget.screenStreamService.zoomLevel * 100).toInt();
                return GestureDetector(
                  onTap: () {
                    // Reset zoom on tap
                    setState(() {
                      _currentZoom = 1.0;
                    });
                    widget.screenStreamService.resetZoom();
                    widget.notificationService.info(context, 'Zoom reset to 100%');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Zoom',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                        Text(
                          '$zoomPercent%',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
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

                    return Listener(
                      onPointerSignal: (event) {
                        // Handle mouse wheel for zoom (only when streaming)
                        if (!isStreaming) return;

                        if (event is PointerScrollEvent) {
                          // Determine zoom direction from scroll
                          final scrollDelta = event.scrollDelta.dy;

                          // Scroll up (negative) = zoom in, Scroll down (positive) = zoom out
                          if (scrollDelta < 0) {
                            widget.screenStreamService.zoomIn(step: 0.1);
                          } else if (scrollDelta > 0) {
                            widget.screenStreamService.zoomOut(step: 0.1);
                          }

                          // Show zoom level feedback
                          final newZoom = widget.screenStreamService.zoomLevel;
                          widget.notificationService.info(
                            context,
                            'Zoom: ${(newZoom * 100).toInt()}%',
                            duration: const Duration(milliseconds: 800),
                          );
                        }
                      },
                      child: GestureDetector(
                        onScaleStart: _handleScaleStart,
                        onScaleUpdate: _handleScaleUpdate,
                        onScaleEnd: _handleScaleEnd,
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
                                    fit: BoxFit.contain,  // Respect aspect ratio, scale to fit
                                    // No explicit width/height - let parent container control sizing
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
                            // Cursor indicator (if streaming) - CENTERED in touchpad
                            // Since server centers cursor in capture, and capture fills touchpad,
                            // the cursor (and thus red dot) should be at touchpad center
                            if (isStreaming && screenFrame != null)
                              Center(  // Center in the Stack (which fills touchpad)
                                child: Container(
                                  width: 7,    // Reduced from 20 for less obstruction
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.7),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 1),
                                  ),
                                ),
                              ),
                          ],
                        ),
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
