import 'package:flutter/material.dart';

import '../battle/h0_battle_tab.dart';
import '../resource/generate_tab.dart';
import '../cards/cards_tab.dart';
import '../stats/stats_tab.dart';
import '../store/store_tab.dart';

class IdleGameScreen extends StatefulWidget {
  const IdleGameScreen({super.key});

  @override
  State<IdleGameScreen> createState() => _IdleGameScreenState();
}

class _IdleGameScreenState extends State<IdleGameScreen> {
  int _index = 0;

  late final List<Widget> _tabs = const [
    BattleTab(),
    GenerateTab(),
    CardsTab(),
    StatsTab(),
    StoreTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Keeps tab state stable and avoids rebuilding heavy trees later
      body: IndexedStack(
        index: _index,
        children: _tabs,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed, // needed for 5 items
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.sports_mma), // if this icon isn't available, see note below
            label: 'Battle',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bolt),
            label: 'Generate',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.style),
            label: 'Cards',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Stats',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.store),
            label: 'Store',
          ),
        ],
      ),
    );
  }
}
