import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'alerts.dart';
import 'rebirth_screen.dart';

/// Change this to swap the background later.
const String kGameBackgroundAsset = 'assets/background_game.png';

/// Keys used for local persistence.
const String kGoldOreKey = 'gold_ore';
const String kGoldKey = 'gold';
const String kTotalGoldOreKey = 'total_gold_ore';
const String kOrePerSecondKey = 'ore_per_second';
const String kLastActiveKey = 'last_active_millis';
const String kRebirthCountKey = 'rebirth_count';
const String kTotalRefinedGoldKey = 'total_refined_gold';

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
/// Swap icons here if you want different ones.
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

  int _rebirthCount = 0;
  double _totalRefinedGold = 0;

  Timer? _timer;
  SharedPreferences? _prefs;
  DateTime? _lastActiveTime;

  @override
  void initState() {
    super.initState();
    _initAndStart();
  }

  Future<void> _initAndStart() async {
    await _loadProgress();
    await _applyOfflineProgress();
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
    final storedLastActive = _prefs!.getInt(kLastActiveKey);
    final storedRebirthCount = _prefs!.getInt(kRebirthCountKey);
    final storedTotalRefinedGold = _prefs!.getDouble(kTotalRefinedGoldKey);

    setState(() {
      _goldOre = storedGoldOre ?? 0;
      _totalGoldOre = storedTotalGoldOre ?? 0;
      _gold = storedGold ?? 0;
      _orePerSecond = storedOrePerSecond ?? 1;
      _rebirthCount = storedRebirthCount ?? 0;
      _totalRefinedGold = storedTotalRefinedGold ?? 0;
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
    await _prefs!.setInt(kRebirthCountKey, _rebirthCount);
    await _prefs!.setDouble(kTotalRefinedGoldKey, _totalRefinedGold);
    await _prefs!
        .setInt(kLastActiveKey, _lastActiveTime!.millisecondsSinceEpoch);
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _goldOre += _orePerSecond;
        _totalGoldOre += _orePerSecond;
      });
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
    if (seconds <= 5) {
      await _saveProgress();
      return;
    }

    final earned = seconds * _orePerSecond;

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
    final levelRaw = math.log(_totalGoldOre) / math.log(100);
    final level = levelRaw.floor();
    if (level <= 0) return 0;

    // gold = level * (level + 1) / 2
    return level * (level + 1) / 2.0;
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

    setState(() {
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
    });

    await _saveProgress();

    await alert_user(
      context,
      'You rebirthed and gained ${rebirthGold.toStringAsFixed(0)} refined gold!\n'
          'Total rebirths: $_rebirthCount\n'
          'Total refined gold: ${_totalRefinedGold.toStringAsFixed(0)}',
      title: 'Rebirth Complete',
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
              // Top stats area
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 12.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Current gold ore (big text)
                    Text(
                      'Gold Ore: ${_goldOre.toStringAsFixed(0)}',
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

                    // Ore generated each second (smaller text)
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
              ),

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

    // Column fills the available height in the main tab.
    // Content at top, rebirth button pinned to bottom (above nav bar).
    return Column(
      children: [
        // Main content area
        Expanded(
          child: Center(
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  // Example: increment some values when user taps
                  _goldOre += 10;
                  _totalGoldOre += 10;
                  _orePerSecond += 0.5;
                });
                _saveProgress();
              },
              child: const Text('Mine 10 Gold Ore (example)'),
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
    // Rebirth tab with its own nested tabs (Store/Deck/Collection).
    return RebirthScreen(currentGold: _gold);
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
