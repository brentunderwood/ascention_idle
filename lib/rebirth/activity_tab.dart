import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Definition model for a "Next Run" game mode option.
class _ActivityOption {
  final String id; // 'gold' or 'antimatter'
  final String name;
  final String description;
  final IconData icon;
  final bool lockedByDefault;
  final int unlockCost; // in refined gold

  const _ActivityOption({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    this.lockedByDefault = false,
    this.unlockCost = 0,
  });
}

class ActivityTab extends StatefulWidget {
  final double currentGold;
  final ValueChanged<double> onSpendGold;

  const ActivityTab({
    super.key,
    required this.currentGold,
    required this.onSpendGold,
  });

  @override
  State<ActivityTab> createState() => _ActivityTabState();
}

class _ActivityTabState extends State<ActivityTab> {
  static const List<_ActivityOption> _options = [
    _ActivityOption(
      id: 'gold',
      name: 'Mine gold',
      description:
      'Focus this run on generating as much gold ore as possible.',
      icon: Icons.attach_money,
      lockedByDefault: false,
    ),
    _ActivityOption(
      id: 'antimatter',
      name: 'Create antimatter',
      description:
      'Convert your efforts into antimatter instead of gold for advanced progression.',
      icon: Icons.bubble_chart,
      lockedByDefault: true,
      unlockCost: 100,
    ),
  ];

  static const String _selectedKey = 'next_run_selected_option';
  String? _selectedId;
  final Map<String, bool> _unlocked = {};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    // Load unlock states
    for (final opt in _options) {
      final key = _unlockKey(opt.id);
      bool? stored = prefs.getBool(key);

      // Backwards compatibility for antimatter unlock:
      // old key: 'next_run_create_antimatter_unlocked'
      if (stored == null && opt.id == 'antimatter') {
        stored = prefs.getBool('next_run_create_antimatter_unlocked');
      }

      if (stored != null) {
        _unlocked[opt.id] = stored;
      } else {
        _unlocked[opt.id] = !opt.lockedByDefault;
      }
    }

    // Load selected option.
    //
    // Backwards compatibility:
    //   'mine_gold'         -> 'gold'
    //   'create_antimatter' -> 'antimatter'
    final storedSelected = prefs.getString(_selectedKey);
    String resolvedSelected;
    if (storedSelected == 'mine_gold') {
      resolvedSelected = 'gold';
    } else if (storedSelected == 'create_antimatter') {
      resolvedSelected = 'antimatter';
    } else if (storedSelected != null &&
        _options.any((o) => o.id == storedSelected)) {
      resolvedSelected = storedSelected;
    } else {
      resolvedSelected = 'gold';
    }

    _selectedId = resolvedSelected;

    // Persist back in normalized form.
    await prefs.setString(_selectedKey, resolvedSelected);

    setState(() {
      _loaded = true;
    });
  }

  String _unlockKey(String id) => 'next_run_${id}_unlocked';

  Future<void> _selectOption(_ActivityOption option) async {
    if (!_isUnlocked(option.id)) return;

    setState(() {
      _selectedId = option.id; // 'gold' or 'antimatter'
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedKey, option.id);
  }

  bool _isUnlocked(String id) {
    return _unlocked[id] ?? false;
  }

  Future<void> _unlockOption(_ActivityOption option) async {
    if (_isUnlocked(option.id)) return;
    if (widget.currentGold < option.unlockCost) {
      return;
    }

    setState(() {
      _unlocked[option.id] = true;
      _selectedId ??= option.id;
    });

    final prefs = await SharedPreferences.getInstance();
    final key = _unlockKey(option.id);
    await prefs.setBool(key, true);

    // Also write the old antimatter key for backwards compatibility if needed.
    if (option.id == 'antimatter') {
      await prefs.setBool('next_run_create_antimatter_unlocked', true);
    }

    await prefs.setString(_selectedKey, _selectedId!);

    // Spend refined gold via callback
    widget.onSpendGold(option.unlockCost.toDouble());
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      color: Colors.black.withOpacity(0.3),
      width: double.infinity,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _options.map((opt) {
            final unlocked = _isUnlocked(opt.id);
            final isSelected = _selectedId == opt.id;

            final cardColor = unlocked
                ? (isSelected
                ? Colors.white.withOpacity(0.22)
                : Colors.white.withOpacity(0.10))
                : Colors.white.withOpacity(0.06);

            final canAffordUnlock =
                widget.currentGold >= opt.unlockCost && opt.unlockCost > 0;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: unlocked ? () => _selectOption(opt) : null,
                child: Card(
                  color: cardColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Stack(
                    children: [
                      // Base content
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Icon
                            Padding(
                              padding:
                              const EdgeInsets.only(right: 8.0),
                              child: Icon(
                                opt.icon,
                                size: 32,
                                color: unlocked
                                    ? (isSelected
                                    ? Colors.amberAccent
                                    : Colors.white)
                                    : Colors.grey.shade500,
                              ),
                            ),

                            // Title + description
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    opt.name,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    opt.description,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  if (isSelected && unlocked)
                                    Text(
                                      'Selected game mode: ${opt.id}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.greenAccent
                                            .withOpacity(0.9),
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 8),

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
                                    title: Text(opt.name),
                                    content: Text(
                                      opt.description +
                                          (opt.lockedByDefault
                                              ? '\n\nUnlock cost: ${opt.unlockCost} refined gold.'
                                              : ''),
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

                      // Locked overlay
                      if (!unlocked)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.80),
                              borderRadius:
                              BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'Locked',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ElevatedButton(
                                    onPressed: () {
                                      if (canAffordUnlock) {
                                        _unlockOption(opt);
                                      } else {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                                'Not enough gold'),
                                            duration:
                                            Duration(seconds: 2),
                                          ),
                                        );
                                      }
                                    },
                                    child: Text(
                                      'Unlock (${opt.unlockCost} gold)',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
