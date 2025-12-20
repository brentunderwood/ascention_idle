// ==================================
// idle_game_screen.dart (CHANGED - FULL FILE)
// ==================================
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utilities/alerts.dart';
import '../rebirth/rebirth_screen.dart';
import '../cards/player_collection_repository.dart';
import '../cards/game_card_models.dart';
import '../upgrades_screen.dart';
import '../rebirth/achievements_catalog.dart';
import '../misc_tab.dart';
import '../stats/stats_tab.dart';
import '../tutorial_manager.dart';
import '../utilities/display_functions.dart';

// ✅ NEW: monster catalog file
import 'monster_catalog.dart';

part 'idle_game_state.dart';
part 'idle_game_state_accessors.dart';

// ✅ split-out mode files
part 'idle_game_gold.dart';
part 'idle_game_antimatter.dart';
part 'idle_game_rebirth.dart';
part 'idle_game_monster.dart';

/// Background assets for each game mode.
const String kGameBackgroundAsset =
    'assets/click_screen_art/gold_mining/background_mine_gold.png';
const String kAntimatterBackgroundAsset =
    'assets/click_screen_art/background_antimatter.png';
const String kMonsterBackgroundAsset =
    'assets/click_screen_art/monster_hunting/background_monster.png';

/// Keys used for local persistence (base keys; actual stored keys are
/// optionally prefixed by the active game mode).
const String kGoldOreKey = 'gold_ore';
const String kGoldKey = 'gold';
const String kTotalGoldOreKey = 'total_gold_ore';
const String kOrePerSecondKey = 'ore_per_second';
const String kBaseOrePerClickKey = 'base_ore_per_click';
const String kLastActiveKey = 'last_active_millis';
const String kRebirthCountKey = 'rebirth_count';
const String kTotalRefinedGoldKey = 'total_refined_gold';

/// Dark matter: meta resource earned from antimatter mode.
const String kDarkMatterKey = 'dark_matter';
const String kPendingDarkMatterKey = 'pending_dark_matter';

/// Active game mode (current run): 'gold', 'antimatter', or 'monster'.
const String kActiveGameModeKey = 'active_game_mode';

/// This key is used by the ActivityTab (Next Run tab) in rebirth_screen.dart
/// to decide what the *next* run's mode should be.
const String kNextRunSelectedKey = 'next_run_selected_option';

/// Upgrades: map<cardId, count> stored as JSON.
const String kCardUpgradeCountsKey = 'card_upgrade_counts';

/// Snapshot of which cards (and at what level) are upgradeable this run.
const String kUpgradeDeckSnapshotKey = 'rebirth_upgrade_deck_snapshot';

/// Tracks manual clicks on the rock.
const String kManualClickCountKey = 'manual_click_count';
const String kManualClickPowerKey = 'manual_click_power';

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
const String kBonusRebirthGoldFromNuggetsKey = 'bonus_rebirth_gold_from_nuggets';

/// Antimatter-related keys (per-mode).
const String kAntimatterKey = 'antimatter';
const String kAntimatterPerSecondKey = 'antimatter_per_second';
const String kAntimatterPolynomialKey = 'antimatter_polynomial';
const String kCurrentTicNumberKey = 'current_tic_number';

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

/// ============================================
/// ROCK DISPLAY + GESTURE / VISUALS
/// ============================================
mixin RockDisplayMixin on State<IdleGameScreen> {
  double _rockScale = 1.0;
  double _rockTiltX = 0.0;
  double _rockTiltY = 0.0;

  double _rockOffsetX = 0.0;
  double _rockOffsetY = 0.0;

  Offset? _rockPressLocalPosition;

  void resetRockVisuals() {
    if (!mounted) return;
    setState(() {
      _rockScale = 1.0;
      _rockTiltX = 0.0;
      _rockTiltY = 0.0;
      _rockOffsetX = 0.0;
      _rockOffsetY = 0.0;
      _rockPressLocalPosition = null;
    });
  }

  void _onRockPanDown(DragDownDetails details) {
    final state = this as _IdleGameScreenState;
    if (state._gameMode != 'gold') return;
    _handleRockPress(details.localPosition);
  }

  void _onRockPanUpdate(DragUpdateDetails details) {
    final state = this as _IdleGameScreenState;
    if (state._gameMode != 'gold') return;
    _updateRockTiltAndOffset(details.localPosition);
  }

  void _onRockPanEnd(DragEndDetails details) {
    final state = this as _IdleGameScreenState;
    if (state._gameMode != 'gold') return;
    _resetRockTransform();
  }

  void _onRockPanCancel() {
    final state = this as _IdleGameScreenState;
    if (state._gameMode != 'gold') return;
    _resetRockTransform();
  }

  void _handleRockPress(Offset localPosition) {
    final state = this as _IdleGameScreenState;

    _rockPressLocalPosition = localPosition;
    final now = DateTime.now();

    const double rockSize = 440.0;
    final double tapX = localPosition.dx.clamp(0.0, rockSize);
    final double tapY = localPosition.dy.clamp(0.0, rockSize);
    final double center = rockSize / 2;

    final double normX = (tapX - center) / center;
    final double normY = (tapY - center) / center;

    const double maxTilt = 4 * math.pi / 18;
    final double tiltX = normY * maxTilt;
    final double tiltY = -normX * maxTilt;

    setState(() {
      _rockScale = 0.9;
      _rockTiltX = tiltX;
      _rockTiltY = tiltY;

      _rockOffsetX = 0.0;
      _rockOffsetY = 0.0;
    });

    state._performRockClickEconomy(nowOverride: now);
  }

  void _updateRockTiltAndOffset(Offset localPosition) {
    if (_rockPressLocalPosition == null) {
      const double rockSize = 440.0;
      final double tapX = localPosition.dx.clamp(0.0, rockSize);
      final double tapY = localPosition.dy.clamp(0.0, rockSize);
      final double center = rockSize / 2;

      final double normX = (tapX - center) / center;
      final double normY = (tapY - center) / center;

      const double maxTilt = 4 * math.pi / 18;

      setState(() {
        _rockScale = 0.9;
        _rockTiltX = normY * maxTilt;
        _rockTiltY = -normX * maxTilt;
        _rockOffsetX = 0.0;
        _rockOffsetY = 0.0;
      });
      return;
    }

    const double rockSize = 440.0;
    final double tapX = localPosition.dx.clamp(0.0, rockSize);
    final double tapY = localPosition.dy.clamp(0.0, rockSize);
    final double center = rockSize / 2;

    final double normX = (tapX - center) / center;
    final double normY = (tapY - center) / center;

    const double maxTilt = 4 * math.pi / 18;

    final double tiltX = normY * maxTilt;
    final double tiltY = -normX * maxTilt;

    const double dragFactor = 0.2;
    const double maxOffset = 200.0;

    final Offset delta = localPosition - _rockPressLocalPosition!;
    double offsetX = delta.dx * dragFactor;
    double offsetY = delta.dy * dragFactor;

    offsetX = offsetX.clamp(-maxOffset, maxOffset);
    offsetY = offsetY.clamp(-maxOffset, maxOffset);

    setState(() {
      _rockScale = 0.9;
      _rockTiltX = tiltX;
      _rockTiltY = tiltY;
      _rockOffsetX = offsetX;
      _rockOffsetY = offsetY;
    });
  }

  void _resetRockTransform() {
    if (!mounted) return;
    setState(() {
      _rockScale = 1.0;
      _rockTiltX = 0.0;
      _rockTiltY = 0.0;
      _rockOffsetX = 0.0;
      _rockOffsetY = 0.0;
      _rockPressLocalPosition = null;
    });
  }
}

/// =======================
/// UI HELPERS (WIDGETS)
/// =======================

Widget buildIdleGameScaffold(
    _IdleGameScreenState state,
    BuildContext context,
    ) {
  final String backgroundAsset = (state._gameMode == 'antimatter')
      ? kAntimatterBackgroundAsset
      : (state._gameMode == 'monster')
      ? kMonsterBackgroundAsset
      : kGameBackgroundAsset;

  return Scaffold(
    backgroundColor: Colors.transparent,
    body: Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(backgroundAsset),
          fit: BoxFit.cover,
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            buildTopBar(state),
            const SizedBox(height: 8),
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
    bottomNavigationBar: BottomNavigationBar(
      currentIndex: state._currentTabIndex,
      type: BottomNavigationBarType.fixed,
      onTap: (index) {
        state.setState(() {
          state._currentTabIndex = index;
        });

        if (index == 2) {
          TutorialManager.instance.onRebirthStoreShown(state.context);
        }
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

Widget buildTopBar(_IdleGameScreenState state) {
  if (state._gameMode == 'monster') {
    return state.buildMonsterTopBar();
  }

  if (state._currentTabIndex == 2) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Refined Gold: ${displayNumber(state._gold)}',
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
            'Total Refined Gold: ${displayNumber(state._totalRefinedGold)}',
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

  final bool isAntimatterMode = state._gameMode == 'antimatter';

  const resourceLabel = 'Gold Ore';
  final orePerClickDisplay = state._currentOrePerClickForDisplay();
  final double effectiveOrePerSecond = state.getOrePerSecond();

  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (isAntimatterMode) ...[
          Text(
            'Antimatter: ${factorialDisplay(state._antimatter)}',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.purpleAccent,
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
            'Antimatter per second: ${displayNumber(state._antimatterPerSecond)}',
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
          const SizedBox(height: 8),
        ],
        Text(
          '$resourceLabel: ${displayNumber(state._goldOre)}',
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
          'Ore per second: ${displayNumber(effectiveOrePerSecond)}',
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
        if (!isAntimatterMode)
          Text(
            'Ore per click: ${displayNumber(orePerClickDisplay)}',
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

Widget buildFrenzyButton(_IdleGameScreenState state) {
  if (!state._spellFrenzyActive || state._gameMode != 'gold') {
    return const SizedBox.shrink();
  }

  final now = DateTime.now();
  final bool frenzyActiveNow = state._isFrenzyCurrentlyActive();
  String label;
  VoidCallback? onPressed;

  if (state._spellFrenzyLastTriggerTime == null) {
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
      final double remainingCooldown = state._spellFrenzyCooldownSeconds - elapsedSeconds;
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
        child: Text(label, textAlign: TextAlign.center),
      ),
    ),
  );
}

Widget buildNuggetWidget(_IdleGameScreenState state, {required int nuggetId}) {
  final nugget = state._nuggets.firstWhere((n) => n.id == nuggetId);

  final now = DateTime.now();
  final age = now.difference(nugget.spawnTime).inMilliseconds;

  const int totalMs = 10000;
  const int fadeMs = 3000;

  double opacity;
  if (age < fadeMs) {
    opacity = age / fadeMs;
  } else if (age > totalMs - fadeMs) {
    final remaining = totalMs - age;
    opacity = remaining / fadeMs;
  } else {
    opacity = 1.0;
  }

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
            final angle = (t - 0.5) * 0.4;
            return Transform.rotate(angle: angle, child: child);
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

Widget buildTabContent(_IdleGameScreenState state) {
  switch (state._currentTabIndex) {
    case 0:
      return buildMainTab(state);
    case 1:
      return buildUpgradesTab(state);
    case 2:
      return buildRebirthTab(state);
    case 3:
      return const StatsTab();
    case 4:
      return buildMiscTab(state);
    default:
      return const SizedBox.shrink();
  }
}

Widget buildMainTab(_IdleGameScreenState state) {
  // ✅ Monster mode main tab is fully handled by monster file.
  if (state._gameMode == 'monster') {
    return state.buildMonsterMainTab();
  }

  final double rebirthGold = state._calculateRebirthGold();
  final int phase = state._currentClickPhase();
  final String rockAssetPath = 'assets/click_screen_art/gold_mining/rock_0$phase.png';

  final Widget phaseBanner = (phase == 9 && state._gameMode == 'gold')
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

  final bool isAntimatterMode = state._gameMode == 'antimatter';

  final String rebirthButtonLabel;
  if (isAntimatterMode) {
    final double pendingDarkMatter = state._pendingDarkMatter;
    rebirthButtonLabel = 'Rebirth and gain ${displayNumber(pendingDarkMatter)} dark matter';
  } else {
    rebirthButtonLabel = 'Rebirth and gain ${rebirthGold.toStringAsFixed(0)} gold';
  }

  return Column(
    children: [
      Expanded(
        child: LayoutBuilder(
          builder: (context, constraints) {
            state._playAreaSize = constraints.biggest;

            return Stack(
              children: [
                if (!isAntimatterMode)
                  Align(
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
                                ..setEntry(3, 2, 0.0015)
                                ..translate(state._rockOffsetX, state._rockOffsetY)
                                ..scale(state._rockScale)
                                ..rotateX(state._rockTiltX)
                                ..rotateY(state._rockTiltY),
                              child: Image.asset(rockAssetPath, fit: BoxFit.contain),
                            ),
                          ),
                        ),
                        buildFrenzyButton(state),
                      ],
                    ),
                  )
                else
                  Align(
                    alignment: const Alignment(0, -0.2),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            'Antimatter reactor online.\nProduction scales with time.',
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
                        ),
                      ],
                    ),
                  ),
                ...state._nuggets.map(
                      (n) => Positioned(
                    left: n.position.dx,
                    top: n.position.dy,
                    child: buildNuggetWidget(state, nuggetId: n.id),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: state._attemptRebirth,
            child: Text(rebirthButtonLabel),
          ),
        ),
      ),
    ],
  );
}

Widget buildUpgradesTab(_IdleGameScreenState state) {
  const resourceLabel = 'Gold Ore';

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

Widget buildMiscTab(_IdleGameScreenState state) {
  return MiscTab(
    onResetGame: () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      await PlayerCollectionRepository.instance.reset();

      if (!state.mounted) return;

      Navigator.of(state.context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const IdleGameScreen()),
            (route) => false,
      );
    },
  );
}
