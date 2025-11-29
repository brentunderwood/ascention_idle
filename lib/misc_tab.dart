import 'package:flutter/material.dart';

/// Misc tab for settings / meta options.
///
/// Right now it contains a "Reset all progress" button with confirmation.
class MiscTab extends StatelessWidget {
  /// Callback that actually performs the reset (clears prefs, restarts, etc.).
  /// This is provided by IdleGameScreen so it has access to navigation.
  final Future<void> Function() onResetGame;

  const MiscTab({
    super.key,
    required this.onResetGame,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Misc options',
            style: TextStyle(
              fontSize: 18,
              color: Colors.white,
              shadows: [
                Shadow(
                  blurRadius: 4,
                  color: Colors.black54,
                  offset: Offset(1, 1),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // BIG RED BUTTON OF DOOM
          SizedBox(
            width: 260,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Reset all progress?'),
                    content: const Text(
                      'This will delete ALL saved data for this game:\n\n'
                          '• Ore & gold\n'
                          '• Cards & decks\n'
                          '• Achievements & multipliers\n'
                          '• Rebirth progress and settings\n\n'
                          'This cannot be undone.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text(
                          'Reset',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );

                if (confirmed == true) {
                  await onResetGame();
                }
              },
              child: const Text(
                'Reset ALL Progress',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
