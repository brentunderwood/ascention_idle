import 'package:flutter/material.dart';

import 'activity_tab.dart';
import 'store_tab.dart';
import 'deck_management_tab.dart';
import 'achievements_tab.dart';
import '../tutorial_manager.dart';

/// Main widget for the Rebirth tab.
/// Shows subtabs: Store, Deck, Achievements, Next Run.
class RebirthScreen extends StatefulWidget {
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
  State<RebirthScreen> createState() => _RebirthScreenState();
}

class _RebirthScreenState extends State<RebirthScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);

    // Initial tab is Store (index 0).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      TutorialManager.instance.onRebirthStoreShown(context);
    });
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;

    if (!mounted) return;

    final index = _tabController.index;
    if (index == 0) {
      // Store
      TutorialManager.instance.onRebirthStoreShown(context);
    } else if (index == 1) {
      // Deck
      TutorialManager.instance.onDeckTabShown(context);
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Store'),
            Tab(text: 'Deck'),
            Tab(text: 'Achievements'),
            Tab(text: 'Mode'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              RebirthStoreTab(
                currentGold: widget.currentGold,
                onSpendGold: widget.onSpendGold,
              ),
              DeckManagementTab(
                currentGold: widget.currentGold,
                onSpendGold: widget.onSpendGold,
              ),
              AchievementsTab(
                currentGold: widget.currentGold,
                onSpendGold: widget.onSpendGold,
                achievementMultiplier: widget.achievementMultiplier,
              ),
              ActivityTab(
                currentGold: widget.currentGold,
                onSpendGold: widget.onSpendGold,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
