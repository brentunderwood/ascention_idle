// lib/main/tabs/cards/buy_packs_tab.dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'card_catalog.dart';
import 'game_card_face.dart';
import '../global_data/global_variables.dart';

/// Model for a card pack configuration.
class CardPackConfig {
  final String id;
  final String name;
  final String packImageAsset;

  const CardPackConfig({
    required this.id,
    required this.name,
    required this.packImageAsset,
  });
}

/// Result of drawing a card from a pack, including any experience multiplier.
class CardDrawResult {
  final GameCard card;
  final int expMultiplier;

  const CardDrawResult({
    required this.card,
    required this.expMultiplier,
  });
}

/// Shared probability distribution for packs.
///
/// Adapted to your CURRENT card model:
/// - Uses GameCard.rarity as the "rank"/rarity bucket (1..10).
CardDrawResult _drawCardForPack({
  required List<GameCard> cardsInPack,
  required int packLevel,
  required math.Random rng,
}) {
  if (cardsInPack.isEmpty) {
    throw StateError('Cannot draw from empty pack.');
  }

  // Ensure packLevel is at least 0 to avoid degenerate behavior.
  final double level = packLevel < 0 ? 0 : packLevel / 4;

  // --- Step 1: Sample a raw "cardRank" with geometric-like distribution -----
  double r = rng.nextDouble() * (level + 1);
  int cardRank = 0;

  while (true) {
    final double probMass = math.pow(level / (level + 1), cardRank).toDouble();

    if (r <= probMass) {
      cardRank++;
      break;
    }

    r -= probMass;
    cardRank++;
  }

  // --- Step 2: Map to final rarity in [1..10] -------------------------------
  final int finalRarity = ((cardRank - 1) % 10) + 1;

  // --- Step 3: Experience multiplier ----------------------------------------
  final int expMultiplier = math.pow(10, (cardRank - 1) ~/ 10).toInt();

  // --- Step 4: Find a card with that rarity, with "step-down" fallback ------
  List<GameCard> matches =
  cardsInPack.where((c) => c.rarity == finalRarity).toList(growable: false);

  if (matches.isEmpty) {
    int search = finalRarity - 1;
    while (search >= 1 && matches.isEmpty) {
      final candidates =
      cardsInPack.where((c) => c.rarity == search).toList(growable: false);
      if (candidates.isNotEmpty) {
        matches = candidates;
        break;
      }
      search--;
    }
  }

  final GameCard chosen = matches.isNotEmpty
      ? matches[rng.nextInt(matches.length)]
      : cardsInPack[rng.nextInt(cardsInPack.length)];

  return CardDrawResult(card: chosen, expMultiplier: expMultiplier);
}

class BuyPacksTab extends StatefulWidget {
  const BuyPacksTab({super.key});

  @override
  State<BuyPacksTab> createState() => _BuyPacksTabState();
}

class _BuyPacksTabState extends State<BuyPacksTab> {
  /// ✅ Only these two packs exist.
  static const List<CardPackConfig> _allPacks = [
    CardPackConfig(
      id: 'lux_aurea',
      name: 'Lux Aurea',
      packImageAsset: 'assets/lux_aurea/card_pack_lux_aurea.png',
    ),
    CardPackConfig(
      id: 'stygian_void',
      name: 'Stygian Void',
      packImageAsset: 'assets/stygian_void/card_pack_stygian_void.png',
    ),
  ];

  bool _loading = true;
  double _currentGold = 0;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    await PlayerDataRepository.instance.init();
    if (!mounted) return;
    setState(() {
      _currentGold = PlayerDataRepository.instance.currentGold;
      _loading = false;
    });
  }

  void _refreshGold() {
    setState(() {
      _currentGold = PlayerDataRepository.instance.currentGold;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Buy Card Packs',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Gold: ${_currentGold.toStringAsFixed(0)}',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          ..._allPacks.map(
                (pack) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: PackTile(
                config: pack,
                currentGold: _currentGold,
                onAfterPurchase: _refreshGold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single card-pack widget with:
/// - Name above
/// - Pack image
/// - Left/right arrows to change level (0..highestPurchased+1)
/// - Cost (10^level)
/// - Buy button (spends gold + draws a card + updates card XP/level)
/// - Info button (includes rarity chances for ranks 1..10)
class PackTile extends StatefulWidget {
  final CardPackConfig config;
  final double currentGold;

  /// Called after purchases so parent can refresh display.
  final VoidCallback onAfterPurchase;

  const PackTile({
    super.key,
    required this.config,
    required this.currentGold,
    required this.onAfterPurchase,
  });

  @override
  State<PackTile> createState() => _PackTileState();
}

class _PackTileState extends State<PackTile> {
  static const int _minLevel = 0;

  // Monte Carlo samples for the rarity % shown in the Info dialog.
  static const int _rarityChanceSamples = 20000;

  int _currentLevel = 0;

  // ✅ Persisted: highest level ever purchased for this specific pack.
  int _highestPurchasedLevel = 0;
  bool _loaded = false;

  String get _prefsKey => 'pack_highest_purchased_level_${widget.config.id}';

  @override
  void initState() {
    super.initState();
    _loadHighestPurchased();
  }

  Future<void> _loadHighestPurchased() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getInt(_prefsKey) ?? 0;

    if (!mounted) return;
    setState(() {
      _highestPurchasedLevel = v < 0 ? 0 : v;
      _currentLevel = math.min(_highestAffordable(widget.currentGold), _maxSelectableLevel());
      _loaded = true;
    });
  }

  Future<void> _recordPurchaseAtLevel(int level) async {
    if (level <= _highestPurchasedLevel) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefsKey, level);

    if (!mounted) return;
    setState(() => _highestPurchasedLevel = level);
  }

  int _highestAffordable(double gold) {
    if (gold < 1) return 0;
    final lvl = (math.log(gold) / math.log(10)).floor();
    return lvl < 0 ? 0 : lvl;
  }

  /// ✅ Maximum selectable = highest purchased + 1 (persisted).
  int _maxSelectableLevel() => _highestPurchasedLevel + 1;

  void _previousLevel() {
    setState(() {
      if (_currentLevel > _minLevel) _currentLevel--;
    });
  }

  void _nextLevel() {
    final maxLevel = _maxSelectableLevel();
    setState(() {
      if (_currentLevel < maxLevel) _currentLevel++;
    });
  }

  double get _cost => math.pow(10, _currentLevel).toDouble();

  String get _costText {
    if (_cost >= 1e6) return _cost.toStringAsExponential(2);
    return _cost.toStringAsFixed(0);
  }

  String get _infoDescription {
    switch (widget.config.id) {
      case 'lux_aurea':
        return 'A pack containing cards that generate resources every second.';
      case 'stygian_void':
        return 'A pack containing cards that tap into antimatter and the dark abyss.';
      default:
        return 'A mysterious pack containing unknown cards.';
    }
  }

  String _formatPct(double? v) => v == null ? '—' : '${v.toStringAsFixed(1)}%';

  List<GameCard> _cardsForThisPack() {
    return CardCatalog.cards
        .where((c) => c.cardPack == widget.config.id)
        .toList(growable: false);
  }

  /// Estimates the chance (%) of drawing each rarity (1..10) at the current level,
  /// using the same draw selection logic.
  Future<Map<int, double>> _estimateRarityChances() async {
    final cards = _cardsForThisPack();
    if (cards.isEmpty) return <int, double>{};

    // Fixed seed so results are stable between opens.
    final rng = math.Random(1337);

    final Map<int, int> counts = <int, int>{};
    int n = 0;

    for (int i = 0; i < _rarityChanceSamples; i++) {
      final res = _drawCardForPack(
        cardsInPack: cards,
        packLevel: _currentLevel,
        rng: rng,
      );
      final int r = res.card.rarity;
      if (r >= 1 && r <= 10) {
        counts[r] = (counts[r] ?? 0) + 1;
      }
      n++;
    }

    final Map<int, double> pct = <int, double>{};
    if (n <= 0) return pct;

    for (int r = 1; r <= 10; r++) {
      final c = counts[r] ?? 0;
      pct[r] = (c / n) * 100.0;
    }
    return pct;
  }

  Future<void> _onBuyPressed(BuildContext context) async {
    final repo = PlayerDataRepository.instance;

    // Always re-check affordability using persisted gold (source of truth).
    final double goldNow = repo.currentGold;
    final bool canAfford = goldNow >= _cost;
    if (!canAfford) return;

    final cards = _cardsForThisPack();
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

    // Spend first (so we don't grant a card if spending fails).
    final spent = await repo.spendGold(_cost);
    if (!spent) {
      // Race-condition safety.
      if (!mounted) return;
      widget.onAfterPurchase();
      return;
    }

    // Draw a card.
    final rng = math.Random();
    final draw = _drawCardForPack(
      cardsInPack: cards,
      packLevel: _currentLevel,
      rng: rng,
    );

    // XP gain mirrors your old logic:
    // baseExp = gold spent (rounded)
    // if new card: +baseExp
    // if already owned: +baseExp * expMultiplier
    final int baseExp = _cost.round();
    final alreadyOwned = repo.ownsCard(draw.card.cardId);
    final int xpGain = alreadyOwned ? baseExp * draw.expMultiplier : baseExp;

    final updatedOwned = await repo.addOrUpdateCard(
      cardId: draw.card.cardId,
      xpGain: xpGain,
      // uses repo's default exp curve for now
    );

    // Persist highest purchased pack level.
    await _recordPurchaseAtLevel(_currentLevel);

    // Refresh parent gold display.
    widget.onAfterPurchase();

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Card Acquired'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GameCardFace(
              card: draw.card,
              width: 120,
              height: 180,
            ),
            const SizedBox(height: 12),
            Text(
              'You got ${draw.card.cardName}!\n\n'
                  'Pack: ${widget.config.name}\n'
                  'Pack Level: $_currentLevel\n'
                  'Cost Paid: $_costText\n\n'
                  'XP Gained: +$xpGain\n'
                  'Owned Level: ${updatedOwned.level}\n'
                  'Owned XP: ${updatedOwned.experience}',
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
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final int maxSelectable = _maxSelectableLevel();
    final bool canAffordUi = widget.currentGold >= _cost;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              widget.config.name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: _currentLevel > _minLevel ? _previousLevel : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Image.asset(
                  widget.config.packImageAsset,
                  width: 90,
                  height: 140,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 90,
                    height: 140,
                    color: Colors.black12,
                    alignment: Alignment.center,
                    child: const Text('Missing\nImage', textAlign: TextAlign.center),
                  ),
                ),
                IconButton(
                  onPressed: _currentLevel < maxSelectable ? _nextLevel : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Level $_currentLevel (max selectable: $maxSelectable)'),
            Text('Cost: $_costText'),
            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: canAffordUi ? () => _onBuyPressed(context) : null,
                child: const Text('Buy Pack'),
              ),
            ),

            const SizedBox(height: 12),

            Align(
              alignment: Alignment.center,
              child: TextButton.icon(
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    builder: (ctx) {
                      return FutureBuilder<Map<int, double>>(
                        future: _estimateRarityChances(),
                        builder: (context, snap) {
                          Widget content;

                          if (snap.connectionState != ConnectionState.done) {
                            content = Column(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                SizedBox(height: 8),
                                CircularProgressIndicator(),
                                SizedBox(height: 12),
                                Text('Calculating rarity chances...'),
                              ],
                            );
                          } else {
                            final pct = snap.data ?? <int, double>{};

                            final List<Widget> lines = [
                              Text(_infoDescription),
                              const SizedBox(height: 12),
                              Text(
                                'Estimated draw chances (Level $_currentLevel):',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                            ];

                            for (int r = 1; r <= 10; r++) {
                              lines.add(Text('Rarity $r: ${_formatPct(pct[r])}'));
                            }

                            lines.add(const SizedBox(height: 8));
                            lines.add(
                              Text(
                                '(Based on $_rarityChanceSamples simulated draws)',
                                style: const TextStyle(fontSize: 12, color: Colors.black54),
                              ),
                            );

                            content = Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: lines,
                            );
                          }

                          return AlertDialog(
                            title: Text(widget.config.name),
                            content: content,
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(),
                                child: const Text('OK'),
                              ),
                            ],
                          );
                        },
                      );
                    },
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
