import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'alerts.dart';
import 'rebirth/rebirth_screen.dart';
import 'cards/player_collection_repository.dart';

/// Change this to swap the background later.
const String kGameBackgroundAsset = 'assets/background_game.png';

/// Keys used for local persistence.
const String kGoldOreKey = 'gold_ore';
const String kGoldKey = 'gold';
const String kTotalGoldOreKey = 'total_gold_ore';
const String kOrePerSecondKey = 'ore_per_second';
const String kBonusOrePerSecondKey = 'bonus_ore_per_second';
const String kLastActiveKey = 'last_active_millis';
const String kRebirthCountKey = 'rebirth_count';
const String kTotalRefinedGoldKey = 'total_refined_gold';
const String kRebirthGoalKey = 'rebirth_goal';

/// This key is used by the NextRunTab in rebirth_screen.dart.
const String kNextRunSelectedKey = 'next_run_selected_option';

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

class _IdleGameScreenState extends State<IdleGameScreen> {
  int _currentTabIndex = 0;

  double _goldOre = 0;
  double _totalGoldOre = 0;
  double _gold = 0.0;
  double _orePerSecond = 0;
  double _bonusOrePerSecond = 1;

  int _rebirthCount = 0;
  double _totalRefinedGold = 0;

  /// Which goal applies to the *current* run
  /// (e.g., 'mine_gold' or 'create_antimatter').
  String _rebirthGoal = 'mine_gold';

  /// Momentum system for clicks.
  int _momentumClicks = 0;
  DateTime? _lastClickTime;

  /// Cached value for previewing how much will be gained on the next click.
  double _lastComputedOrePerClick = 0.0;

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
    await _updatePreviewPerClick();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    // Save one last time (fire-and-forget)
    _saveProgress();
    super.dispose();
  }

  // IDs must match the ones used in PickaxeUpgradesTab in rebirth_screen.dart
  static const List<String> _pickaxeUpgradeIds = [
    'base_gold_per_click',
    'base_antimatter_per_click',
    'bonus_gold_per_click',
    'bonus_antimatter_per_click',
    'upgrade_scaling_factor',
    'frenzy_multiplier',
    'frenzy_duration',
    'frenzy_cooldown',
    'momentum_value',
    'momentum_cap',
  ];

  Future<void> _loadProgress() async {
    _prefs ??= await SharedPreferences.getInstance();

    final storedGoldOre = _prefs!.getDouble(kGoldOreKey);
    final storedTotalGoldOre = _prefs!.getDouble(kTotalGoldOreKey);
    final storedGold = _prefs!.getDouble(kGoldKey);
    final storedOrePerSecond = _prefs!.getDouble(kOrePerSecondKey);
    final storedBonusOrePerSecond = _prefs!.getDouble(kBonusOrePerSecondKey);
    final storedLastActive = _prefs!.getInt(kLastActiveKey);
    final storedRebirthCount = _prefs!.getInt(kRebirthCountKey);
    final storedTotalRefinedGold = _prefs!.getDouble(kTotalRefinedGoldKey);
    final storedRebirthGoal = _prefs!.getString(kRebirthGoalKey);

    setState(() {
      _goldOre = storedGoldOre ?? 0;
      _totalGoldOre = storedTotalGoldOre ?? 0;
      _gold = storedGold ?? 0;
      _orePerSecond = storedOrePerSecond ?? 0;
      _bonusOrePerSecond = storedBonusOrePerSecond ?? 0;
      _rebirthCount = storedRebirthCount ?? 0;
      _totalRefinedGold = storedTotalRefinedGold ?? 0;
      _rebirthGoal = storedRebirthGoal ?? 'mine_gold';
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
    await _prefs!.setDouble(kBonusOrePerSecondKey, _bonusOrePerSecond);
    await _prefs!.setInt(kRebirthCountKey, _rebirthCount);
    await _prefs!.setDouble(kTotalRefinedGoldKey, _totalRefinedGold);
    await _prefs!.setString(kRebirthGoalKey, _rebirthGoal);
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
        await _updatePreviewPerClick();
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

    final message =
        'While you were away for $durationText,\n'
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

    return 1.0*levelRaw.floor();
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

      // Reset momentum for the new run
      _momentumClicks = 0;
      _lastClickTime = null;
    });

    await _saveProgress();
    await _updatePreviewPerClick();

    await alert_user(
      context,
      'You rebirthed and gained ${rebirthGold.toStringAsFixed(0)} refined gold!\n'
          'Total rebirths: $_rebirthCount\n'
          'Total refined gold: ${_totalRefinedGold.toStringAsFixed(0)}\n'
          'Run goal: ${_rebirthGoal == 'mine_gold' ? 'Mine gold' : _rebirthGoal}',
      title: 'Rebirth Complete',
    );
  }

  /// Reads pickaxe upgrade levels from SharedPreferences and returns
  /// the resource per click according to the current rebirth goal.
  ///
  /// For gold-mining runs:
  ///   base = 1.25^[base_gold_per_click level]
  ///   bonus = ore_per_second * [bonus_gold_per_click level] / 10000
  ///   raw = base + bonus
  ///
  ///   momentum_multiplier = 1 + momentumClicks * sqrt(momentum_value_level) / 1000
  ///   capped at 1 + [momentum_cap level] / 10
  ///
  /// For other goals (e.g. create_antimatter):
  /// same structure but using the antimatter pickaxe levels.
  Future<double> _computeOrePerClick({bool no_bonuses=false}) async {
    _prefs ??= await SharedPreferences.getInstance();

    int _getLevel(String id) {
      final key = 'pickaxe_upgrade_${id}_level';
      return _prefs!.getInt(key) ?? 1;
    }

    final int baseLevel;
    final int bonusLevel;
    if (_rebirthGoal == 'mine_gold') {
      baseLevel = _getLevel('base_gold_per_click');
      bonusLevel = _getLevel('bonus_gold_per_click');
    } else {
      baseLevel = _getLevel('base_antimatter_per_click');
      bonusLevel = _getLevel('bonus_antimatter_per_click');
    }

    final momentumValueLevel = _getLevel('momentum_value');
    final momentumCapLevel = _getLevel('momentum_cap');

    // base term: 1.25 ^ baseLevel
    final baseTerm = math.pow(1.25, baseLevel).toDouble();

    // bonus term: orePerSecond * bonusLevel / 10000
    final bonusTerm = _orePerSecond * (bonusLevel / 10000.0);

    final double raw;
    if(no_bonuses){
      raw = baseTerm;
    }else{
      raw = baseTerm + bonusTerm;
    }

    // momentum multiplier
    double momentumMultiplier =
        1 + _momentumClicks * math.pow(momentumValueLevel, 0.5) / 10000.0;

    // cap: 1 + [momentum cap level] / 10
    final maxMultiplier = 1 + momentumCapLevel / 10.0;
    if (momentumMultiplier > maxMultiplier) {
      momentumMultiplier = maxMultiplier;
    }

    return raw * momentumMultiplier;
  }

  /// Helper: recompute and cache the current per-click amount for preview text.
  Future<void> _updatePreviewPerClick() async {
    final value = await _computeOrePerClick();
    setState(() {
      _lastComputedOrePerClick = value;
    });
  }

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
    final buttonLabel =
        '$buttonLabelBase (+${preview.toStringAsFixed(0)})';

    // Column fills the available height in the main tab.
    // Content at top, rebirth button pinned to bottom (above nav bar).
    return Column(
      children: [
        // Main content area
        Expanded(
          child: Center(
            child: ElevatedButton(
              onPressed: () async {
                // Handle momentum first
                final now = DateTime.now();
                if (_lastClickTime == null ||
                    now.difference(_lastClickTime!) >
                        const Duration(seconds: 10)) {
                  _momentumClicks = 0;
                }
                _momentumClicks += 1;
                _lastClickTime = now;

                // Compute ore per click based on rebirth goal + upgrades + momentum
                double bonusDelta = 0;
                double orePerClick = await _computeOrePerClick();
                double clickCap = await _computeOrePerClick(no_bonuses: true) + 10 * _orePerSecond * _bonusOrePerSecond;
                if(orePerClick > clickCap){
                  bonusDelta = orePerClick / clickCap;
                }

                setState(() {
                  _goldOre += orePerClick;
                  _totalGoldOre += orePerClick;
                  _lastComputedOrePerClick = orePerClick;
                  _orePerSecond += bonusDelta / 1000000;
                  _bonusOrePerSecond += bonusDelta / 1000000;
                });
                _saveProgress();
              },
              child: Text(buttonLabel),
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
    return const Center(
      child: Text(
        'Upgrades coming soon...',
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

  Widget _buildRebirthTab() {
    // Rebirth tab with its own nested tabs (Next Run / Store / Deck / Pickaxe).
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
