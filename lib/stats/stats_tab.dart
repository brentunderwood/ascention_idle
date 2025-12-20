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
const String kTotalClicksKey = 'total_clicks';
const String kTotalManualClickCyclesKey = 'total_manual_click_cycles';
const String kMaxCardCountKey = 'max_card_count';

/// ✅ NEW: maxGoldMultiplier renamed -> maxSingleRunGold (GLOBAL, not mode-dependent)
const String kMaxSingleRunGoldKey = 'max_single_run_gold';

/// Legacy fallback (older saves)
const String kLegacyMaxGoldMultiplierKey = 'max_gold_multiplier';

/// Per-mode/per-run keys (base; antimatter uses prefix)
const String kGoldOreKey = 'gold_ore';
const String kTotalGoldOreKey = 'total_gold_ore';

/// ✅ NEW: overall multiplier renamed -> chrono_stepPmultiplier (per-mode; rebirth-only)
const String kChronoStepPMultiplierKey = 'chrono_stepPmultiplier';

/// Legacy fallback
const String kLegacyOverallMultiplierKey = 'overall_multiplier';

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
  final double maxSingleRunGold;
  final int totalClicksAllTime;
  final double totalManualClickCyclesAllTime;
  final int maxCardCount;

  // Monster hunter
  final int monstersKilled;
  final int hunterLevel;
  final int hunterExp;

  // Gold-mode (per-run/per-mode)
  final double goldTotalOreThisRebirth;
  final double goldChronoStepPMultiplier; // rebirth-only (stored)
  final int goldClicksThisRun;
  final double goldRefinedGoldFromNuggetsThisRun; // stored as manualClickCyclesThisRun

  // Antimatter-mode (per-run/per-mode)
  final double antiAntimatterCurrentRun;
  final double antiChronoStepPMultiplier; // rebirth-only (stored)

  const _StatsSnapshot({
    required this.totalRefinedGold,
    required this.darkMatterTotal,
    required this.achievementMultiplier,
    required this.maxSingleRunGold,
    required this.totalClicksAllTime,
    required this.totalManualClickCyclesAllTime,
    required this.maxCardCount,
    required this.monstersKilled,
    required this.hunterLevel,
    required this.hunterExp,
    required this.goldTotalOreThisRebirth,
    required this.goldChronoStepPMultiplier,
    required this.goldClicksThisRun,
    required this.goldRefinedGoldFromNuggetsThisRun,
    required this.antiAntimatterCurrentRun,
    required this.antiChronoStepPMultiplier,
  });
}

class _StatsTabState extends State<StatsTab> {
  late Future<_StatsSnapshot> _future;

  /// Expand/collapse state for grouped rows
  final Map<String, bool> _expanded = <String, bool>{};

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

    // Achievement multiplier is GLOBAL (not mode-dependent)
    final achievementMultiplier =
        prefs.getDouble(kAchievementMultiplierKey) ?? 1.0;

    // maxSingleRunGold is GLOBAL (not mode-dependent)
    final maxSingleRunGold = prefs.getDouble(kMaxSingleRunGoldKey) ??
        prefs.getDouble(kLegacyMaxGoldMultiplierKey) ??
        1.0;

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

    // chrono_stepPmultiplier (rebirth-only). Fallback to legacy overall.
    final goldChronoStepPMultiplier =
        prefs.getDouble(_modeKey(kChronoStepPMultiplierKey, goldMode)) ??
            prefs.getDouble(_modeKey(kLegacyOverallMultiplierKey, goldMode)) ??
            1.0;

    final goldClicksThisRun =
        prefs.getInt(_modeKey(kClicksThisRunKey, goldMode)) ?? 0;

    // Refined gold from nuggets this run is stored in manual_click_cycles_this_run
    final goldRefinedGoldFromNuggetsThisRun =
        prefs.getDouble(_modeKey(kManualClickCyclesThisRunKey, goldMode)) ??
            0.0;

    // ---- Antimatter mode (prefixed keys) ----
    const antiMode = 'antimatter';
    final antiAntimatterCurrentRun =
        prefs.getDouble(_modeKey(kAntimatterKey, antiMode)) ?? 0.0;

    final antiChronoStepPMultiplier =
        prefs.getDouble(_modeKey(kChronoStepPMultiplierKey, antiMode)) ??
            prefs.getDouble(_modeKey(kLegacyOverallMultiplierKey, antiMode)) ??
            1.0;

    return _StatsSnapshot(
      totalRefinedGold: totalRefinedGold,
      darkMatterTotal: darkMatterTotal,
      achievementMultiplier: achievementMultiplier,
      maxSingleRunGold: maxSingleRunGold,
      totalClicksAllTime: totalClicksAllTime,
      totalManualClickCyclesAllTime: totalManualClickCyclesAllTime,
      maxCardCount: maxCardCount,
      monstersKilled: monstersKilled,
      hunterLevel: hunterLevel,
      hunterExp: hunterExp,
      goldTotalOreThisRebirth: goldTotalOreThisRebirth,
      goldChronoStepPMultiplier: goldChronoStepPMultiplier,
      goldClicksThisRun: goldClicksThisRun,
      goldRefinedGoldFromNuggetsThisRun: goldRefinedGoldFromNuggetsThisRun,
      antiAntimatterCurrentRun: antiAntimatterCurrentRun,
      antiChronoStepPMultiplier: antiChronoStepPMultiplier,
    );
  }

  // Best-effort extraction without assuming exact OwnedCard field names.
  int _ownedCardLevel(OwnedCard c) {
    try {
      final d = c as dynamic;
      final dynamic v =
      (d.level ?? d.cardLevel ?? d.upgradeLevel ?? d.count ?? 0);

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
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final row = Row(
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
        if (trailing != null) ...[
          const SizedBox(width: 8),
          trailing,
        ],
      ],
    );

    final content = Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Column(
        children: [
          if (onTap != null)
            InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.0),
                child: row,
              ),
            )
          else
            row,
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

    return content;
  }

  Widget _collapsibleGroup({
    required String id,
    required String label,
    required String value,
    required List<Widget> children,
    required bool isLastInSection,
  }) {
    final bool expanded = _expanded[id] ?? false;

    return Column(
      children: [
        _statRow(
          label: label,
          value: value,
          // If expanded, we don't want the header to render the "end-of-row" divider,
          // because we're about to render children under it.
          isLast: expanded ? true : isLastInSection,
          trailing: Icon(
            expanded ? Icons.expand_less : Icons.expand_more,
            color: Colors.white70,
            size: 20,
          ),
          onTap: () {
            setState(() {
              _expanded[id] = !expanded;
            });
          },
        ),
        if (expanded) ...[
          // Divider between header and first child (visual grouping)
          Divider(
            height: 1,
            thickness: 1,
            color: Colors.white.withOpacity(0.10),
          ),
          const SizedBox(height: 10),
          ...children,
          // If the group is NOT the last thing in the section, add the section divider.
          if (!isLastInSection) ...[
            Divider(
              height: 1,
              thickness: 1,
              color: Colors.white.withOpacity(0.10),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ],
    );
  }

  /// ✅ "max gold multiplier" derived from maxSingleRunGold via log boost.
  double _maxGoldSingleRunLogBoost(double maxSingleRunGold) {
    final safe = (!maxSingleRunGold.isFinite || maxSingleRunGold <= 0)
        ? 1.0
        : maxSingleRunGold;
    return 1.0 + (math.log(safe) / math.log(1000.0));
  }

  double _monsterHunterGoldMult(int hunterLevel) {
    final lvl = hunterLevel <= 0 ? 1 : hunterLevel;
    return lvl.toDouble();
  }

  double _monsterHunterAntimatterMult(int hunterLevel) {
    // As in your latest file: antimatter MH multiplier equals hunter level (min 1).
    final double m = math.max(1.0, hunterLevel.toDouble());
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

        // ---- Derived multipliers ----
        final double maxLogBoost = _maxGoldSingleRunLogBoost(s.maxSingleRunGold);

        final int hunterLvlSafe = (s.hunterLevel <= 0) ? 1 : s.hunterLevel;
        final double hunterGoldMult = _monsterHunterGoldMult(hunterLvlSafe);
        final double hunterAntiMult = _monsterHunterAntimatterMult(hunterLvlSafe);

        // "Current ore multiplier" reflects computeCoreOreMultiplier().
        final double coreOreMultGold = s.goldChronoStepPMultiplier *
            s.achievementMultiplier *
            maxLogBoost *
            hunterGoldMult;

        final double coreOreMultAnti = s.antiChronoStepPMultiplier *
            s.achievementMultiplier *
            maxLogBoost *
            hunterAntiMult;

        // Nuggets
        final double refinedGoldFromNuggetsThisRun =
            s.goldRefinedGoldFromNuggetsThisRun;
        final int nuggetsFoundThisRun =
        _nuggetsFoundThisRunFromRefinedGold(refinedGoldFromNuggetsThisRun);

        final String antimatterDisplay =
        factorialDisplay(s.antiAntimatterCurrentRun);

        // Monster hunter EXP
        final int expToNext =
            (hunterLvlSafe + 1) * (hunterLvlSafe + 1) * (hunterLvlSafe + 1);

        // ---- Collapsible children lists ----
        final List<Widget> goldCoreChildren = [
          _statRow(
            label: 'Achievement multiplier',
            value: 'x${s.achievementMultiplier.toStringAsFixed(2)}',
            isIndented: true,
          ),
          _statRow(
            label: 'Max gold multiplier',
            value: 'x${maxLogBoost.toStringAsFixed(2)}',
            isIndented: true,
          ),
          _statRow(
            label: 'Small Step multiplier',
            value: 'x${s.goldChronoStepPMultiplier.toStringAsFixed(2)}',
            isIndented: true,
          ),
          _statRow(
            label: 'Monster Hunter multiplier',
            value: 'x${hunterGoldMult.toStringAsFixed(0)}',
            isIndented: true,
            isLast: true,
          ),
        ];

        final List<Widget> antiCoreChildren = [
          _statRow(
            label: 'Achievement multiplier',
            value: 'x${s.achievementMultiplier.toStringAsFixed(2)}',
            isIndented: true,
          ),
          _statRow(
            label: 'Max gold multiplier',
            value: 'x${maxLogBoost.toStringAsFixed(2)}',
            isIndented: true,
          ),
          _statRow(
            label: 'Small Step multiplier',
            value: 'x${s.antiChronoStepPMultiplier.toStringAsFixed(2)}',
            isIndented: true,
          ),
          _statRow(
            label: 'Monster Hunter multiplier',
            value: 'x${hunterAntiMult.toStringAsFixed(2)}',
            isIndented: true,
            isLast: true,
          ),
        ];

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

                    // ✅ Collapsible group
                    _collapsibleGroup(
                      id: 'gold_core_mult',
                      label: 'Current ore multiplier',
                      value: 'x${coreOreMultGold.toStringAsFixed(2)}',
                      children: goldCoreChildren,
                      isLastInSection: false,
                    ),

                    _statRow(
                      label: 'Max gold (single run)',
                      value: displayNumber(s.maxSingleRunGold),
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

                    // ✅ Collapsible group
                    _collapsibleGroup(
                      id: 'anti_core_mult',
                      label: 'Current antimatter multiplier',
                      value: 'x${coreOreMultAnti.toStringAsFixed(2)}',
                      children: antiCoreChildren,
                      isLastInSection: false,
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
