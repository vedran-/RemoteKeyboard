/// Touchpad Screen
///
/// Provides a touch-sensitive area for controlling the PC cursor.

import 'package:flutter/material.dart';

import '../../application/services/services.dart';
import '../../domain/entities/command.dart';

class TouchpadScreen extends StatefulWidget {
  final CommandService commandService;
  final ConnectionService connectionService;

  const TouchpadScreen({
    super.key,
    required this.commandService,
    required this.connectionService,
  });

  @override
  State<TouchpadScreen> createState() => _TouchpadScreenState();
}

class _TouchpadScreenState extends State<TouchpadScreen> {
  String _sensitivityLevel = 'Normal';

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
      _showNotConnectedMessage();
      return;
    }

    widget.commandService.sendQuickClick(MouseButton.left);
  }

  void _handleSecondaryTap() {
    if (!widget.connectionService.isConnected) {
      _showNotConnectedMessage();
      return;
    }

    widget.commandService.sendQuickClick(MouseButton.right);
  }

  void _showNotConnectedMessage() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Not connected to PC'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.connectionService,
      builder: (context, _) {
        final isDisconnected = !widget.connectionService.isConnected;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Touchpad'),
            actions: [
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

              // Touchpad area
              Expanded(
                child: GestureDetector(
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
                    child: Center(
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
                          const SizedBox(height: 8),
                          Text(
                            'Tap = Left Click | Two-finger tap = Right Click',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: isDisconnected
                                      ? Theme.of(context).colorScheme.onSurfaceVariant
                                      : Theme.of(context).colorScheme.onPrimaryContainer,
                                ),
                          ),
                          if (!isDisconnected) ...[
                            const SizedBox(height: 16),
                            Chip(
                              label: Text('Sensitivity: $_sensitivityLevel'),
                              backgroundColor: Theme.of(context).colorScheme.surface,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
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
      },
    );
  }
}
