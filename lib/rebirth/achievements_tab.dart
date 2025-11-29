import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'achievements_catalog.dart';

class AchievementsTab extends StatefulWidget {
  final double currentGold;
  final ValueChanged<double> onSpendGold;

  /// Current global achievement multiplier to display in the header.
  final double achievementMultiplier;

  const AchievementsTab({
    super.key,
    required this.currentGold,
    required this.onSpendGold,
    required this.achievementMultiplier,
  });

  @override
  State<AchievementsTab> createState() => _AchievementsTabState();
}

class _AchievementUiState {
  final int level;
  final double progress;

  const _AchievementUiState({
    required this.level,
    required this.progress,
  });
}

class _AchievementsTabState extends State<AchievementsTab> {
  bool _loading = true;
  Map<String, _AchievementUiState> _states = {};

  @override
  void initState() {
    super.initState();
    _loadAchievements();
  }

  Future<void> _loadAchievements() async {
    final prefs = await SharedPreferences.getInstance();
    final map = <String, _AchievementUiState>{};

    for (final def in kAchievementCatalog) {
      final levelKey = _achievementLevelKey(def.id);
      final progressKey = _achievementProgressKey(def.id);

      final level = prefs.getInt(levelKey) ?? 0;
      final progress = prefs.getDouble(progressKey) ?? 0.0;

      map[def.id] = _AchievementUiState(
        level: level,
        progress: progress,
      );
    }

    if (!mounted) return;
    setState(() {
      _states = map;
      _loading = false;
    });
  }

  String _achievementLevelKey(String id) => 'achievement_${id}_level';
  String _achievementProgressKey(String id) => 'achievement_${id}_progress';

  double _nextTarget(AchievementDefinition def, int level) {
    return def.baseTarget * math.pow(10.0, level).toDouble();
  }

  /// Decide whether an achievement is considered "completed".
  ///
  /// With the current semantics:
  /// - unique == true  → one-shot; once level > 0, it is completed.
  /// - unique == false → recurring; never fully "done" (always has another level).
  bool _isAchievementCompleted(
      AchievementDefinition def,
      int level,
      double progress,
      double target,
      ) {
    if (def.unique) {
      // One-shot: as soon as you have at least 1 level, treat as complete.
      return level > 0;
    }
    // Recurring achievements are never permanently complete.
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.3),
      width: double.infinity,
      child: _loading
          ? const Center(
        child: CircularProgressIndicator(),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Achievements',
                    style: TextStyle(
                      fontSize: 22,
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
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white70),
                  tooltip: 'Refresh achievements',
                  onPressed: () {
                    setState(() {
                      _loading = true;
                    });
                    _loadAchievements();
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),

            // New multiplier info box (replaces the old "Persistent, scaling..." text).
            _buildMultiplierInfoBox(),

            const SizedBox(height: 16),

            // Achievements: incomplete first, completed at the bottom.
            ..._buildOrderedAchievementCards(),
          ],
        ),
      ),
    );
  }

  Widget _buildMultiplierInfoBox() {
    final double m = widget.achievementMultiplier;
    final String mText = m.toStringAsFixed(2);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.45),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.star,
            size: 20,
            color: Colors.amber,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Current achievement multiplier: ×$mText',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the list of achievement cards in the desired order:
  /// - All *incomplete* achievements first (in catalog order).
  /// - All *completed* achievements afterwards (also in catalog order).
  List<Widget> _buildOrderedAchievementCards() {
    final List<Widget> widgets = [];

    final List<AchievementDefinition> incompleteDefs = [];
    final List<AchievementDefinition> completedDefs = [];

    // First pass: classify each achievement as complete or incomplete.
    for (final def in kAchievementCatalog) {
      final ui = _states[def.id];
      final int level = ui?.level ?? 0;
      final double progress = ui?.progress ?? 0.0;
      final double target = _nextTarget(def, level);

      final bool isCompleted =
      _isAchievementCompleted(def, level, progress, target);

      if (isCompleted) {
        completedDefs.add(def);
      } else {
        incompleteDefs.add(def);
      }
    }

    // Second pass: build cards for incompletes first.
    for (final def in incompleteDefs) {
      final ui = _states[def.id];
      final int level = ui?.level ?? 0;
      final double progress = ui?.progress ?? 0.0;
      final double target = _nextTarget(def, level);

      widgets.add(
        _buildAchievementCard(
          def,
          level: level,
          progress: progress,
          target: target,
          isCompleted: false,
        ),
      );
      widgets.add(const SizedBox(height: 8));
    }

    // Then build cards for completed achievements.
    for (final def in completedDefs) {
      final ui = _states[def.id];
      final int level = ui?.level ?? 0;
      final double progress = ui?.progress ?? 0.0;
      final double target = _nextTarget(def, level);

      widgets.add(
        _buildAchievementCard(
          def,
          level: level,
          progress: progress,
          target: target,
          isCompleted: true,
        ),
      );
      widgets.add(const SizedBox(height: 8));
    }

    return widgets;
  }

  Widget _buildAchievementCard(
      AchievementDefinition def, {
        required int level,
        required double progress,
        required double target,
        required bool isCompleted,
      }) {
    final Color borderColor =
    isCompleted ? Colors.greenAccent : Colors.white24;
    final Color bgColor = isCompleted
        ? Colors.green.withOpacity(0.25)
        : Colors.white.withOpacity(0.06);
    final Color titleColor = Colors.white;
    const IconData icon = Icons.lock_open;

    final String progressLine = isCompleted
        ? 'Completed (no further progress available)'
        : 'Level: $level   •   Progress: ${_formatNumber(progress)} / ${_formatNumber(target)}';

    return Card(
      color: bgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 32,
              color: titleColor,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    def.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    def.description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    progressLine,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white60,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatNumber(double value) {
    if (value == 0) return '0';
    if (value.abs() >= 1e6 || value.abs() < 0.001) {
      return value.toStringAsExponential(2);
    }
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }
}
