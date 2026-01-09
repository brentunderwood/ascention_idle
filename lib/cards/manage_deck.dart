import 'package:flutter/material.dart';

class ManageDeckTab extends StatelessWidget {
  const ManageDeckTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: Center(
        child: Text(
          'Manage Deck (placeholder)',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
