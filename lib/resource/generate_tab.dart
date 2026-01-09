import 'package:flutter/material.dart';

import 'mode_antimatter.dart';
import 'mode_mining.dart';

class GenerateTab extends StatelessWidget {
  const GenerateTab({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2, // add more modes later
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Generate'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.terrain), text: 'Mining'),
              Tab(icon: Icon(Icons.auto_awesome), text: 'Antimatter'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            MiningModeTab(),
            AntimatterModeTab(),
          ],
        ),
      ),
    );
  }
}
