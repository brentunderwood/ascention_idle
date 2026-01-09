import 'package:flutter/material.dart';

import 'h2_campaign_map_tab.dart';
import 'h2_tournament_tab.dart';

class CampaignMapPage extends StatelessWidget {
  /// Optional: later, when map nodes start battles, call this.
  final VoidCallback? onBattleStarted;

  const CampaignMapPage({
    super.key,
    this.onBattleStarted,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Campaign'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.map), text: 'Main Campaign'),
              Tab(icon: Icon(Icons.emoji_events), text: 'Tournament'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // ✅ Main Campaign tab now owns the map.
            MainCampaignTab(onBattleStarted: onBattleStarted),

            TournamentTab(onBattleStarted: onBattleStarted),
          ],
        ),
      ),
    );
  }
}
