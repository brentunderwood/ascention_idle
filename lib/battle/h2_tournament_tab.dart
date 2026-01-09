import 'package:flutter/material.dart';

class TournamentTab extends StatelessWidget {
  final VoidCallback? onBattleStarted;

  const TournamentTab({
    super.key,
    this.onBattleStarted,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Tournament Map (placeholder)',
              style: TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onBattleStarted,
              child: const Text('Start Tournament Battle (placeholder)'),
            ),
          ],
        ),
      ),
    );
  }
}
