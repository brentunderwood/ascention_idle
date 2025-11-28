import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'alerts.dart';
import 'rebirth/rebirth_screen.dart';
import 'cards/player_collection_repository.dart';
import 'cards/game_card_models.dart';
import 'upgrades_screen.dart';

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
/// This must match the key in upgrades_screen.dart.
const String kUpgradeDeckSnapshotKey = 'rebirth_upgrade_deck_snapshot';

/// Tracks manual clicks on the rock.
const String kManualClickCountKey = 'manual_click_count';

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

/// Main game state for the idle game.
///
/// Implements [IdleGameEffectTarget] so card effects can modify the
/// current run's values (ore, orePerSecond, etc.) in a controlled way.
class _IdleGameScreenState extends State<IdleGameScreen>
    implements IdleGameEffectTarget {
  int _currentTabIndex = 0;

  double _goldOre = 0;
  double _totalGoldOre = 0;
  double _gold = 0.0;
  double _orePerSecond = 0;
  double _bonusOrePerSecond = 1;

  /// Flat bonus added to the base 1.0 ore per click.
  double _baseOrePerClick = 0.0;

  int _rebirthCount = 0;
  double _totalRefinedGold = 0;

  /// Which goal applies to the *current* run
  /// (e.g., 'mine_gold' or 'create_antimatter').
  String _rebirthGoal = 'mine_gold';

  /// Momentum system for clicks (kept for future use).
  int _momentumClicks = 0;
  DateTime? _lastClickTime;

  /// Cached value for previewing how much will be gained on the next click.
  double _lastComputedOrePerClick = 1.0;

  /// Manual clicks on the rock (persisted, reset on rebirth).
  int _manualClickCount = 0;

  /// Animation state for the rock (3D-ish tilt).
  double _rockScale = 1.0;
  double _rockTiltX = 0.0; // tilt forward/back (based on vertical tap)
  double _rockTiltY = 0.0; // tilt left/right (based on horizontal tap)

  /// Small positional offset so the rock can "drag" a bit under the finger.
  double _rockOffsetX = 0.0;
  double _rockOffsetY = 0.0;

  /// Where the initial press happened within the rock, used to compute drag delta.
  Offset? _rockPressLocalPosition;

  Timer? _timer;
  SharedPreferences? _prefs;
  DateTime? _lastActiveTime;

  @override
  void initState() {
    super.initState();
    _initAndStart();
  }

  Future<void> _initAndStart() async {
    await PlayerCollectionRepository.instance.init();
    await _loadProgress();
    await _applyOfflineProgress();
    _updatePreviewPerClick();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    // Save one last time (fire-and-forget)
    _saveProgress();
    super.dispose();
  }

  Future<void> _loadProgress() async {
    _prefs ??= await SharedPreferences.getInstance();

    final storedGoldOre = _prefs!.getDouble(kGoldOreKey);
    final storedTotalGoldOre = _prefs!.getDouble(kTotalGoldOreKey);
    final storedGold = _prefs!.getDouble(kGoldKey);
    final storedOrePerSecond = _prefs!.getDouble(kOrePerSecondKey);
    final storedBaseOrePerClick = _prefs!.getDouble(kBaseOrePerClickKey);
    final storedLastActive = _prefs!.getInt(kLastActiveKey);
    final storedRebirthCount = _prefs!.getInt(kRebirthCountKey);
    final storedTotalRefinedGold = _prefs!.getDouble(kTotalRefinedGoldKey);
    final storedRebirthGoal = _prefs!.getString(kRebirthGoalKey);
    final storedManualClicks = _prefs!.getInt(kManualClickCountKey);

    setState(() {
      _goldOre = storedGoldOre ?? 0;
      _totalGoldOre = storedTotalGoldOre ?? 0;
      _gold = storedGold ?? 0;
      _orePerSecond = storedOrePerSecond ?? 0;
      _baseOrePerClick = storedBaseOrePerClick ?? 1;
      _rebirthCount = storedRebirthCount ?? 0;
      _totalRefinedGold = storedTotalRefinedGold ?? 0;
      _rebirthGoal = storedRebirthGoal ?? 'mine_gold';
      _manualClickCount = storedManualClicks ?? 0;
      _lastActiveTime = storedLastActive != null
          ? DateTime.fromMillisecondsSinceEpoch(storedLastActive)
          : null;
    });
  }

  Future<void> _saveProgress() async {
    _prefs ??= await SharedPreferences.getInstance();
    _lastActiveTime = DateTime.now();

    await _prefs!.setDouble(kGoldOreKey, _goldOre);
    await _prefs!.setDouble(kTotalGoldOreKey, _totalGoldOre);
    await _prefs!.setDouble(kGoldKey, _gold);
    await _prefs!.setDouble(kOrePerSecondKey, _orePerSecond);
    await _prefs!.setDouble(kBaseOrePerClickKey, _baseOrePerClick);
    await _prefs!.setInt(kRebirthCountKey, _rebirthCount);
    await _prefs!.setDouble(kTotalRefinedGoldKey, _totalRefinedGold);
    await _prefs!.setString(kRebirthGoalKey, _rebirthGoal);
    await _prefs!.setInt(kManualClickCountKey, _manualClickCount);
    await _prefs!
        .setInt(kLastActiveKey, _lastActiveTime!.millisecondsSinceEpoch);
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      final now = DateTime.now();

      bool momentumChanged = false;
      if (_lastClickTime != null &&
          now.difference(_lastClickTime!) > const Duration(seconds: 10) &&
          _momentumClicks != 0) {
        setState(() {
          _momentumClicks = 0;
        });
        momentumChanged = true;
      }

      setState(() {
        _goldOre += _orePerSecond;
        _totalGoldOre += _orePerSecond * _bonusOrePerSecond;
      });

      if (momentumChanged) {
        _updatePreviewPerClick();
      }

      _saveProgress();
    });
  }

  Future<void> _applyOfflineProgress() async {
    if (_lastActiveTime == null || _orePerSecond <= 0) {
      // Nothing to do, just update last active.
      await _saveProgress();
      return;
    }

    final now = DateTime.now();
    final diff = now.difference(_lastActiveTime!);
    final seconds = diff.inSeconds;

    // Ignore very short gaps (e.g., app switch for a second)
    if (seconds <= 60) {
      await _saveProgress();
      return;
    }

    final earned = seconds * _orePerSecond * _bonusOrePerSecond;

    setState(() {
      _goldOre += earned;
      _totalGoldOre += earned;
    });

    await _saveProgress();

    final durationText = _formatDuration(diff);

    final message = 'While you were away for $durationText,\n'
        'your miners produced ${earned.toStringAsFixed(0)} gold ore!';

    // Show the alert *after* first frame to avoid context issues in initState.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      alert_user(
        context,
        message,
        title: 'Offline Progress',
      );
    });
  }

  String _formatDuration(Duration d) {
    if (d.inHours >= 1) {
      final hours = d.inHours;
      final minutes = d.inMinutes % 60;
      if (minutes > 0) {
        return '${hours}h ${minutes}m';
      }
      return '${hours}h';
    } else if (d.inMinutes >= 1) {
      final minutes = d.inMinutes;
      final seconds = d.inSeconds % 60;
      if (seconds > 0) {
        return '${minutes}m ${seconds}s';
      }
      return '${minutes}m';
    } else {
      return '${d.inSeconds}s';
    }
  }

  double _calculateRebirthGold() {
    if (_totalGoldOre <= 0) return 0;

    // level = floor(log_100(total_gold_ore))
    double levelRaw = math.log(_totalGoldOre) / math.log(100);
    levelRaw *= levelRaw;


    double manualClick;
    if(_manualClickCount == 0){
      manualClick = 0;
    }else{
      manualClick = math.log(_manualClickCount) / math.log(10) - 1;
      manualClick = math.max(manualClick.floor(), 0).toDouble();
    }

    return levelRaw.floorToDouble() + manualClick;
  }

  Future<void> _clearCardUpgradeCounts() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.remove(kCardUpgradeCountsKey);
  }

  Future<void> _clearUpgradeDeckSnapshot() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.remove(kUpgradeDeckSnapshotKey);
  }

  Future<void> _attemptRebirth() async {
    final rebirthGold = _calculateRebirthGold();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Rebirth'),
        content: Text(
          'Rebirth will reset your gold ore, total gold ore, and ore per second '
              'back to 0, and grant you ${rebirthGold.toStringAsFixed(0)} refined gold.\n\n'
              'Do you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Rebirth'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Determine which Next Run option is currently selected
    _prefs ??= await SharedPreferences.getInstance();
    final selectedGoal =
        _prefs!.getString(kNextRunSelectedKey) ?? 'mine_gold';

    setState(() {
      // Update the rebirth goal for this run
      _rebirthGoal = selectedGoal;

      // Award gold + total refined gold
      _gold += rebirthGold;
      _totalRefinedGold += rebirthGold;

      // Increment rebirth count only if reward > 0
      if (rebirthGold > 0) {
        _rebirthCount += 1;
      }

      // Reset ore values
      _goldOre = 0;
      _totalGoldOre = 0;
      _orePerSecond = 0;
      _bonusOrePerSecond = 1;

      // Reset click-related stats for the new run
      _baseOrePerClick = 0.0;
      _lastComputedOrePerClick = 1.0;

      // Reset momentum for the new run
      _momentumClicks = 0;
      _lastClickTime = null;

      // Reset manual click count for the new run
      _manualClickCount = 0;
    });

    // Clear per-run card upgrades and the frozen upgrade deck snapshot
    // so the next run's upgrade pool is rebuilt from the active deck.
    await _clearCardUpgradeCounts();
    await _clearUpgradeDeckSnapshot();

    await _saveProgress();
    _updatePreviewPerClick();

    final runGoalText =
    _rebirthGoal == 'mine_gold' ? 'Mine gold' : _rebirthGoal;

    await alert_user(
      context,
      'You rebirthed and gained ${rebirthGold.toStringAsFixed(0)} refined gold!\n'
          'Total rebirths: $_rebirthCount\n'
          'Total refined gold: ${_totalRefinedGold.toStringAsFixed(0)}\n'
          'Run goal: $runGoalText',
      title: 'Rebirth Complete',
    );
  }

  /// For now: click value is base 1 per click + any per-click bonuses.
  void _updatePreviewPerClick() {
    setState(() {
      _lastComputedOrePerClick = 1.0 + _baseOrePerClick;
    });
  }

  /// Called when an upgrade is purchased in the Upgrades tab.
  ///
  /// [cardLevel] is the player's level for this card.
  /// [upgradesThisRun] is how many times this card has been upgraded
  /// so far in the *current* run (after this purchase).
  void _applyCardUpgradeEffect(
      GameCard card,
      int cardLevel,
      int upgradesThisRun,
      ) {
    setState(() {
      card.cardEffect?.call(this, cardLevel, upgradesThisRun);
    });
    _saveProgress();
  }

  /// Implementation of IdleGameEffectTarget: applies an ore/s delta.
  @override
  void addOrePerSecond(double amount) {
    _orePerSecond += amount;
  }

  /// Implementation of IdleGameEffectTarget: applies an instant ore gain.
  @override
  void addOre(double amount) {
    _goldOre += amount;
    _totalGoldOre += amount;
  }

  /// Implementation of IdleGameEffectTarget: modifies base ore per click.
  @override
  void addBaseOrePerClick(double amount) {
    _baseOrePerClick += amount;
    _updatePreviewPerClick();
  }

  /// Compute click phase for a given manual click count.
  ///
  /// log_clicks = ceil(log10(manualClicks)), with a minimum of 2
  /// phase = floor(manualClicks * 10 / 10^log_clicks)
  /// Clamped to [0, 9] so we always have a valid rock_0x.png.
  int _computeClickPhase(int manualClicks) {
    if (manualClicks <= 0) return 1;

    final double rawLog = math.log(manualClicks) / math.log(10);
    int logClicks = rawLog.ceil();
    if (logClicks < 2) logClicks = 2;

    final double denom = math.pow(10, logClicks).toDouble();
    final double value = manualClicks * 10 / denom;

    int phase = value.floor();
    if (phase <= 0) phase = 1;
    if (phase > 9) phase = 9;
    return phase;
  }

  /// Convenience wrapper that uses the current stored _manualClickCount.
  int _currentClickPhase() => _computeClickPhase(_manualClickCount);

  /// Top bar switches between Ore stats and Refined Gold
  /// depending on which main tab is selected.
  Widget _buildTopBar() {
    if (_currentTabIndex == 2) {
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
              'Refined Gold: ${_gold.toStringAsFixed(0)}',
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
              'Total Refined Gold: ${_totalRefinedGold.toStringAsFixed(0)}',
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
    _rebirthGoal == 'create_antimatter' ? 'Antimatter' : 'Gold Ore';

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16.0,
        vertical: 12.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            '$resourceLabel: ${_goldOre.toStringAsFixed(0)}',
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
            'Ore per second: ${_orePerSecond.toStringAsFixed(2)}',
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

  // ====== ROCK INTERACTION LOGIC ======

  /// Handle the *start* of a press/drag on the rock.
  /// Awards ore once and sets the initial tilt based on touch position.
  void _onRockPanDown(DragDownDetails details) {
    _handleRockPress(details.localPosition);
  }

  /// While dragging, update tilt and small positional offset to follow the finger.
  void _onRockPanUpdate(DragUpdateDetails details) {
    _updateRockTiltAndOffset(details.localPosition);
  }

  /// On release, rebound rock to normal.
  void _onRockPanEnd(DragEndDetails details) {
    _resetRockTransform();
  }

  /// Also rebound if the gesture is cancelled.
  void _onRockPanCancel() {
    _resetRockTransform();
  }

  void _handleRockPress(Offset localPosition) {
    // Remember where the press started for drag calculations.
    _rockPressLocalPosition = localPosition;

    // Momentum handling (future use)
    final now = DateTime.now();
    if (_lastClickTime == null ||
        now.difference(_lastClickTime!) > const Duration(seconds: 10)) {
      _momentumClicks = 0;
    }
    _momentumClicks += 1;
    _lastClickTime = now;

    const double rockSize = 440.0;
    final double tapX = localPosition.dx.clamp(0.0, rockSize);
    final double tapY = localPosition.dy.clamp(0.0, rockSize);
    final double center = rockSize / 2;

    // Normalize to [-1, 1], where 0 is center.
    final double normX = (tapX - center) / center; // left -1, right +1
    final double normY = (tapY - center) / center; // top -1, bottom +1

    // Max tilt angle for a "pressed in" feel.
    const double maxTilt = 4 * math.pi / 18;

    // We want the rock to tilt *toward* the press.
    final double tiltX = normY * maxTilt;
    final double tiltY = -normX * maxTilt;

    // Compute phase for this click using the *new* click index.
    final int clicksAfterThis = _manualClickCount + 1;
    final int phase = _computeClickPhase(clicksAfterThis);
    final double multiplier = phase == 9 ? 10.0 : 1.0;

    final double orePerClick = (1.0 + _baseOrePerClick) * multiplier;

    setState(() {
      // Animate: shrink + 3D tilt toward tap point.
      _rockScale = 0.9;
      _rockTiltX = tiltX;
      _rockTiltY = tiltY;

      // No drag offset yet; only applied once the finger moves.
      _rockOffsetX = 0.0;
      _rockOffsetY = 0.0;

      // Game logic.
      _goldOre += orePerClick;
      _totalGoldOre += orePerClick;
      _lastComputedOrePerClick = orePerClick;
      _manualClickCount = clicksAfterThis;
    });

    _saveProgress();
  }

  void _updateRockTiltAndOffset(Offset localPosition) {
    // If for some reason we missed the press, just tilt without offset.
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

    // Tilt based on where inside the rock the finger currently is.
    const double rockSize = 440.0;
    final double tapX = localPosition.dx.clamp(0.0, rockSize);
    final double tapY = localPosition.dy.clamp(0.0, rockSize);
    final double center = rockSize / 2;

    final double normX = (tapX - center) / center; // -1 to 1
    final double normY = (tapY - center) / center; // -1 to 1

    const double maxTilt = 4 * math.pi / 18;

    final double tiltX = normY * maxTilt;
    final double tiltY = -normX * maxTilt;

    // Drag offset: 20% of the cursor movement from the press point.
    const double dragFactor = 0.2;
    const double maxOffset = 200.0; // keep it small

    final Offset delta = localPosition - _rockPressLocalPosition!;
    double offsetX = delta.dx * dragFactor;
    double offsetY = delta.dy * dragFactor;

    // Clamp to a small radius so it doesn't fly away.
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

  // ====== END ROCK INTERACTION LOGIC ======

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Transparent so background image shows fully.
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(kGameBackgroundAsset),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              const SizedBox(height: 8),
              // Main tab content area fills everything down to bottom nav bar.
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: _buildTabContent(),
                ),
              ),
            ],
          ),
        ),
      ),

      // Bottom tab navigation
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTabIndex,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          setState(() {
            _currentTabIndex = index;
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

  /// Returns the widget for the currently selected tab.
  Widget _buildTabContent() {
    switch (_currentTabIndex) {
      case 0:
        return _buildMainTab();
      case 1:
        return _buildUpgradesTab();
      case 2:
        return _buildRebirthTab();
      case 3:
        return _buildStatsTab();
      case 4:
        return _buildMiscTab();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildMainTab() {
    final rebirthGold = _calculateRebirthGold();

    final buttonLabelBase =
    _rebirthGoal == 'create_antimatter' ? 'Create Antimatter' : 'Mine Gold Ore';

    final preview = _lastComputedOrePerClick;

    final int phase = _currentClickPhase();
    final String buttonLabel;
    if (phase == 9) {
      buttonLabel = 'Gold Vein Found! All clicks have 10x power';
    } else {
      buttonLabel = '$buttonLabelBase (+${preview.toStringAsFixed(0)})';
    }

    // Image changes with phase: rock_0x.png where x is the phase (0–9).
    final String rockAssetPath =
        'assets/click_screen_art/gold_mining/rock_0$phase.png';

    // Column fills the available height in the main tab.
    // Content at top, rebirth button pinned to bottom (above nav bar).
    return Column(
      children: [
        // Main content area
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 440,
                  height: 440,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanDown: _onRockPanDown,
                    onPanUpdate: _onRockPanUpdate,
                    onPanEnd: _onRockPanEnd,
                    onPanCancel: _onRockPanCancel,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 80),
                      curve: Curves.easeOut,
                      transformAlignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.0015) // perspective for foreshortening
                        ..translate(_rockOffsetX, _rockOffsetY)
                        ..scale(_rockScale)
                        ..rotateX(_rockTiltX)
                        ..rotateY(_rockTiltY),
                      child: Image.asset(
                        rockAssetPath,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  buttonLabel,
                  style: const TextStyle(
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
              ],
            ),
          ),
        ),

        // Rebirth button at bottom of Main tab only
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _attemptRebirth,
              child: Text(
                'Rebirth and gain ${rebirthGold.toStringAsFixed(0)} gold',
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUpgradesTab() {
    final resourceLabel =
    _rebirthGoal == 'create_antimatter' ? 'Antimatter' : 'Gold Ore';

    return UpgradesScreen(
      currentResource: _goldOre,
      resourceLabel: resourceLabel,
      onSpendResource: (amount) {
        setState(() {
          _goldOre -= amount;
          if (_goldOre < 0) _goldOre = 0;
        });
        _saveProgress();
      },
      onCardUpgradeEffect: _applyCardUpgradeEffect,
    );
  }

  Widget _buildRebirthTab() {
    // Rebirth tab with its own nested tabs (Next Run / Store / Deck / Achievements).
    return RebirthScreen(
      currentGold: _gold,
      onSpendGold: (amount) {
        setState(() {
          _gold -= amount;
          if (_gold < 0) _gold = 0;
        });
        _saveProgress();
      },
    );
  }

  Widget _buildStatsTab() {
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

  Widget _buildMiscTab() {
    return const Center(
      child: Text(
        'Misc options coming soon...',
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
}
