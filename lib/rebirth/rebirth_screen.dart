import 'package:flutter/material.dart';

import 'next_run_tab.dart';
import 'store_tab.dart';
import 'deck_management_tab.dart';
import 'achievements_tab.dart';

/// Main widget for the Rebirth tab.
/// Shows subtabs: Next Run, Store, Deck, Achievements.
class RebirthScreen extends StatelessWidget {
  final double currentGold;
  final ValueChanged<double> onSpendGold;

  /// The current global achievement multiplier, coming from the idle game state.
  final double achievementMultiplier;

  const RebirthScreen({
    super.key,
    required this.currentGold,
    required this.onSpendGold,
    required this.achievementMultiplier,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Next Run'),
              Tab(text: 'Store'),
              Tab(text: 'Deck'),
              Tab(text: 'Achievements'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                NextRunTab(
                  currentGold: currentGold,
                  onSpendGold: onSpendGold,
                ),
                RebirthStoreTab(
                  currentGold: currentGold,
                  onSpendGold: onSpendGold,
                ),
                DeckManagementTab(
                  currentGold: currentGold,
                  onSpendGold: onSpendGold,
                ),
                AchievementsTab(
                  currentGold: currentGold,
                  onSpendGold: onSpendGold,
                  achievementMultiplier: achievementMultiplier,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
