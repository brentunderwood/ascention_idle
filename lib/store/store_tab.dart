import 'package:flutter/material.dart';

class StoreTab extends StatelessWidget {
  const StoreTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: Text(
            'Store (placeholder)',
            style: TextStyle(fontSize: 20),
          ),
        ),
      ),
    );
  }
}
