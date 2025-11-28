import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'cards/game_card_models.dart';
import 'cards/card_catalog.dart';
import 'cards/game_card_face.dart';
import 'cards/card_effects.dart';

/// Deck persistence keys (same string values as in deck_management_tab.dart).
const String _deckSlotCountKey = 'rebirth_deck_slot_count';
const String _decksDataKey = 'rebirth_decks_data';
const String _activeDeckIndexKey = 'rebirth_active_deck_index';

/// Upgrades: map<cardId, count> stored as JSON.
/// This matches kCardUpgradeCountsKey in idle_game_screen.dart.
const String kCardUpgradeCountsKey = 'card_upgrade_counts';

/// Shared key for player collection in SharedPreferences
/// (same as in DeckManagementTab).
const String kPlayerCollectionKey = 'player_collection';

/// Snapshot of which cards (and at what level) are upgradeable this run.
/// This is written at rebirth time and remains fixed until the next rebirth.
const String kUpgradeDeckSnapshotKey = 'rebirth_upgrade_deck_snapshot';

class UpgradesScreen extends StatefulWidget {
  final double currentResource;
  final String resourceLabel;
  final ValueChanged<double> onSpendResource;

  /// Callback into IdleGameScreen so it can apply per-card effects
  /// (e.g., modify orePerSecond).
  final void Function(GameCard card, int cardLevel, int upgradesThisRun)
  onCardUpgradeEffect;

  const UpgradesScreen({
    super.key,
    required this.currentResource,
    required this.resourceLabel,
    required this.onSpendResource,
    required this.onCardUpgradeEffect,
  });

  @override
  State<UpgradesScreen> createState() => _UpgradesScreenState();
}

class _UpgradesScreenState extends State<UpgradesScreen> {
  SharedPreferences? _prefs;

  bool _loading = true;

  /// cardId -> number of upgrades purchased this run.
  Map<String, int> _upgradeCounts = {};

  /// One entry per upgrade row.
  List<_UpgradeRowData> _rows = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    _prefs ??= await SharedPreferences.getInstance();

    // 1) Load upgrade counts.
    final countsJson = _prefs!.getString(kCardUpgradeCountsKey);
    Map<String, int> counts = {};
    if (countsJson != null && countsJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(countsJson);
        if (decoded is Map<String, dynamic>) {
          decoded.forEach((key, value) {
            if (value is int) {
              counts[key] = value;
            } else if (value is num) {
              counts[key] = value.toInt();
            }
          });
        }
      } catch (_) {
        counts = {};
      }
    }

    // 2) Try to build rows from the frozen snapshot first.
    final rowsFromSnapshot =
    await _buildRowsFromSnapshotIfAvailable(counts: counts);

    if (rowsFromSnapshot != null && rowsFromSnapshot.isNotEmpty) {
      setState(() {
        _upgradeCounts = counts;
        _rows = rowsFromSnapshot;
        _loading = false;
      });
      return;
    }

    // 3) If no valid snapshot exists (e.g. first run),
    //    derive from the current active deck + collection
    //    and create the snapshot now.
    final rowsFromLive =
    await _buildRowsFromCurrentDeckAndCreateSnapshot(counts: counts);

    setState(() {
      _upgradeCounts = counts;
      _rows = rowsFromLive;
      _loading = false;
    });
  }

  /// Attempts to build upgrade rows from the frozen snapshot.
  /// Returns null or empty list if snapshot is missing/invalid.
  Future<List<_UpgradeRowData>?> _buildRowsFromSnapshotIfAvailable({
    required Map<String, int> counts,
  }) async {
    final snapshotJson = _prefs!.getString(kUpgradeDeckSnapshotKey);
    if (snapshotJson == null || snapshotJson.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(snapshotJson) as List<dynamic>;
      final List<_UpgradeRowData> rows = [];

      for (final entry in decoded) {
        if (entry is! Map<String, dynamic>) continue;
        final cardId = entry['cardId']?.toString();
        if (cardId == null) continue;
        final levelRaw = entry['level'];
        final int cardLevel;
        if (levelRaw is int) {
          cardLevel = levelRaw;
        } else if (levelRaw is num) {
          cardLevel = levelRaw.toInt();
        } else {
          cardLevel = 1;
        }

        final card = CardCatalog.getById(cardId);
        if (card == null) continue;

        final ownedCount = counts[cardId] ?? 0;
        rows.add(
          _UpgradeRowData(
            card: card,
            ownedCount: ownedCount,
            cardLevel: cardLevel,
          ),
        );
      }

      return rows;
    } catch (_) {
      return null;
    }
  }

  /// Reads the *current* active deck & collection (like DeckManagementTab),
  /// builds the upgrade rows, and writes a frozen snapshot for future runs.
  Future<List<_UpgradeRowData>> _buildRowsFromCurrentDeckAndCreateSnapshot({
    required Map<String, int> counts,
  }) async {
    // --- Active deck from deck prefs ---
    final deckSlotCount = _prefs!.getInt(_deckSlotCountKey) ?? 1;
    final activeDeckIndexZero = _prefs!.getInt(_activeDeckIndexKey) ?? 0;
    final decksJson = _prefs!.getString(_decksDataKey);

    List<_DeckData> decks = [];

    if (decksJson != null && decksJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(decksJson);
        if (decoded is List) {
          decks = decoded
              .whereType<Map<String, dynamic>>()
              .map((m) => _DeckData.fromJson(m))
              .toList();
        }
      } catch (_) {
        decks = [];
      }
    }

    // Ensure list has at least deckSlotCount entries so we always have a deck_N.
    while (decks.length < deckSlotCount) {
      final index = decks.length;
      decks.add(
        _DeckData(
          id: 'deck_${index + 1}',
          name: 'Deck ${index + 1}',
          cardIds: const [],
        ),
      );
    }

    int idx = activeDeckIndexZero;
    if (idx < 0 || idx >= decks.length) {
      idx = 0;
    }
    final activeDeck = decks[idx];

    // --- Resolve cards in the active deck ---
    final List<GameCard> activeCards = [];
    for (final cardId in activeDeck.cardIds) {
      final card = CardCatalog.getById(cardId);
      if (card != null) {
        activeCards.add(card);
      }
    }

    // --- Load player collection like DeckManagementTab ---
    final rawCollection = _prefs!.getString(kPlayerCollectionKey);
    List<OwnedCard> collection = [];
    if (rawCollection != null && rawCollection.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawCollection) as List<dynamic>;
        collection = decoded
            .map((e) => OwnedCard.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        collection = [];
      }
    }
    final Map<String, OwnedCard> ownedById = {
      for (final oc in collection) oc.cardId: oc,
    };

    // --- Build rows + snapshot list ---
    final rows = <_UpgradeRowData>[];
    final snapshotList = <Map<String, dynamic>>[];

    for (final card in activeCards) {
      final owned = ownedById[card.id];
      final cardLevel = owned?.level ?? card.baseLevel;
      final ownedCount = counts[card.id] ?? 0;

      rows.add(
        _UpgradeRowData(
          card: card,
          ownedCount: ownedCount,
          cardLevel: cardLevel,
        ),
      );

      snapshotList.add({
        'cardId': card.id,
        'level': cardLevel,
      });
    }

    // Persist snapshot so future loads use this frozen list.
    await _prefs!.setString(kUpgradeDeckSnapshotKey, jsonEncode(snapshotList));

    return rows;
  }

  Future<void> _saveUpgradeCounts() async {
    _prefs ??= await SharedPreferences.getInstance();
    final mapToSave = _upgradeCounts.map((key, value) => MapEntry(key, value));
    await _prefs!.setString(kCardUpgradeCountsKey, jsonEncode(mapToSave));
  }

  /// Computes the next upgrade cost for a given card, using the
  /// *player's* card level (not the catalog baseLevel).
  ///
  /// cost = baseCost(rank, cardLevel) * [costScalingFactor(cardLevel)]^ownedCount
  double _computeNextCost({
    required GameCard card,
    required int cardLevel,
    required int ownedCount,
  }) {
    final double baseCost =
    CardEffects.baseCost(rank: card.rank, level: cardLevel);
    final double scaling = CardEffects.costScalingFactor(level: cardLevel);
    return baseCost * math.pow(scaling, ownedCount);
  }

  Future<void> _handlePurchase(_UpgradeRowData row) async {
    final card = row.card;
    final cardLevel = row.cardLevel;
    final currentCount = _upgradeCounts[card.id] ?? row.ownedCount;
    final cost = _computeNextCost(
      card: card,
      cardLevel: cardLevel,
      ownedCount: currentCount,
    );

    if (widget.currentResource < cost) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Not enough ${widget.resourceLabel.toLowerCase()} '
                'to upgrade ${card.name}.',
          ),
        ),
      );
      return;
    }

    // Spend the resource in the parent (IdleGameScreen).
    widget.onSpendResource(cost);

    final newCount = currentCount + 1;

    setState(() {
      _upgradeCounts[card.id] = newCount;
      _rows = _rows
          .map(
            (r) => r.card.id == card.id
            ? _UpgradeRowData(
          card: r.card,
          ownedCount: newCount,
          cardLevel: r.cardLevel,
        )
            : r,
      )
          .toList();
    });

    await _saveUpgradeCounts();

    // Notify IdleGameScreen so it can apply the actual effect.
    widget.onCardUpgradeEffect(card, cardLevel, newCount);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Upgraded ${card.name} (owned this run: $newCount).'),
      ),
    );
  }

  void _showInfoDialog(_UpgradeRowData row) {
    final card = row.card;
    final ownedCount = row.ownedCount;
    final cardLevel = row.cardLevel;
    final nextCost = _computeNextCost(
      card: card,
      cardLevel: cardLevel,
      ownedCount: ownedCount,
    );

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(card.name),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card.longDescription,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 12),
                Text('Upgrades owned this run: $ownedCount'),
                const SizedBox(height: 4),
                Text(
                  'Next upgrade cost: '
                      '${nextCost.toStringAsFixed(0)} ${widget.resourceLabel}',
                ),
                const SizedBox(height: 4),
                Text('Card level: $cardLevel'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildUpgradeRow(_UpgradeRowData row) {
    final card = row.card;
    final ownedCount = row.ownedCount;
    final cardLevel = row.cardLevel;
    final cost = _computeNextCost(
      card: card,
      cardLevel: cardLevel,
      ownedCount: ownedCount,
    );
    final costText = cost.toStringAsFixed(0);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _handlePurchase(row),
      child: Container(
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.45),
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Card image (match Rebirth Store / deck usage).
            SizedBox(
              width: 70,
              height: 100,
              child: FittedBox(
                fit: BoxFit.contain,
                child: GameCardFace(
                  card: card,
                  width: 90,
                  height: 140,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Name + long description + level
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.name,
                    style: const TextStyle(
                      fontSize: 16,
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
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    card.longDescription,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Level: $cardLevel',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white60,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Owned + Cost
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'Owned',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
                Text(
                  ownedCount.toString(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Cost',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
                Text(
                  '$costText ${widget.resourceLabel}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),

            // Info button
            IconButton(
              icon: const Icon(
                Icons.info_outline,
                color: Colors.white,
              ),
              onPressed: () => _showInfoDialog(row),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_rows.isEmpty) {
      return const Center(
        child: Text(
          'Your upgrade pool is empty.\n'
              'Open the Rebirth → Deck tab and rebirth to set a new upgrade deck.',
          textAlign: TextAlign.center,
          style: TextStyle(
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
        ),
      );
    }

    return ListView.separated(
      itemCount: _rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _buildUpgradeRow(_rows[index]),
    );
  }
}

/// Minimal deck data model to read deck JSON from SharedPreferences.
/// This matches the structure written by DeckManagementTab.
class _DeckData {
  final String id;
  String name;
  final List<String> cardIds;

  _DeckData({
    required this.id,
    required this.name,
    required this.cardIds,
  });

  factory _DeckData.fromJson(Map<String, dynamic> json) {
    final cardsRaw = json['cards'];
    final List<String> ids;
    if (cardsRaw is List) {
      ids = cardsRaw.map((e) => e.toString()).toList();
    } else {
      ids = const [];
    }

    return _DeckData(
      id: json['id']?.toString() ?? 'deck_1',
      name: json['name']?.toString() ?? 'Deck 1',
      cardIds: ids,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'cards': cardIds,
    };
  }
}

/// Simple holder for row data.
class _UpgradeRowData {
  final GameCard card;
  final int ownedCount;

  /// Player's level for this card (from OwnedCard.level or snapshot).
  final int cardLevel;

  const _UpgradeRowData({
    required this.card,
    required this.ownedCount,
    required this.cardLevel,
  });
}
