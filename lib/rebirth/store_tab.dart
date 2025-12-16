import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../cards/game_card_models.dart';
import '../cards/card_catalog.dart';
import '../cards/game_card_face.dart';
import '../cards/player_collection_repository.dart';
import '../tutorial_manager.dart';

/// Model for a card pack configuration.
class CardPackConfig {
  final String id;
  final String name;

  /// Image asset for the pack art shown in the store.
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

/// Shared probability distribution for *all* packs.
///
/// The flow:
/// 1. Sample a raw "cardRank" using a geometric-like distribution based on
///    the pack level.
/// 2. Map that to a "finalRank" in [1..10].
/// 3. Compute an exp multiplier: 10^(floor((cardRank - 1) / 10)).
/// 4. Attempt to pick a card of that rank from the pack.
///    - If none exists, walk DOWN in rank (finalRank-1, finalRank-2, ...)
///      and pick from the highest lower rank that exists.
///    - If still none exist, fall back to uniform random from the pack.
///
/// NOTE: Cards with negative rank (unique cards) are *excluded* from this
/// distribution and are handled via a separate mechanic.
CardDrawResult _drawCardForPack({
  required List<GameCard> cards,
  required String packId, // kept for future per-pack tweaks if needed
  required int packLevel,
  required math.Random rng,
}) {
  if (cards.isEmpty) {
    throw StateError('Cannot draw from empty card list.');
  }

  // Filter out unique cards (rank < 0) so they are not drawn by
  // the standard distribution.
  final List<GameCard> nonUniqueCards =
  cards.where((c) => c.rank >= 0).toList(growable: false);

  if (nonUniqueCards.isEmpty) {
    throw StateError(
      'Cannot draw from card list that only contains unique (negative rank) cards.',
    );
  }

  // Ensure packLevel is at least 0 to avoid degenerate behavior.
  final double level = packLevel < 0 ? 0 : packLevel / 4;

  // --- Step 1: Sample a raw "cardRank" with geometric-like distribution -----
  double r = rng.nextDouble() * (level + 1);
  int cardRank = 0;

  while (true) {
    final double probMass =
    math.pow(level / (level + 1), cardRank).toDouble();

    if (r <= probMass) {
      cardRank++;
      break;
    }

    r -= probMass;
    cardRank++;
  }

  // --- Step 2: Map to final rank in [1..10] ---------------------------------
  // final_rank = ((card_rank - 1) % 10) + 1
  final int finalRank = ((cardRank - 1) % 10) + 1;

  // --- Step 3: Experience multiplier ----------------------------------------
  // exp_multiplier = 10 ^ floor((card_rank - 1) / 10)
  final int expMultiplier =
  math.pow(10, (cardRank - 1) ~/ 10).toInt();

  // --- Step 4: Find a card with that rank, with "step-down" fallback --------
  List<GameCard> rankMatches = nonUniqueCards
      .where((c) => c.rank == finalRank)
      .toList(growable: false);

  // If no card exists at that rank, walk DOWN in rank until we find cards.
  if (rankMatches.isEmpty) {
    int searchRank = finalRank - 1;
    while (searchRank >= 1 && rankMatches.isEmpty) {
      final candidates = nonUniqueCards
          .where((c) => c.rank == searchRank)
          .toList(growable: false);
      if (candidates.isNotEmpty) {
        rankMatches = candidates;
        break;
      }
      searchRank--;
    }
  }

  GameCard chosen;
  if (rankMatches.isNotEmpty) {
    chosen = rankMatches[rng.nextInt(rankMatches.length)];
  } else {
    // As an absolute fallback (e.g., if all ranks are weird), pick uniformly.
    chosen = nonUniqueCards[rng.nextInt(nonUniqueCards.length)];
  }

  return CardDrawResult(
    card: chosen,
    expMultiplier: expMultiplier,
  );
}

class RebirthStoreTab extends StatefulWidget {
  final double currentGold;

  /// Callback to actually spend refined gold in the parent.
  final ValueChanged<double> onSpendGold;

  const RebirthStoreTab({
    super.key,
    required this.currentGold,
    required this.onSpendGold,
  });

  @override
  State<RebirthStoreTab> createState() => _RebirthStoreTabState();
}

class _RebirthStoreTabState extends State<RebirthStoreTab> {
  /// All possible packs. Visibility is controlled via unlock rules.
  static const List<CardPackConfig> _allPacks = [
    CardPackConfig(
      id: 'lux_aurea',
      name: 'Lux Aurea',
      packImageAsset: 'assets/lux_aurea/card_pack_lux_aurea.png',
    ),
    CardPackConfig(
      id: 'vita_orum',
      name: 'Vita Orum',
      packImageAsset: 'assets/vita_orum/card_pack_vita_orum.png',
    ),
    CardPackConfig(
      id: 'chrono_epoch',
      name: 'Chrono Epoch',
      packImageAsset: 'assets/chrono_epoch/card_pack_chrono_epoch.png',
    ),
    CardPackConfig(
      id: 'stygian_void',
      name: 'Stygian Void',
      packImageAsset:
      'assets/stygian_void/card_pack_stygian_void.png',
    ),
  ];

  /// Which pack IDs are currently visible, based on unlock state.
  Set<String> _visiblePackIds = <String>{};
  bool _loadedVisibility = false;

  @override
  void initState() {
    super.initState();
    _loadPackVisibility();
  }

  /// Central place to define "unlock requirements" per pack.
  ///
  /// When you add new packs later, add a case here for their unlock rule.
  Future<void> _loadPackVisibility() async {
    final prefs = await SharedPreferences.getInstance();
    final Set<String> visible = <String>{};

    for (final pack in _allPacks) {
      bool isVisible;

      switch (pack.id) {
        case 'stygian_void':
        // Visible only if "Create antimatter" has been unlocked on ActivityTab.
        //
        // ActivityTab uses the key 'next_run_antimatter_unlocked'.
        // We also accept the old 'next_run_create_antimatter_unlocked'
        // for backwards compatibility.
          final antimatterUnlocked =
              prefs.getBool('next_run_antimatter_unlocked') ??
                  prefs.getBool('next_run_create_antimatter_unlocked') ??
                  false;
          isVisible = antimatterUnlocked;
          break;

      // Default: always visible (no unlock requirement).
        default:
          isVisible = true;
      }

      if (isVisible) {
        visible.add(pack.id);
      }
    }

    if (!mounted) return;
    setState(() {
      _visiblePackIds = visible;
      _loadedVisibility = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_loadedVisibility) {
      return Container(
        color: Colors.black.withOpacity(0.3),
        width: double.infinity,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final visiblePacks = _allPacks
        .where((p) => _visiblePackIds.contains(p.id))
        .toList(growable: false);

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
            ...visiblePacks.map(
                  (pack) => Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: RebirthPackTile(
                  config: pack,
                  currentGold: widget.currentGold,
                  onSpendGold: widget.onSpendGold,
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
/// - Pack image
/// - Left/right arrows to change level (0–X+1)
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

  int _currentLevel = _minLevel;

  /// Highest level L such that 10^L <= gold.
  /// If gold < 1, we treat highest affordable as 0 so default is level 0.
  int _highestAffordableLevel(double gold) {
    if (gold < 1) {
      return 0;
    }
    final double log10 = math.log(gold) / math.log(10);
    final int level = log10.floor();
    return level < 0 ? 0 : level;
  }

  /// Maximum selectable level is X+1, where X is highest affordable level.
  int _maxSelectableLevel() {
    final int highest = _highestAffordableLevel(widget.currentGold);
    return highest + 1;
  }

  @override
  void initState() {
    super.initState();
    // Default selection should be X (highest affordable).
    _currentLevel = _highestAffordableLevel(widget.currentGold);
  }

  @override
  void didUpdateWidget(covariant RebirthPackTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentGold != oldWidget.currentGold) {
      // Whenever gold changes, snap to the new highest affordable level X.
      _currentLevel = _highestAffordableLevel(widget.currentGold);
    }
  }

  void _previousLevel() {
    setState(() {
      if (_currentLevel > _minLevel) {
        _currentLevel--;
      }
    });
  }

  void _nextLevel() {
    final int maxLevel = _maxSelectableLevel();
    setState(() {
      if (_currentLevel < maxLevel) {
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

  /// Per-pack info description text.
  String get _infoDescription {
    switch (widget.config.id) {
      case 'lux_aurea':
        return 'A pack containing cards that generate resources every second';
      case 'vita_orum':
        return 'A pack containing cards that generate resources when you click';
      case 'chrono_epoch':
        return 'A pack containing cards that manipulate time';
      case 'stygian_void':
        return 'A pack containing cards that tap into antimatter and the dark abyss.';
      default:
        return 'A mysterious pack containing unknown cards.';
    }
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

    // 2) Use the shared PlayerCollectionRepository for collection management.
    final repo = PlayerCollectionRepository.instance;
    await repo.init();

    // Build a quick lookup map: cardId -> OwnedCard.
    final Map<String, OwnedCard> ownedById = {
      for (final oc in repo.allOwnedCards) oc.cardId: oc,
    };

    final rng = math.Random();

    // 3) Identify the unique card for this pack (rank < 0).
    final List<GameCard> uniqueCandidates =
    cards.where((c) => c.rank < 0).toList(growable: false);
    GameCard? uniqueCard =
    uniqueCandidates.isNotEmpty ? uniqueCandidates.first : null;

    // Check if the player already owns the unique card.
    final OwnedCard? uniqueOwned =
    (uniqueCard != null) ? ownedById[uniqueCard.id] : null;
    final bool hasUnique = uniqueOwned != null;

    // 4) Choose a card using the shared pack distribution, with unique logic.
    final int baseExp = _cost.round(); // also "gold spent" this purchase
    final bool canRollForUnique = uniqueCard != null && !hasUnique;

    GameCard chosen;
    int expMultiplierIfOwned;

    if (canRollForUnique) {
      // Chance = (gold spent on pack) / 1,000,000, clamped to [0, 1].
      double uniqueChance = _cost / 1000000.0;
      if (uniqueChance > 1.0) {
        uniqueChance = 1.0;
      }

      if (rng.nextDouble() < uniqueChance) {
        // Hit the unique card instead of the "normal" draw.
        chosen = uniqueCard!;
        // For a brand-new unique, treat multiplier as 1 (normal behavior if new).
        expMultiplierIfOwned = 1;
      } else {
        final drawResult = _drawCardForPack(
          cards: cards,
          packId: widget.config.id,
          packLevel: _currentLevel,
          rng: rng,
        );
        chosen = drawResult.card;
        expMultiplierIfOwned = drawResult.expMultiplier;
      }
    } else {
      // Either no unique card exists, or they already own it:
      // use the normal distribution for the drawn card.
      final drawResult = _drawCardForPack(
        cards: cards,
        packId: widget.config.id,
        packLevel: _currentLevel,
        rng: rng,
      );
      chosen = drawResult.card;
      expMultiplierIfOwned = drawResult.expMultiplier;
    }

    // 5) Apply experience to the chosen card (normal behavior).
    final OwnedCard? existingChosen = ownedById[chosen.id];
    final int expGain =
    existingChosen == null ? baseExp : baseExp * expMultiplierIfOwned;

    int totalExp;
    int level;
    int startingLevel;
    int startingExp;
    int levelsGained = 0;

    if (existingChosen == null) {
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
      ownedById[owned.cardId] = owned;
      await repo.upsertOwnedCard(owned);
    } else {
      // Existing card: add exp on top of existing.
      level = existingChosen.level;
      startingLevel = existingChosen.level;
      startingExp = existingChosen.experience;

      totalExp = existingChosen.experience + expGain;

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

      final updated = existingChosen.copyWith(
        level: level,
        experience: totalExp,
      );
      ownedById[updated.cardId] = updated;
      await repo.upsertOwnedCard(updated);
    }

    // 6) If the unique card is already owned, it gains 1 XP per gold spent
    //    on this pack (baseExp) *in addition* to the normal card's XP.
    if (uniqueCard != null && hasUnique && uniqueOwned != null) {
      int uniqueLevel = uniqueOwned.level;
      int uniqueExp = uniqueOwned.experience + baseExp;
      int uniqueLevelsGained = 0;

      while (true) {
        final needed = _expToNextLevel(uniqueLevel);
        if (uniqueExp >= needed) {
          uniqueExp -= needed;
          uniqueLevel += 1;
          uniqueLevelsGained += 1;
        } else {
          break;
        }
      }

      final updatedUnique = uniqueOwned.copyWith(
        level: uniqueLevel,
        experience: uniqueExp,
      );
      ownedById[updatedUnique.cardId] = updatedUnique;
      await repo.upsertOwnedCard(updatedUnique);
      // (You can optionally include uniqueLevelsGained in the popup text later.)
    }

    // 7) Show result popup for the drawn card.
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
      ..writeln('Pack experience gained: +$expGain');

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Card Acquired'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Use the shared widget that layers background + art
            GameCardFace(
              card: chosen,
              width: 120,
              height: 180,
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

    // 8) Finally, actually spend the gold via the callback.
    widget.onSpendGold(_cost);
    TutorialManager.instance.onRebirthStoreShown(context);
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

            // Arrow + pack image
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: _previousLevel,
                  icon: const Icon(Icons.chevron_left),
                  color: Colors.white,
                ),
                const SizedBox(width: 8),

                // Pack image
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
                      widget.config.packImageAsset,
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
                        _infoDescription,
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
