import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Misc tab for settings / meta options.
///
/// Contains a "Reset all progress" button with confirmation. This tab is
/// responsible for performing a *true factory reset* by clearing all
/// SharedPreferences keys, and then calling [onResetGame] so the host
/// screen can reset any in-memory singletons and navigate appropriately.
class MiscTab extends StatelessWidget {
  /// Callback that performs any additional reset work that is *not*
  /// stored in SharedPreferences (e.g. in-memory repositories, caches,
  /// or navigation back to a clean root screen).
  ///
  /// The MiscTab itself will already have called SharedPreferences.clear()
  /// before invoking this.
  final Future<void> Function() onResetGame;

  const MiscTab({
    super.key,
    required this.onResetGame,
  });

  Future<void> _performFactoryReset(BuildContext context) async {
    // 1. Clear ALL SharedPreferences keys. This is the important bit that
    //    makes the reset future-proof for any data stored via prefs.
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    // 2. Let the host screen clean up any in-memory state or navigate.
    await onResetGame();

    // 3. Optionally show a "done" message so the player knows it worked.
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All data has been factory reset.'),
        ),
      );
    }
  }

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
                    title: const Text('Factory reset all data?'),
                    content: const Text(
                      'This will delete ALL saved data for this app:\n\n'
                          '• Ore & refined gold\n'
                          '• Antimatter & dark matter\n'
                          '• Cards, decks, and upgrades\n'
                          '• Achievements & multipliers\n'
                          '• Rebirth progress, settings, and all other prefs\n\n'
                          'This is equivalent to uninstalling and reinstalling '
                          'the app. This cannot be undone.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text(
                          'Reset EVERYTHING',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );

                if (confirmed == true) {
                  await _performFactoryReset(context);
                }
              },
              child: const Text(
                'Factory Reset (Delete ALL Data)',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
