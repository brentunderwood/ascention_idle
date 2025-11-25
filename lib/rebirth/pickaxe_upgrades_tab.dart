import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Definition model for a pickaxe upgrade.
class _UpgradeDef {
  final String id;
  final String name;
  final String shortDescription;
  final String longDescription;
  final IconData icon;

  const _UpgradeDef({
    required this.id,
    required this.name,
    required this.shortDescription,
    required this.longDescription,
    required this.icon,
  });
}

class PickaxeUpgradesTab extends StatefulWidget {
  final double currentGold;
  final ValueChanged<double> onSpendGold;

  const PickaxeUpgradesTab({
    super.key,
    required this.currentGold,
    required this.onSpendGold,
  });

  @override
  State<PickaxeUpgradesTab> createState() => _PickaxeUpgradesTabState();
}

class _PickaxeUpgradesTabState extends State<PickaxeUpgradesTab> {
  static const List<_UpgradeDef> _upgrades = [
    _UpgradeDef(
      id: 'base_gold_per_click',
      name: 'Base gold per click',
      shortDescription: 'Increases the base amount of gold gained per click.',
      longDescription:
      'Each level increases the base gold gained per click before '
          'any bonuses or multipliers are applied.',
      icon: Icons.circle, // placeholder
    ),
    _UpgradeDef(
      id: 'base_antimatter_per_click',
      name: 'Base antimatter per click',
      shortDescription: 'Increases the base amount of antimatter gained per click.',
      longDescription:
      'Each level increases the base antimatter gained per click, '
          'unlocking deeper late-game progression.',
      icon: Icons.blur_on,
    ),
    _UpgradeDef(
      id: 'bonus_gold_per_click',
      name: 'Bonus gold per click',
      shortDescription: 'Adds a bonus to gold gained per click.',
      longDescription:
      'Each level increases the additive bonus applied to every click, '
          'stacking with your base gold per click.',
      icon: Icons.add_circle_outline,
    ),
    _UpgradeDef(
      id: 'bonus_antimatter_per_click',
      name: 'Bonus antimatter per click',
      shortDescription: 'Adds a bonus to antimatter gained per click.',
      longDescription:
      'Each level increases the additive bonus antimatter gained per click, '
          'helping you push late-game upgrades faster.',
      icon: Icons.stars,
    ),
    _UpgradeDef(
      id: 'upgrade_scaling_factor',
      name: 'Upgrade scaling factor',
      shortDescription: 'Reduces how quickly upgrade costs scale up.',
      longDescription:
      'Each level slightly improves the global scaling of certain upgrades, '
          'making future upgrades more affordable.',
      icon: Icons.trending_down,
    ),
    _UpgradeDef(
      id: 'frenzy_multiplier',
      name: 'Frenzy multiplier',
      shortDescription: 'Boosts gains during Frenzy.',
      longDescription:
      'Each level increases the multiplier applied to gold and antimatter '
          'gains while Frenzy is active.',
      icon: Icons.flash_on,
    ),
    _UpgradeDef(
      id: 'frenzy_duration',
      name: 'Frenzy duration',
      shortDescription: 'Increases how long Frenzy lasts.',
      longDescription:
      'Each level extends the duration of Frenzy, giving you more time '
          'with boosted production.',
      icon: Icons.timelapse,
    ),
    _UpgradeDef(
      id: 'frenzy_cooldown',
      name: 'Frenzy cooldown',
      shortDescription: 'Reduces the cooldown between Frenzy activations.',
      longDescription:
      'Each level reduces the time you must wait before triggering Frenzy again.',
      icon: Icons.hourglass_bottom,
    ),
    _UpgradeDef(
      id: 'momentum_value',
      name: 'Momentum value',
      shortDescription: 'Improves the strength of your momentum system.',
      longDescription:
      'Each level increases how much benefit you gain per unit of momentum, '
          'boosting sustained play sessions.',
      icon: Icons.trending_up,
    ),
    _UpgradeDef(
      id: 'momentum_cap',
      name: 'Momentum cap',
      shortDescription: 'Raises the maximum momentum you can store.',
      longDescription:
      'Each level increases your maximum momentum cap, allowing for larger '
          'long-term bonuses.',
      icon: Icons.vertical_align_top,
    ),
  ];

  final Map<String, int> _levels = {};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadLevels();
  }

  Future<void> _loadLevels() async {
    final prefs = await SharedPreferences.getInstance();
    for (final up in _upgrades) {
      final key = _prefsKeyFor(up.id);
      final stored = prefs.getInt(key);
      _levels[up.id] = stored ?? 1; // default level 1
    }
    setState(() {
      _loaded = true;
    });
  }

  String _prefsKeyFor(String id) => 'pickaxe_upgrade_${id}_level';

  int _getLevel(String id) => _levels[id] ?? 1;

  int _costForLevel(int level) {
    // cost = 1.25^level rounded to nearest whole number, minimum 1
    final raw = math.pow(1.25, level);
    final rounded = raw.round();
    return rounded < 1 ? 1 : rounded;
  }

  Future<void> _buyUpgrade(_UpgradeDef upgrade) async {
    final currentLevel = _getLevel(upgrade.id);
    final cost = _costForLevel(currentLevel);

    if (widget.currentGold < cost) {
      // Not enough gold; could show feedback later.
      return;
    }

    final newLevel = currentLevel + 1;

    setState(() {
      _levels[upgrade.id] = newLevel;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefsKeyFor(upgrade.id), newLevel);

    // Deduct gold via callback so IdleGameScreen stays the source of truth.
    widget.onSpendGold(cost.toDouble());
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Container(
      color: Colors.black.withOpacity(0.3),
      width: double.infinity,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Upgrade Your Mining Equipment',
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
            const SizedBox(height: 12),
            ..._upgrades.map((up) {
              final level = _getLevel(up.id);
              final cost = _costForLevel(level);
              final canAfford = widget.currentGold >= cost;

              final cardColor = canAfford
                  ? Colors.white.withOpacity(0.18)
                  : Colors.white.withOpacity(0.06);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Card(
                  color: cardColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Icon / future image slot
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Icon(
                            up.icon,
                            size: 32,
                            color: canAfford
                                ? Colors.amberAccent
                                : Colors.grey.shade500,
                          ),
                        ),

                        // Name + description (takes most of the width)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                up.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Level $level',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                up.shortDescription,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade200,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 8),

                        // Buy button + cost
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            ElevatedButton(
                              onPressed:
                              canAfford ? () => _buyUpgrade(up) : null,
                              child: const Text('Buy'),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Cost: $cost',
                              style: TextStyle(
                                fontSize: 12,
                                color: canAfford
                                    ? Colors.amberAccent
                                    : Colors.grey.shade400,
                              ),
                            ),
                          ],
                        ),

                        // Info button
                        IconButton(
                          icon: const Icon(
                            Icons.info_outline,
                            size: 20,
                            color: Colors.white70,
                          ),
                          onPressed: () {
                            showDialog<void>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: Text(up.name),
                                content: Text(
                                  '${up.longDescription}\n\n'
                                      'Current level: $level\n'
                                      'Next upgrade cost: $cost gold.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(),
                                    child: const Text('OK'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}
