import 'package:flutter/material.dart';

/// The interface that Antimatter-mode cards are allowed to touch.
/// Add getters/setters here as antimatter mechanics come online.
abstract class AntimatterContext {
  // Example future fields:
  // int get antimatter;
  // set antimatter(int v);
}

class AntimatterModeTab extends StatefulWidget {
  const AntimatterModeTab({super.key});

  @override
  State<AntimatterModeTab> createState() => _AntimatterModeTabState();
}

class _AntimatterModeTabState extends State<AntimatterModeTab>
    implements AntimatterContext {
  // Add antimatter state here later.

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: Center(
        child: Text(
          'Antimatter Mode (placeholder)\n\n'
              'Context interface is set up; add stats later.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
