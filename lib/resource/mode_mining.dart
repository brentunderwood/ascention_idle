import 'package:flutter/material.dart';

import '../../cards/card_catalog.dart';

/// The interface that Mining-mode cards are allowed to touch.
/// Cards receive this type as their "calling context".
abstract class MiningContext {
  int get ore;
  set ore(int v);

  int get orePerSecond;
  set orePerSecond(int v);
}

class MiningModeTab extends StatefulWidget {
  const MiningModeTab({super.key});

  @override
  State<MiningModeTab> createState() => _MiningModeTabState();
}

class _MiningModeTabState extends State<MiningModeTab> implements MiningContext {
  int _ore = 0;
  int _orePerSecond = 1;

  // ---- MiningContext implementation (what cards can access) ----
  @override
  int get ore => _ore;

  @override
  set ore(int v) => setState(() => _ore = v);

  @override
  int get orePerSecond => _orePerSecond;

  @override
  set orePerSecond(int v) => setState(() => _orePerSecond = v);

  // ---- Example: play a catalog card in this mode ----
  void _playFirstMiningCard() {

  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mining Mode (placeholder)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text('Ore: $ore'),
            Text('Ore/sec: $orePerSecond'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _playFirstMiningCard,
              child: const Text('Play dummy Mining card'),
            ),
            const SizedBox(height: 8),
            const Text(
              'This button demonstrates calling a catalog card effect that\n'
                  'mutates ore/orePerSecond through the MiningContext interface.',
            ),
          ],
        ),
      ),
    );
  }
}
