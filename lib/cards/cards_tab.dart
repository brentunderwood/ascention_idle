import 'package:flutter/material.dart';

import 'buy_packs.dart';
import 'manage_deck.dart';

class CardsTab extends StatelessWidget {
  const CardsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Cards'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.shopping_bag), text: 'Buy Packs'),
              Tab(icon: Icon(Icons.view_list), text: 'Manage Deck'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            BuyPacksTab(),
            ManageDeckTab(),
          ],
        ),
      ),
    );
  }
}
