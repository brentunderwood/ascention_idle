import 'package:flutter/material.dart';

import 'next_run_tab.dart';
import 'rebirth_store_tab.dart';
import 'deck_management_tab.dart';
import 'pickaxe_upgrades_tab.dart';

/// Main widget for the Rebirth tab.
/// Shows subtabs: Next Run, Store, Deck, Pickaxe.
class RebirthScreen extends StatelessWidget {
  final double currentGold;
  final ValueChanged<double> onSpendGold;

  const RebirthScreen({
    super.key,
    required this.currentGold,
    required this.onSpendGold,
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
              Tab(text: 'Pickaxe'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                NextRunTab(
                  currentGold: currentGold,
                  onSpendGold: onSpendGold,
                ),
                RebirthStoreTab(currentGold: currentGold, onSpendGold: onSpendGold),
                DeckManagementTab(
                  currentGold: currentGold,
                  onSpendGold: onSpendGold,
                ),
                PickaxeUpgradesTab(
                  currentGold: currentGold,
                  onSpendGold: onSpendGold,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
