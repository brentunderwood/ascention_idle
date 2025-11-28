import 'package:flutter/material.dart';

/// Placeholder Achievements tab.
///
/// For now this just shows some mock achievements as disabled cards.
/// You can later hook this up to real achievement data and logic.
class AchievementsTab extends StatelessWidget {
  final double currentGold;
  final ValueChanged<double> onSpendGold;

  const AchievementsTab({
    super.key,
    required this.currentGold,
    required this.onSpendGold,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.3),
      width: double.infinity,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Achievements',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [
                  Shadow(
                    blurRadius: 4,
                    color: Colors.black54,
                    offset: Offset(1, 1),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Track long-term goals and unlock powerful bonuses.\n'
                  'This system is not implemented yet.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 16),

            // Example placeholder cards — purely cosmetic for now.
            _buildAchievementCard(
              title: 'First Rebirth',
              description: 'Perform your first rebirth.',
              progressText: '0 / 1',
              unlocked: false,
            ),
            const SizedBox(height: 8),
            _buildAchievementCard(
              title: 'Ore Hoarder',
              description: 'Accumulate 1,000,000 gold ore in a single run.',
              progressText: '0 / 1,000,000',
              unlocked: false,
            ),
            const SizedBox(height: 8),
            _buildAchievementCard(
              title: 'Deck Master',
              description: 'Fill a deck to its maximum card capacity.',
              progressText: '0 / 1',
              unlocked: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAchievementCard({
    required String title,
    required String description,
    required String progressText,
    required bool unlocked,
  }) {
    final Color borderColor = unlocked ? Colors.amberAccent : Colors.white24;
    final Color bgColor =
    unlocked ? Colors.white.withOpacity(0.18) : Colors.white.withOpacity(0.06);
    final Color titleColor = unlocked ? Colors.amberAccent : Colors.white;
    final IconData icon = unlocked ? Icons.check_circle : Icons.lock;

    return Card(
      color: bgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 32,
              color: titleColor,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Progress: $progressText',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white60,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
