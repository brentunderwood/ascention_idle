import 'dart:math' as math;
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../cards/game_card_models.dart';
import '../cards/card_catalog.dart';

/// Key used to store the player's collection in SharedPreferences.
const String kPlayerCollectionKey = 'player_collection';

/// Model for a card pack configuration.
/// You can later add more packs with different images / names.
class CardPackConfig {
  final String id;
  final String name;

  const CardPackConfig({
    required this.id,
    required this.name,
  });
}

class RebirthStoreTab extends StatelessWidget {
  final double currentGold;

  /// Callback to actually spend refined gold in the parent.
  final ValueChanged<double> onSpendGold;

  const RebirthStoreTab({
    super.key,
    required this.currentGold,
    required this.onSpendGold,
  });

  @override
  Widget build(BuildContext context) {
    const packs = [
      CardPackConfig(
        id: 'lux_aurea',
        name: 'Lux Aurea',
      ),
      CardPackConfig(
        id: 'vita_aurum',
        name: 'Vita Aurum',
      ),
    ];

    return Container(
      color: Colors.black.withOpacity(0.3),
      width: double.infinity,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Buy Card Packs',
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
            const SizedBox(height: 16),

            // Multiple pack tiles, reusable via CardPackConfig + RebirthPackTile
            ...packs.map(
                  (pack) => Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: RebirthPackTile(
                  config: pack,
                  currentGold: currentGold,
                  onSpendGold: onSpendGold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single card-pack widget with:
/// - Name above
/// - Simple rectangular image "card"
/// - Left/right arrows to change level (0–10)
/// - Cost (10^level)
/// - Buy button (random card from pack)
/// - Info button below
class RebirthPackTile extends StatefulWidget {
  final CardPackConfig config;
  final double currentGold;

  /// Callback used to deduct gold in the parent (IdleGameScreen).
  final ValueChanged<double> onSpendGold;

  const RebirthPackTile({
    super.key,
    required this.config,
    required this.currentGold,
    required this.onSpendGold,
  });

  @override
  State<RebirthPackTile> createState() => _RebirthPackTileState();
}

class _RebirthPackTileState extends State<RebirthPackTile> {
  static const int _minLevel = 0;
  static const int _maxLevel = 10;

  int _currentLevel = _minLevel;

  void _previousLevel() {
    setState(() {
      if (_currentLevel > _minLevel) {
        _currentLevel--;
      }
    });
  }

  void _nextLevel() {
    setState(() {
      if (_currentLevel < _maxLevel) {
        _currentLevel++;
      }
    });
  }

  double get _cost {
    // cost = 10^level
    return math.pow(10, _currentLevel).toDouble();
  }

  String get _costText {
    if (_cost >= 1e6) {
      return _cost.toStringAsExponential(2);
    }
    return _cost.toStringAsFixed(0);
  }

  int _expToNextLevel(int level) {
    // Exp to next level: (level + 1)^3
    return math.pow(level + 1, 3).toInt();
  }

  Future<void> _onBuyPressed(BuildContext context) async {
    final canAfford = widget.currentGold >= _cost;
    if (!canAfford) {
      // Should be disabled anyway, but guard just in case.
      return;
    }

    // 1) Get all cards for this pack from the catalog.
    final cards = CardCatalog.instance.getCardsForPack(widget.config.id);
    if (cards.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => const AlertDialog(
          title: Text('No Cards Defined'),
          content: Text('There are no cards defined for this pack yet.'),
        ),
      );
      return;
    }

    // 2) Choose a random card uniformly.
    final rng = math.Random();
    final GameCard chosen = cards[rng.nextInt(cards.length)];

    // 3) Load player collection from SharedPreferences.
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(kPlayerCollectionKey);
    List<OwnedCard> collection = [];
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List<dynamic>;
        collection = decoded
            .map((e) => OwnedCard.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        // If parsing fails, start with empty collection.
        collection = [];
      }
    }

    // Find existing card in collection (if any).
    final index = collection.indexWhere((c) => c.cardId == chosen.id);

    final int expGain = _cost.round();
    int totalExp = expGain;
    int level;
    int startingLevel;
    int startingExp;
    int levelsGained = 0;

    if (index == -1) {
      // New card: start from the card's base level and 0 exp, then add expGain.
      level = chosen.baseLevel;
      startingLevel = level;
      startingExp = 0;
      totalExp = expGain;

      // Apply level-up loop.
      while (true) {
        final needed = _expToNextLevel(level);
        if (totalExp >= needed) {
          totalExp -= needed;
          level += 1;
          levelsGained += 1;
        } else {
          break;
        }
      }

      final owned = OwnedCard(
        cardId: chosen.id,
        level: level,
        experience: totalExp,
      );
      collection.add(owned);
    } else {
      // Existing card: add exp on top of existing.
      final current = collection[index];
      level = current.level;
      startingLevel = current.level;
      startingExp = current.experience;

      totalExp = current.experience + expGain;

      while (true) {
        final needed = _expToNextLevel(level);
        if (totalExp >= needed) {
          totalExp -= needed;
          level += 1;
          levelsGained += 1;
        } else {
          break;
        }
      }

      final updated = current.copyWith(
        level: level,
        experience: totalExp,
      );
      collection[index] = updated;
    }

    // 4) Save updated collection back to SharedPreferences.
    final encoded = jsonEncode(
      collection.map((c) => c.toJson()).toList(),
    );
    await prefs.setString(kPlayerCollectionKey, encoded);

    // 5) Show result popup.
    final int nextLevelExpRequirement = _expToNextLevel(level);
    final buffer = StringBuffer()
      ..writeln('You got ${chosen.name}!')
      ..writeln()
      ..writeln('Current Level: $level');

    if (levelsGained > 0) {
      buffer.writeln('Level up! (+$levelsGained)');
    }

    buffer
      ..writeln(
          'Experience: $totalExp / $nextLevelExpRequirement (toward next level)')
      ..writeln()
      ..writeln('Pack cost added as experience: +$expGain');

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Card Acquired'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Card image (for now, use the pack background as a stand-in).
            SizedBox(
              width: 120,
              height: 180,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/card_background_lux_aurea.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF333333),
                            Color(0xFF777777),
                          ],
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          'Card Image\nMissing',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              buffer.toString(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    // 6) Finally, actually spend the gold via the callback.
    widget.onSpendGold(_cost);
  }

  @override
  Widget build(BuildContext context) {
    final bool canAfford = widget.currentGold >= _cost;

    return Card(
      color: Colors.black.withOpacity(0.6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Pack name
            Text(
              widget.config.name,
              style: const TextStyle(
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
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Arrow + card image
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: _previousLevel,
                  icon: const Icon(Icons.chevron_left),
                  color: Colors.white,
                ),
                const SizedBox(width: 8),

                // Real card image (falls back to placeholder if asset is missing)
                Container(
                  width: 90,
                  height: 140,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.amberAccent.withOpacity(0.8),
                      width: 2,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/card_pack_lux_aurea.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF333333),
                                Color(0xFF777777),
                              ],
                            ),
                          ),
                          child: const Center(
                            child: Text(
                              'Missing\nImage',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _nextLevel,
                  icon: const Icon(Icons.chevron_right),
                  color: Colors.white,
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Level + cost
            Text(
              'Level $_currentLevel',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Cost: $_costText',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.amber,
              ),
            ),

            const SizedBox(height: 12),

            // BUY BUTTON
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: canAfford
                    ? () async {
                  await _onBuyPressed(context);
                }
                    : null,
                child: const Text('Buy Pack'),
              ),
            ),

            const SizedBox(height: 12),

            // Info button
            Align(
              alignment: Alignment.center,
              child: TextButton.icon(
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(widget.config.name),
                      content: Text(
                        'Info about ${widget.config.name} (Level $_currentLevel)\n'
                            'Cost: $_costText gold.\n\n'
                            'Detailed effects will be added later.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.info_outline),
                label: const Text('Info'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
