import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'h1_battle_page.dart';
import 'h1_campaign_page.dart';

/// Persisted flag for "player is currently mid-battle".
const String kIsMidBattleKey = 'is_mid_battle';

class BattleTab extends StatefulWidget {
  const BattleTab({super.key});

  @override
  State<BattleTab> createState() => _BattleTabState();

  /// Call this from anywhere to enter battle (and persist it).
  static Future<void> setMidBattle(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kIsMidBattleKey, value);
  }

  /// Read persisted state (useful for non-UI logic).
  static Future<bool> getMidBattle() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(kIsMidBattleKey) ?? false;
  }
}

class _BattleTabState extends State<BattleTab> {
  bool? _isMidBattle; // null = loading

  @override
  void initState() {
    super.initState();
    _loadMidBattle();
  }

  Future<void> _loadMidBattle() async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getBool(kIsMidBattleKey) ?? false;
    if (!mounted) return;
    setState(() => _isMidBattle = val);
  }

  Future<void> _setMidBattle(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kIsMidBattleKey, value);
    if (!mounted) return;
    setState(() => _isMidBattle = value);
  }

  @override
  Widget build(BuildContext context) {
    // While loading persisted state.
    if (_isMidBattle == null) {
      return const Scaffold(
        body: SafeArea(
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    // Route automatically based on persisted state.
    if (_isMidBattle == true) {
      return BattlePage(
        onBattleEnded: () => _setMidBattle(false),
      );
    }

    return CampaignMapPage(
      // Optional hook: when you later add "start battle" from the map,
      // call this to flip to the BattlePage and persist it.
      onBattleStarted: () => _setMidBattle(true),
    );
  }
}
