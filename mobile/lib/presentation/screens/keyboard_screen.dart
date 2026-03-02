/// Keyboard Screen
///
/// Provides a virtual keyboard for typing on the PC.

import 'package:flutter/material.dart';

import '../../application/services/services.dart';

class KeyboardScreen extends StatefulWidget {
  final CommandService commandService;
  final ConnectionService connectionService;
  final NotificationService notificationService;

  const KeyboardScreen({
    super.key,
    required this.commandService,
    required this.connectionService,
    required this.notificationService,
  });

  @override
  State<KeyboardScreen> createState() => _KeyboardScreenState();
}

class _KeyboardScreenState extends State<KeyboardScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _showFullKeyboard = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _sendText() {
    final text = _controller.text;
    if (text.isEmpty) return;

    if (!_checkConnection()) return;

    widget.commandService.sendTypeText(text);
    _controller.clear();

    if (mounted) {
      widget.notificationService.command(context, 'Text sent');
    }
  }

  void _sendKey(String key) {
    if (!_checkConnection()) return;

    widget.commandService.sendKeyPress(key);

    if (mounted) {
      widget.notificationService.command(context, 'Sent: $key');
    }
  }

  bool _checkConnection() {
    if (!widget.connectionService.isConnected) {
      widget.notificationService.warning(context, 'Not connected to PC');
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.connectionService,
      builder: (context, _) {
        final isDisconnected = !widget.connectionService.isConnected;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Keyboard'),
            actions: [
              IconButton(
                icon: Icon(_showFullKeyboard ? Icons.keyboard_hide : Icons.keyboard),
                onPressed: () {
                  setState(() {
                    _showFullKeyboard = !_showFullKeyboard;
                  });
                },
                tooltip: _showFullKeyboard ? 'Hide full keyboard' : 'Show full keyboard',
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
                          'Connect to PC to use keyboard',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.orange[800],
                              ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Text input field
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _controller,
                  enabled: !isDisconnected,
                  decoration: InputDecoration(
                    hintText: isDisconnected ? 'Connect to PC first' : 'Type here...',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: isDisconnected ? null : _sendText,
                    ),
                  ),
                  onSubmitted: (_) => _sendText(),
                  textInputAction: TextInputAction.send,
                ),
              ),

              // Special keys
              if (_showFullKeyboard) ...[
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Function keys row
                        _buildKeyRow([
                          ('F1', 'F1'),
                          ('F2', 'F2'),
                          ('F3', 'F3'),
                          ('F4', 'F4'),
                          ('F5', 'F5'),
                          ('F6', 'F6'),
                        ], compact: true),
                        const SizedBox(height: 8),
                        _buildKeyRow([
                          ('F7', 'F7'),
                          ('F8', 'F8'),
                          ('F9', 'F9'),
                          ('F10', 'F10'),
                          ('F11', 'F11'),
                          ('F12', 'F12'),
                        ], compact: true),
                        const SizedBox(height: 16),

                        // Navigation keys
                        _buildKeyRow([
                          ('Insert', 'Insert'),
                          ('Home', 'Home'),
                          ('PgUp', 'PageUp'),
                          ('Delete', 'Delete'),
                          ('End', 'End'),
                          ('PgDn', 'PageDown'),
                        ]),
                        const SizedBox(height: 16),

                        // Arrow keys
                        _buildArrowKeys(),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildKeyRow(List<(String, String)> keys, {bool compact = false}) {
    return Row(
      children: keys.map((key) {
        final label = key.$1;
        final value = key.$2;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: ElevatedButton(
              onPressed: () => _sendKey(value),
              style: ElevatedButton.styleFrom(
                fixedSize: Size(compact ? 50 : 60, compact ? 50 : 60),
              ),
              child: Text(label, style: TextStyle(fontSize: compact ? 12 : 14)),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildArrowKeys() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 60),
            ElevatedButton(
              onPressed: () => _sendKey('ArrowUp'),
              style: ElevatedButton.styleFrom(
                fixedSize: const Size(60, 60),
              ),
              child: const Icon(Icons.keyboard_arrow_up),
            ),
            const SizedBox(width: 60),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => _sendKey('ArrowLeft'),
              style: ElevatedButton.styleFrom(
                fixedSize: const Size(60, 60),
              ),
              child: const Icon(Icons.keyboard_arrow_left),
            ),
            ElevatedButton(
              onPressed: () => _sendKey('ArrowDown'),
              style: ElevatedButton.styleFrom(
                fixedSize: const Size(60, 60),
              ),
              child: const Icon(Icons.keyboard_arrow_down),
            ),
            ElevatedButton(
              onPressed: () => _sendKey('ArrowRight'),
              style: ElevatedButton.styleFrom(
                fixedSize: const Size(60, 60),
              ),
              child: const Icon(Icons.keyboard_arrow_right),
            ),
          ],
        ),
      ],
    );
  }
}
