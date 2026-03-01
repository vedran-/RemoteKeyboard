/// Media Keys Screen
///
/// Provides media control buttons for the PC.

import 'package:flutter/material.dart';

import '../../application/services/services.dart';
import '../../domain/entities/command.dart';

class MediaScreen extends StatelessWidget {
  final CommandService commandService;
  final ConnectionService connectionService;

  const MediaScreen({
    super.key,
    required this.commandService,
    required this.connectionService,
  });

  void _sendMediaKey(BuildContext context, MediaAction action) {
    if (!connectionService.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Not connected to PC'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    commandService.sendMediaKey(action);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sent: ${_actionName(action)}'),
        duration: const Duration(milliseconds: 500),
      ),
    );
  }

  String _actionName(MediaAction action) {
    switch (action) {
      case MediaAction.playPause:
        return 'Play/Pause';
      case MediaAction.nextTrack:
        return 'Next';
      case MediaAction.prevTrack:
        return 'Previous';
      case MediaAction.volumeUp:
        return 'Volume Up';
      case MediaAction.volumeDown:
        return 'Volume Down';
      case MediaAction.mute:
        return 'Mute';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: connectionService,
      builder: (context, _) {
        final isDisconnected = !connectionService.isConnected;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Media Controls'),
          ),
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Connection warning
                if (isDisconnected)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning, color: Colors.orange, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Connect to PC to use media controls',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.orange[800],
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),

                if (isDisconnected) const SizedBox(height: 24),

                // Playback controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _MediaButton(
                      icon: Icons.skip_previous,
                      label: 'Previous',
                      onPressed: isDisconnected
                          ? null
                          : () => _sendMediaKey(context, MediaAction.prevTrack),
                    ),
                    const SizedBox(width: 16),
                    _MediaButton(
                      icon: Icons.play_arrow,
                      label: 'Play/Pause',
                      size: 80,
                      onPressed: isDisconnected
                          ? null
                          : () => _sendMediaKey(context, MediaAction.playPause),
                    ),
                    const SizedBox(width: 16),
                    _MediaButton(
                      icon: Icons.skip_next,
                      label: 'Next',
                      onPressed: isDisconnected
                          ? null
                          : () => _sendMediaKey(context, MediaAction.nextTrack),
                    ),
                  ],
                ),

                const SizedBox(height: 48),

                // Volume controls
                Text(
                  'Volume',
                  style: Theme.of(context).textTheme.titleMedium,
                ),

                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _MediaButton(
                      icon: Icons.volume_down,
                      label: 'Down',
                      onPressed: isDisconnected
                          ? null
                          : () => _sendMediaKey(context, MediaAction.volumeDown),
                    ),
                    const SizedBox(width: 16),
                    _MediaButton(
                      icon: Icons.volume_off,
                      label: 'Mute',
                      onPressed: isDisconnected
                          ? null
                          : () => _sendMediaKey(context, MediaAction.mute),
                    ),
                    const SizedBox(width: 16),
                    _MediaButton(
                      icon: Icons.volume_up,
                      label: 'Up',
                      onPressed: isDisconnected
                          ? null
                          : () => _sendMediaKey(context, MediaAction.volumeUp),
                    ),
                  ],
                ),

                const SizedBox(height: 48),

                // Info
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'These buttons control media playback on your PC',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Works with Spotify, YouTube, VLC, and other media players',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MediaButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final double? size;

  const _MediaButton({
    required this.icon,
    required this.label,
    this.onPressed,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    final isLarge = size != null;

    return Column(
      children: [
        ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            fixedSize: Size(size ?? 60, size ?? 60),
            shape: const CircleBorder(),
          ),
          child: Icon(icon, size: isLarge ? 40 : 24),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
