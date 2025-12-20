// ===============================
// stats/stats_tab.dart (FULL FILE)
// ===============================
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../cards/player_collection_repository.dart';
import '../cards/game_card_models.dart';
import '../cards/card_catalog.dart';
import '../utilities/display_functions.dart';

class StatsTab extends StatefulWidget {
  const StatsTab({super.key});

  @override
  State<StatsTab> createState() => _StatsTabState();
}

// -------------------------
// Key strings (MUST match idle_game_screen.dart)
// -------------------------

/// Shared/global keys
const String kGoldKey = 'gold';
const String kTotalRefinedGoldKey = 'total_refined_gold';
const String kDarkMatterKey = 'dark_matter';
const String kAchievementMultiplierKey = 'achievement_multiplier';
const String kMaxGoldMultiplierKey = 'max_gold_multiplier';
const String kTotalClicksKey = 'total_clicks';
const String kTotalManualClickCyclesKey = 'total_manual_click_cycles';
const String kMaxCardCountKey = 'max_card_count';

/// Per-mode/per-run keys (base; antimatter uses prefix)
const String kGoldOreKey = 'gold_ore';
const String kTotalGoldOreKey = 'total_gold_ore';
const String kOverallMultiplierKey = 'overall_multiplier';
const String kClicksThisRunKey = 'clicks_this_run';
const String kManualClickCyclesThisRunKey = 'manual_click_cycles_this_run';

/// Antimatter per-mode keys (also stored per-mode; we access via prefix mapping)
const String kAntimatterKey = 'antimatter';

/// Monster hunter keys (global keys used by monster mode)
const String kMonsterPlayerLevelKey = 'monster_player_level';
const String kMonsterPlayerExperienceKey = 'monster_player_experience';
const String kMonsterKillCountKey = 'monster_kill_count';

/// Mode prefix helper:
/// - gold: baseKey
/// - antimatter: 'antimatter_<baseKey>'
String _modeKey(String baseKey, String mode) {
  if (mode == 'antimatter') return 'antimatter_$baseKey';
  return baseKey; // gold / default
}

class _StatsSnapshot {
  // Meta/global
  final double totalRefinedGold;
  final double darkMatterTotal;
  final double achievementMultiplier;
  final double maxGoldSingleRebirthValue;
  final int totalClicksAllTime;
  final double totalManualClickCyclesAllTime;
  final int maxCardCount;

  // Monster hunter
  final int monstersKilled;
  final int hunterLevel;
  final int hunterExp;

  // Gold-mode (per-run/per-mode)
  final double goldTotalOreThisRebirth;
  final double goldOverallMultiplier; // stored overall (without hunter boost)
  final int goldClicksThisRun;
  final double goldRefinedGoldFromNuggetsThisRun; // stored as manualClickCyclesThisRun

  // Antimatter-mode (per-run/per-mode)
  final double antiAntimatterCurrentRun;
  final double antiOverallMultiplier; // stored overall (may historically include max-gold derived)

  const _StatsSnapshot({
    required this.totalRefinedGold,
    required this.darkMatterTotal,
    required this.achievementMultiplier,
    required this.maxGoldSingleRebirthValue,
    required this.totalClicksAllTime,
    required this.totalManualClickCyclesAllTime,
    required this.maxCardCount,
    required this.monstersKilled,
    required this.hunterLevel,
    required this.hunterExp,
    required this.goldTotalOreThisRebirth,
    required this.goldOverallMultiplier,
    required this.goldClicksThisRun,
    required this.goldRefinedGoldFromNuggetsThisRun,
    required this.antiAntimatterCurrentRun,
    required this.antiOverallMultiplier,
  });
}

class _StatsTabState extends State<StatsTab> {
  late Future<_StatsSnapshot> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadSnapshot();
  }

  Future<_StatsSnapshot> _loadSnapshot() async {
    final prefs = await SharedPreferences.getInstance();

    // ---- Meta/global ----
    final totalRefinedGold = prefs.getDouble(kTotalRefinedGoldKey) ?? 0.0;
    final darkMatterTotal = prefs.getDouble(kDarkMatterKey) ?? 0.0;
    final achievementMultiplier = prefs.getDouble(kAchievementMultiplierKey) ?? 1.0;

    // Misnamed in state: kMaxGoldMultiplierKey is actually "max gold (single rebirth)" value
    final maxGoldSingleRebirthValue = prefs.getDouble(kMaxGoldMultiplierKey) ?? 1.0;

    final totalClicksAllTime = prefs.getInt(kTotalClicksKey) ?? 0;
    final totalManualClickCyclesAllTime =
        prefs.getDouble(kTotalManualClickCyclesKey) ?? 0.0;
    final maxCardCount = prefs.getInt(kMaxCardCountKey) ?? 0;

    // ---- Monster hunter ----
    final monstersKilled = prefs.getInt(kMonsterKillCountKey) ?? 0;
    final hunterLevel = prefs.getInt(kMonsterPlayerLevelKey) ?? 1;
    final hunterExp = prefs.getInt(kMonsterPlayerExperienceKey) ?? 0;

    // ---- Gold mode (base keys) ----
    const goldMode = 'gold';
    final goldTotalOreThisRebirth =
        prefs.getDouble(_modeKey(kTotalGoldOreKey, goldMode)) ?? 0.0;
    final goldOverallMultiplier =
        prefs.getDouble(_modeKey(kOverallMultiplierKey, goldMode)) ?? 1.0;
    final goldClicksThisRun = prefs.getInt(_modeKey(kClicksThisRunKey, goldMode)) ?? 0;

    // Refined gold from nuggets this run is stored in manual_click_cycles_this_run
    final goldRefinedGoldFromNuggetsThisRun =
        prefs.getDouble(_modeKey(kManualClickCyclesThisRunKey, goldMode)) ?? 0.0;

    // ---- Antimatter mode (prefixed keys) ----
    const antiMode = 'antimatter';
    final antiAntimatterCurrentRun =
        prefs.getDouble(_modeKey(kAntimatterKey, antiMode)) ?? 0.0;
    final antiOverallMultiplier =
        prefs.getDouble(_modeKey(kOverallMultiplierKey, antiMode)) ?? 1.0;

    return _StatsSnapshot(
      totalRefinedGold: totalRefinedGold,
      darkMatterTotal: darkMatterTotal,
      achievementMultiplier: achievementMultiplier,
      maxGoldSingleRebirthValue: maxGoldSingleRebirthValue,
      totalClicksAllTime: totalClicksAllTime,
      totalManualClickCyclesAllTime: totalManualClickCyclesAllTime,
      maxCardCount: maxCardCount,
      monstersKilled: monstersKilled,
      hunterLevel: hunterLevel,
      hunterExp: hunterExp,
      goldTotalOreThisRebirth: goldTotalOreThisRebirth,
      goldOverallMultiplier: goldOverallMultiplier,
      goldClicksThisRun: goldClicksThisRun,
      goldRefinedGoldFromNuggetsThisRun: goldRefinedGoldFromNuggetsThisRun,
      antiAntimatterCurrentRun: antiAntimatterCurrentRun,
      antiOverallMultiplier: antiOverallMultiplier,
    );
  }

  // Best-effort extraction without assuming exact OwnedCard field names.
  int _ownedCardLevel(OwnedCard c) {
    try {
      final d = c as dynamic;
      final dynamic v = (d.level ?? d.cardLevel ?? d.upgradeLevel ?? d.count ?? 0);

      if (v is int) return v;
      if (v is double) return v.floor();
      if (v is num) return v.toInt();
      return 0;
    } catch (_) {
      return 0;
    }
  }

  int _sumCardLevels(List<OwnedCard> cards) {
    int sum = 0;
    for (final c in cards) {
      sum += _ownedCardLevel(c);
    }
    return sum;
  }

  int _maxCardLevel(List<OwnedCard> cards) {
    int mx = 0;
    for (final c in cards) {
      mx = math.max(mx, _ownedCardLevel(c));
    }
    return mx;
  }

  Widget _sectionCard({
    required String title,
    required List<Widget> rows,
  }) {
    return Card(
      elevation: 0,
      color: Colors.black.withOpacity(0.25),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [
                  Shadow(
                    blurRadius: 4,
                    color: Colors.black54,
                    offset: Offset(1, 1),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            ...rows,
          ],
        ),
      ),
    );
  }

  Widget _statRow({
    required String label,
    required String value,
    bool isLast = false,
    bool isIndented = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: isIndented ? 14.0 : 0),
                  child: Text(
                    label,
                    softWrap: true,
                    style: TextStyle(
                      fontSize: 15,
                      color: isIndented ? Colors.white70 : Colors.white,
                      shadows: const [
                        Shadow(
                          blurRadius: 3,
                          color: Colors.black54,
                          offset: Offset(1, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 170),
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  softWrap: true,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        blurRadius: 3,
                        color: Colors.black54,
                        offset: Offset(1, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (!isLast) ...[
            const SizedBox(height: 10),
            Divider(
              height: 1,
              thickness: 1,
              color: Colors.white.withOpacity(0.10),
            ),
          ],
        ],
      ),
    );
  }

  double _maxGoldDerivedMultiplier(double maxGoldSingleRebirth) {
    final safe = maxGoldSingleRebirth <= 0 ? 1.0 : maxGoldSingleRebirth;
    return 1.0 + (math.log(safe) / math.log(1000.0));
  }

  double _chronoEpochMultiplierGold({
    required double overallStored,
    required double achievement,
    required double maxGoldDerived,
  }) {
    final denom =
        (achievement <= 0 ? 1.0 : achievement) * (maxGoldDerived <= 0 ? 1.0 : maxGoldDerived);
    if (denom == 0) return overallStored;
    return overallStored / denom;
  }

  double _chronoEpochMultiplierAntimatterNoMax({
    required double overallNoMax,
    required double achievement,
  }) {
    final denom = (achievement <= 0 ? 1.0 : achievement);
    if (denom == 0) return overallNoMax;
    return overallNoMax / denom;
  }

  double _monsterHunterGoldMult(int hunterLevel) {
    final lvl = hunterLevel <= 0 ? 1 : hunterLevel;
    return lvl.toDouble();
  }

  double _monsterHunterAntimatterMult(int hunterLevel) {
    final double L = math.max(1.0, hunterLevel.toDouble());
    final double m = math.pow(L, math.log(L)).toDouble();
    if (!m.isFinite || m <= 0) return 1.0;
    return m;
  }

  int _nuggetsFoundThisRunFromRefinedGold(double refinedGoldFromNuggets) {
    final x = refinedGoldFromNuggets.isFinite ? refinedGoldFromNuggets : 0.0;
    final safe = x < 0 ? 0.0 : x;
    return math.sqrt(safe * 2.0).floor();
  }

  @override
  Widget build(BuildContext context) {
    final List<OwnedCard> ownedCards =
        PlayerCollectionRepository.instance.allOwnedCards;

    final int totalCardLevels = _sumCardLevels(ownedCards);
    final int maxCardLevel = _maxCardLevel(ownedCards);

    final int ownedCount = ownedCards.length;
    final int totalGameCards = CardCatalog.allCards.length;

    final String ownedFraction = '$ownedCount / $totalGameCards';
    final String ownedPercent = totalGameCards == 0
        ? '—'
        : '${(ownedCount / totalGameCards * 100).toStringAsFixed(1)}%';

    return FutureBuilder<_StatsSnapshot>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SafeArea(
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snap.hasData) {
          return SafeArea(
            child: Center(
              child: Text(
                'Failed to load stats.',
                style: TextStyle(color: Colors.white.withOpacity(0.9)),
              ),
            ),
          );
        }

        final s = snap.data!;

        // Derived multipliers
        final double maxGoldSingleRebirth = s.maxGoldSingleRebirthValue;
        final double maxGoldMultDerived = _maxGoldDerivedMultiplier(maxGoldSingleRebirth);

        final double hunterGoldMult = _monsterHunterGoldMult(s.hunterLevel);
        final double hunterAntiMult = _monsterHunterAntimatterMult(s.hunterLevel);

        // Gold: chrono epoch from stored overall (which is then boosted by hunter level in gameplay)
        final double chronoEpochGold = _chronoEpochMultiplierGold(
          overallStored: s.goldOverallMultiplier,
          achievement: s.achievementMultiplier,
          maxGoldDerived: maxGoldMultDerived,
        );
        final double goldOverallEffective = s.goldOverallMultiplier * hunterGoldMult;

        // Antimatter: remove max-gold-derived from the stored overall, then apply hunter formula
        final double antiOverallNoMax =
        (maxGoldMultDerived <= 0) ? s.antiOverallMultiplier : (s.antiOverallMultiplier / maxGoldMultDerived);

        final double chronoEpochAnti = _chronoEpochMultiplierAntimatterNoMax(
          overallNoMax: antiOverallNoMax,
          achievement: s.achievementMultiplier,
        );

        final double antiOverallEffective = antiOverallNoMax * hunterAntiMult;

        // Nuggets
        final double refinedGoldFromNuggetsThisRun = s.goldRefinedGoldFromNuggetsThisRun;
        final int nuggetsFoundThisRun =
        _nuggetsFoundThisRunFromRefinedGold(refinedGoldFromNuggetsThisRun);

        final String antimatterDisplay = factorialDisplay(s.antiAntimatterCurrentRun);

        // Monster hunter EXP
        final int hunterLvlSafe = (s.hunterLevel <= 0) ? 1 : s.hunterLevel;
        final int expToNext = (hunterLvlSafe + 1) * (hunterLvlSafe + 1) * (hunterLvlSafe + 1);

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _sectionCard(
                  title: 'Meta',
                  rows: [
                    _statRow(
                      label: 'Total refined gold',
                      value: displayNumber(s.totalRefinedGold),
                    ),
                    _statRow(
                      label: 'Total dark matter',
                      value: displayNumber(s.darkMatterTotal),
                    ),
                    _statRow(
                      label: 'Owned cards',
                      value: '$ownedFraction  ($ownedPercent)',
                    ),
                    _statRow(
                      label: 'Total card levels',
                      value: totalCardLevels.toString(),
                    ),
                    _statRow(
                      label: 'Max card level',
                      value: maxCardLevel.toString(),
                    ),
                    _statRow(
                      label: 'Max card count (any single card)',
                      value: s.maxCardCount.toString(),
                    ),
                    _statRow(
                      label: 'Total manual click cycles (all time)',
                      value: displayNumber(s.totalManualClickCyclesAllTime),
                    ),
                    _statRow(
                      label: 'Clicks (all time)',
                      value: s.totalClicksAllTime.toString(),
                      isLast: true,
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                _sectionCard(
                  title: 'Monster Hunter',
                  rows: [
                    _statRow(
                      label: 'Monsters killed',
                      value: s.monstersKilled.toString(),
                    ),
                    _statRow(
                      label: 'Hunter Lv',
                      value: hunterLvlSafe.toString(),
                    ),
                    _statRow(
                      label: 'Exp / Exp to next level',
                      value: '${s.hunterExp} / $expToNext',
                      isLast: true,
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                _sectionCard(
                  title: 'Gold Mode',
                  rows: [
                    _statRow(
                      label: 'Total ore this rebirth',
                      value: displayNumber(s.goldTotalOreThisRebirth),
                    ),
                    _statRow(
                      label: 'from clicks',
                      value: 'TBD',
                      isIndented: true,
                    ),
                    _statRow(
                      label: 'from tics',
                      value: 'TBD',
                      isIndented: true,
                    ),
                    _statRow(
                      label: 'Current ore multiplier',
                      value: 'x${goldOverallEffective.toStringAsFixed(2)}',
                    ),
                    _statRow(
                      label: 'Achievement multiplier',
                      value: 'x${s.achievementMultiplier.toStringAsFixed(2)}',
                      isIndented: true,
                    ),
                    _statRow(
                      label: 'Max gold multiplier',
                      value: 'x${maxGoldMultDerived.toStringAsFixed(2)}',
                      isIndented: true,
                    ),
                    _statRow(
                      label: 'Chrono Epoch multiplier',
                      value: 'x${chronoEpochGold.toStringAsFixed(2)}',
                      isIndented: true,
                    ),
                    _statRow(
                      label: 'Monster Hunter multiplier',
                      value: 'x${hunterGoldMult.toStringAsFixed(0)}',
                      isIndented: true,
                    ),
                    _statRow(
                      label: 'Max gold (single rebirth)',
                      value: displayNumber(maxGoldSingleRebirth),
                    ),
                    _statRow(
                      label: 'Nuggets found (this run)',
                      value: nuggetsFoundThisRun.toString(),
                    ),
                    _statRow(
                      label: 'Refined gold from nuggets (this run)',
                      value: displayNumber(refinedGoldFromNuggetsThisRun),
                    ),
                    _statRow(
                      label: 'Clicks (this run)',
                      value: s.goldClicksThisRun.toString(),
                      isLast: true,
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                _sectionCard(
                  title: 'Antimatter Mode',
                  rows: [
                    _statRow(
                      label: 'Antimatter (this run)',
                      value: antimatterDisplay,
                    ),
                    _statRow(
                      label: 'Current antimatter multiplier',
                      value: 'x${antiOverallEffective.toStringAsFixed(2)}',
                    ),
                    _statRow(
                      label: 'Achievement multiplier',
                      value: 'x${s.achievementMultiplier.toStringAsFixed(2)}',
                      isIndented: true,
                    ),
                    _statRow(
                      label: 'Chrono Epoch multiplier',
                      value: 'x${chronoEpochAnti.toStringAsFixed(2)}',
                      isIndented: true,
                    ),
                    _statRow(
                      label: 'Monster Hunter multiplier',
                      value: 'x${hunterAntiMult.toStringAsFixed(2)}',
                      isIndented: true,
                    ),
                    _statRow(
                      label: 'Max dark matter (single rebirth)',
                      value: 'TBD',
                      isLast: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

Widget buildStatsTabFromState() => const StatsTab();
