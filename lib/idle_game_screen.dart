import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'alerts.dart';
import 'rebirth/rebirth_screen.dart';
import 'cards/player_collection_repository.dart';
import 'cards/game_card_models.dart';
import 'upgrades_screen.dart';
import 'rebirth/achievements_catalog.dart';
import 'misc_tab.dart'; // NEW: misc tab split into its own file

part 'idle_game_state.dart';

/// Change this to swap the background later.
const String kGameBackgroundAsset =
    'assets/click_screen_art/gold_mining/background_mine_gold.png';

/// Keys used for local persistence.
const String kGoldOreKey = 'gold_ore';
const String kGoldKey = 'gold';
const String kTotalGoldOreKey = 'total_gold_ore';
const String kOrePerSecondKey = 'ore_per_second';
const String kBaseOrePerClickKey = 'base_ore_per_click';
const String kLastActiveKey = 'last_active_millis';
const String kRebirthCountKey = 'rebirth_count';
const String kTotalRefinedGoldKey = 'total_refined_gold';
const String kRebirthGoalKey = 'rebirth_goal';

/// This key is used by the NextRunTab in rebirth_screen.dart.
const String kNextRunSelectedKey = 'next_run_selected_option';

/// Upgrades: map<cardId, count> stored as JSON.
const String kCardUpgradeCountsKey = 'card_upgrade_counts';

/// Snapshot of which cards (and at what level) are upgradeable this run.
const String kUpgradeDeckSnapshotKey = 'rebirth_upgrade_deck_snapshot';

/// Tracks manual clicks on the rock.
const String kManualClickCountKey = 'manual_click_count';

/// Frenzy spell persistence keys.
const String kSpellFrenzyActiveKey = 'spell_frenzy_active';
const String kSpellFrenzyLastTriggerKey = 'spell_frenzy_last_trigger';
const String kSpellFrenzyDurationKey = 'spell_frenzy_duration_seconds';
const String kSpellFrenzyCooldownKey = 'spell_frenzy_cooldown_seconds';
const String kSpellFrenzyMultiplierKey = 'spell_frenzy_multiplier';

/// Momentum persistence keys.
const String kMomentumCapKey = 'momentum_cap';
const String kMomentumScaleKey = 'momentum_scale';

/// Bonus ore persistence keys.
const String kBonusOrePerSecondKey = 'bonus_ore_per_second';
const String kBonusOrePerClickKey = 'bonus_ore_per_click';

/// Multiplier persistence keys.
const String kRebirthMultiplierKey = 'rebirth_multiplier';
const String kOverallMultiplierKey = 'overall_multiplier';
const String kMaxGoldMultiplierKey = 'max_gold_multiplier';
const String kAchievementMultiplierKey = 'achievement_multiplier';

/// Random nugget spawn persistence keys.
const String kRandomSpawnChanceKey = 'random_spawn_chance';
const String kBonusRebirthGoldFromNuggetsKey =
    'bonus_rebirth_gold_from_nuggets';

/// Simple nav item model so you can easily swap icons / labels later.
class _NavItem {
  final String label;
  final IconData icon;

  const _NavItem({
    required this.label,
    required this.icon,
  });
}

/// Tabs: Main, Upgrades, Rebirth, Stats, Misc.
const List<_NavItem> _navItems = [
  _NavItem(label: 'Main', icon: Icons.home),
  _NavItem(label: 'Upgrades', icon: Icons.upgrade),
  _NavItem(label: 'Rebirth', icon: Icons.autorenew),
  _NavItem(label: 'Stats', icon: Icons.bar_chart),
  _NavItem(label: 'Misc', icon: Icons.more_horiz),
];

class IdleGameScreen extends StatefulWidget {
  const IdleGameScreen({super.key});

  @override
  State<IdleGameScreen> createState() => _IdleGameScreenState();
}

/// =======================
/// UI HELPERS (WIDGETS)
/// =======================

Widget buildIdleGameScaffold(
    _IdleGameScreenState state,
    BuildContext context,
    ) {
  return Scaffold(
    // Transparent so background image shows fully.
    backgroundColor: Colors.transparent,
    body: Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage(kGameBackgroundAsset),
          fit: BoxFit.cover,
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            buildTopBar(state),
            const SizedBox(height: 8),
            // Main tab content area fills everything down to bottom nav bar.
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: buildTabContent(state),
              ),
            ),
          ],
        ),
      ),
    ),

    // Bottom tab navigation
    bottomNavigationBar: BottomNavigationBar(
      currentIndex: state._currentTabIndex,
      type: BottomNavigationBarType.fixed,
      onTap: (index) {
        state.setState(() {
          state._currentTabIndex = index;
        });
      },
      items: _navItems
          .map(
            (item) => BottomNavigationBarItem(
          icon: Icon(item.icon),
          label: item.label,
        ),
      )
          .toList(),
    ),
  );
}

/// Top bar switches between Ore stats and Refined Gold
/// depending on which main tab is selected.
Widget buildTopBar(_IdleGameScreenState state) {
  if (state._currentTabIndex == 2) {
    // Rebirth tab: show refined gold instead of ore stats.
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16.0,
        vertical: 12.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Refined Gold: ${state._gold.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.amber,
              shadows: [
                Shadow(
                  blurRadius: 6,
                  color: Colors.black,
                  offset: Offset(2, 2),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Total Refined Gold: ${state._totalRefinedGold.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white,
              shadows: [
                Shadow(
                  blurRadius: 4,
                  color: Colors.black54,
                  offset: Offset(1, 1),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Default: ore/antimatter status for all other tabs
  final resourceLabel =
  state._rebirthGoal == 'create_antimatter' ? 'Antimatter' : 'Gold Ore';
  final orePerClickDisplay = state._currentOrePerClickForDisplay();

  // Show effective ore per second, including Frenzy + overall multiplier.
  final bool frenzyNow = state._isFrenzyCurrentlyActive();
  final double baseOrePerSecond =
      state._orePerSecond + state._bonusOrePerSecond;
  final double effectiveOrePerSecond = baseOrePerSecond *
      (frenzyNow ? state._spellFrenzyMultiplier : 1.0) *
      state._overallMultiplier;

  return Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: 16.0,
      vertical: 12.0,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          '$resourceLabel: ${state._goldOre.toStringAsFixed(0)}',
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: [
              Shadow(
                blurRadius: 6,
                color: Colors.black,
                offset: Offset(2, 2),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          'Ore per second: ${effectiveOrePerSecond.toStringAsFixed(2)}',
          style: const TextStyle(
            fontSize: 16,
            color: Colors.white,
            shadows: [
              Shadow(
                blurRadius: 4,
                color: Colors.black54,
                offset: Offset(1, 1),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          'Ore per click: ${orePerClickDisplay.toStringAsFixed(2)}',
          style: const TextStyle(
            fontSize: 16,
            color: Colors.white,
            shadows: [
              Shadow(
                blurRadius: 4,
                color: Colors.black54,
                offset: Offset(1, 1),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

/// Build the Frenzy button (or nothing if the spell isn't unlocked).
Widget buildFrenzyButton(_IdleGameScreenState state) {
  if (!state._spellFrenzyActive) {
    return const SizedBox.shrink();
  }

  final now = DateTime.now();
  final bool frenzyActiveNow = state._isFrenzyCurrentlyActive();
  String label;
  VoidCallback? onPressed;

  if (state._spellFrenzyLastTriggerTime == null) {
    // Never cast before: available immediately.
    label = 'Cast Frenzy';
    onPressed = state._activateFrenzy;
  } else {
    final double elapsedSeconds =
    now.difference(state._spellFrenzyLastTriggerTime!).inSeconds.toDouble();

    if (frenzyActiveNow) {
      final remaining = state._spellFrenzyDurationSeconds - elapsedSeconds;
      final int secs = remaining > 0 ? remaining.ceil() : 0;
      label = 'Frenzy active: ${secs}s left';
      onPressed = null;
    } else {
      final double remainingCooldown =
          state._spellFrenzyCooldownSeconds - elapsedSeconds;
      if (remainingCooldown <= 0) {
        label = 'Cast Frenzy';
        onPressed = state._activateFrenzy;
      } else {
        final int secs = remainingCooldown.ceil();
        label = 'Frenzy cooldown: ${secs}s';
        onPressed = null;
      }
    }
  }

  return Padding(
    padding: const EdgeInsets.only(top: 12.0),
    child: SizedBox(
      width: 260,
      child: ElevatedButton(
        onPressed: onPressed,
        child: Text(
          label,
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );
}

/// Nugget widget – small rotating clickable image.
Widget buildNuggetWidget(
    _IdleGameScreenState state, {
      required int nuggetId,
    }) {
  final nugget = state._nuggets.firstWhere((n) => n.id == nuggetId);

  final now = DateTime.now();
  final age = now.difference(nugget.spawnTime).inMilliseconds;

  const int totalMs = 10000; // 10 seconds
  const int fadeMs = 3000; // 3 sec fade in, 3 sec fade out

  double opacity;

  if (age < fadeMs) {
    // ✔ FADE IN: 0 → 1 over 3 seconds
    opacity = age / fadeMs;
  } else if (age > totalMs - fadeMs) {
    // ✔ FADE OUT: 1 → 0 over last 3 seconds
    final remaining = totalMs - age;
    opacity = remaining / fadeMs;
  } else {
    // Fully visible during middle 4 seconds
    opacity = 1.0;
  }

  // Clamp just in case
  opacity = opacity.clamp(0.0, 1.0);

  return Opacity(
    opacity: opacity,
    child: GestureDetector(
      onTap: () => state._onNuggetTap(nuggetId),
      child: SizedBox(
        width: 64,
        height: 64,
        child: AnimatedBuilder(
          animation: state._nuggetRotationController,
          builder: (context, child) {
            final t = state._nuggetRotationController.value;
            final angle = (t - 0.5) * 0.4; // swing -0.2 ↔ 0.2
            return Transform.rotate(
              angle: angle,
              child: child,
            );
          },
          child: Image.asset(
            'assets/click_screen_art/gold_mining/rock_09.png',
            fit: BoxFit.contain,
          ),
        ),
      ),
    ),
  );
}

/// Returns the widget for the currently selected tab.
Widget buildTabContent(_IdleGameScreenState state) {
  switch (state._currentTabIndex) {
    case 0:
      return buildMainTab(state);
    case 1:
      return buildUpgradesTab(state);
    case 2:
      return buildRebirthTab(state);
    case 3:
      return buildStatsTab();
    case 4:
    // NEW: real misc tab widget with reset support
      return buildMiscTab(state);
    default:
      return const SizedBox.shrink();
  }
}

Widget buildMainTab(_IdleGameScreenState state) {
  final rebirthGold = state._calculateRebirthGold();

  final int phase = state._currentClickPhase();

  // Image changes with phase: rock_0x.png where x is the phase (1–9).
  final String rockAssetPath =
      'assets/click_screen_art/gold_mining/rock_0$phase.png';

  // Optional phase-9 banner text above the rock.
  final Widget phaseBanner = phase == 9
      ? const Padding(
    padding: EdgeInsets.only(bottom: 8.0),
    child: Text(
      'Gold Vein Found! All clicks have 10x power',
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.amber,
        shadows: [
          Shadow(
            blurRadius: 4,
            color: Colors.black54,
            offset: Offset(1, 1),
          ),
        ],
      ),
      textAlign: TextAlign.center,
    ),
  )
      : const SizedBox.shrink();

  // Column fills the available height in the main tab.
  // Content at top, rebirth button pinned to bottom (above nav bar).
  return Column(
    children: [
      // Main content area (includes rock and random nuggets).
      Expanded(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Update play area size for spawn positioning.
            state._playAreaSize = constraints.biggest;

            return Stack(
              children: [
                Align(
                  // Move the click object slightly higher on the screen.
                  alignment: const Alignment(0, -0.2),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      phaseBanner,
                      SizedBox(
                        width: 440,
                        height: 440,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onPanDown: state._onRockPanDown,
                          onPanUpdate: state._onRockPanUpdate,
                          onPanEnd: state._onRockPanEnd,
                          onPanCancel: state._onRockPanCancel,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 80),
                            curve: Curves.easeOut,
                            transformAlignment: Alignment.center,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.0015) // perspective
                              ..translate(
                                  state._rockOffsetX, state._rockOffsetY)
                              ..scale(state._rockScale)
                              ..rotateX(state._rockTiltX)
                              ..rotateY(state._rockTiltY),
                            child: Image.asset(
                              rockAssetPath,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                      // New Frenzy button below the click object.
                      buildFrenzyButton(state),
                    ],
                  ),
                ),

                // Multiple random gold nuggets, each positioned absolutely
                // so they can cover the whole play area without going off-screen.
                ...state._nuggets.map(
                      (n) => Positioned(
                    left: n.position.dx,
                    top: n.position.dy,
                    child: buildNuggetWidget(
                      state,
                      nuggetId: n.id,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),

      // Rebirth button at bottom of Main tab only
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: state._attemptRebirth,
            child: Text(
              'Rebirth and gain ${rebirthGold.toStringAsFixed(0)} gold',
            ),
          ),
        ),
      ),
    ],
  );
}

Widget buildUpgradesTab(_IdleGameScreenState state) {
  final resourceLabel =
  state._rebirthGoal == 'create_antimatter' ? 'Antimatter' : 'Gold Ore';

  return UpgradesScreen(
    currentResource: state._goldOre,
    resourceLabel: resourceLabel,
    onSpendResource: (amount) {
      state.setState(() {
        state._goldOre -= amount;
        if (state._goldOre < 0) state._goldOre = 0;
      });
      state._saveProgress();
    },
    onCardUpgradeEffect: state._applyCardUpgradeEffect,
  );
}

Widget buildRebirthTab(_IdleGameScreenState state) {
  // Rebirth tab with its own nested tabs (Next Run / Store / Deck / Achievements).
  return RebirthScreen(
    currentGold: state._gold,
    onSpendGold: (amount) {
      state.setState(() {
        state._gold -= amount;
        if (state._gold < 0) state._gold = 0;
      });
      state._saveProgress();
    },
    achievementMultiplier: state.getAchievementMultiplier(),
  );
}

Widget buildStatsTab() {
  return const Center(
    child: Text(
      'Stats coming soon...',
      style: TextStyle(
        fontSize: 18,
        color: Colors.white,
        shadows: [
          Shadow(
            blurRadius: 4,
            color: Colors.black54,
            offset: Offset(1, 1),
          ),
        ],
      ),
      textAlign: TextAlign.center,
    ),
  );
}

/// New: real misc tab with a reset button.
/// The reset callback lives here (has access to state & navigation),
/// while the UI is in misc_tab.dart.
Widget buildMiscTab(_IdleGameScreenState state) {
  return MiscTab(
    onResetGame: () async {
      // 1) Clear all saved preferences (game progress, decks, achievements, etc.)
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // 2) Reset in-memory collection repository so it matches cleared prefs.
      await PlayerCollectionRepository.instance.reset();

      // 3) Restart the game screen from a clean slate.
      if (!state.mounted) return;

      Navigator.of(state.context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const IdleGameScreen()),
            (route) => false,
      );
    },
  );
}
