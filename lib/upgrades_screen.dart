import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'cards/game_card_models.dart';
import 'cards/card_catalog.dart';
import 'cards/game_card_face.dart';
import 'cards/card_effects.dart';
import 'cards/player_collection_repository.dart';
import 'cards/info_dialog.dart';
import 'utilities/display_functions.dart';

/// Upgrades: map<cardId, count> stored as JSON.
/// This matches kCardUpgradeCountsKey in idle_game_screen.dart.
/// NOTE: We store these **per mode** by prefixing with 'antimatter_' when needed.
const String kCardUpgradeCountsKey = 'card_upgrade_counts';

/// Snapshot of which cards (and at what level) are upgradeable this run.
/// This is written at rebirth time and remains fixed until the next rebirth.
/// NOTE: We now treat the snapshot as the frozen set of card IDs,
///       and store it **per mode** using the same prefix convention.
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

  /// Current game mode: 'gold' or 'antimatter'.
  String _gameMode = 'gold';

  /// SharedPreferences key for the active game mode.
  /// Must match the key used in IdleGameScreen.
  static const String _activeGameModeKey = 'active_game_mode';

  /// cardId -> number of upgrades purchased this run (per mode).
  Map<String, int> _upgradeCounts = {};

  /// One entry per upgrade row.
  List<_UpgradeRowData> _rows = [];

  /// Helper to add per-mode prefix to keys:
  ///  - gold: baseKey as-is
  ///  - antimatter: 'antimatter_<baseKey>'
  String _modeKey(String baseKey, String gameMode) {
    if (gameMode == 'antimatter') return 'antimatter_$baseKey';
    return baseKey;
  }

  /// Resolve current game mode from prefs.
  String _resolveCurrentGameMode(SharedPreferences prefs) {
    final storedMode = prefs.getString(_activeGameModeKey);

    if (storedMode == 'mine_gold') return 'gold';
    if (storedMode == 'create_antimatter') return 'antimatter';
    if (storedMode == 'gold' || storedMode == 'antimatter') {
      return storedMode!;
    }
    return 'gold';
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    _prefs ??= await SharedPreferences.getInstance();
    final prefs = _prefs!;

    _gameMode = _resolveCurrentGameMode(prefs);
    String mk(String baseKey) => _modeKey(baseKey, _gameMode);

    // 1) Load upgrade counts (per run, PER MODE).
    final countsJson = prefs.getString(mk(kCardUpgradeCountsKey));
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

    // 2) Try to build rows from the frozen snapshot first (PER MODE).
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

    // 3) If no valid snapshot exists, derive from the current active deck + collection
    //    and create the snapshot now (PER MODE).
    final rowsFromLive =
    await _buildRowsFromCurrentDeckAndCreateSnapshot(counts: counts);

    setState(() {
      _upgradeCounts = counts;
      _rows = rowsFromLive;
      _loading = false;
    });
  }

  /// Load the current player collection from PlayerCollectionRepository.
  Future<Map<String, OwnedCard>> _loadOwnedById() async {
    final repo = PlayerCollectionRepository.instance;
    await repo.init();
    return {for (final oc in repo.allOwnedCards) oc.cardId: oc};
  }

  /// Attempts to build upgrade rows from the frozen snapshot (PER MODE).
  /// Returns null or empty list if snapshot is missing/invalid.
  ///
  /// IMPORTANT: We only use the snapshot to fix the *set of cards*.
  /// The cardLevel is always taken from the current collection (OwnedCard.level),
  /// falling back to the snapshot level or baseLevel if needed.
  Future<List<_UpgradeRowData>?> _buildRowsFromSnapshotIfAvailable({
    required Map<String, int> counts,
  }) async {
    final prefs = _prefs!;
    String mk(String baseKey) => _modeKey(baseKey, _gameMode);

    final snapshotJson = prefs.getString(mk(kUpgradeDeckSnapshotKey));
    if (snapshotJson == null || snapshotJson.isEmpty) return null;

    final ownedById = await _loadOwnedById();

    try {
      final decoded = jsonDecode(snapshotJson);
      if (decoded is! List) return null;

      final List<_UpgradeRowData> rows = [];
      for (final entry in decoded) {
        if (entry is! Map<String, dynamic>) continue;
        final cardId = entry['cardId']?.toString();
        if (cardId == null) continue;

        final card = CardCatalog.getById(cardId);
        if (card == null) continue;

        // Snapshot may contain a 'level' field from older runs; fallback only.
        final snapshotLevelRaw = entry['level'];
        int snapshotLevel = 1;
        if (snapshotLevelRaw is int) {
          snapshotLevel = snapshotLevelRaw;
        } else if (snapshotLevelRaw is num) {
          snapshotLevel = snapshotLevelRaw.toInt();
        }

        final owned = ownedById[cardId];
        final int cardLevel =
            owned?.level ?? snapshotLevel.clamp(1, 9999) ?? card.baseLevel;

        final ownedCount = counts[cardId] ?? 0;

        rows.add(
          _UpgradeRowData(
            card: card,
            ownedCount: ownedCount,
            cardLevel: cardLevel,
            owned: owned,
          ),
        );
      }

      return rows;
    } catch (_) {
      return null;
    }
  }

  /// Reads the *current* active deck & collection, builds rows, and writes snapshot.
  /// This is done PER MODE.
  Future<List<_UpgradeRowData>> _buildRowsFromCurrentDeckAndCreateSnapshot({
    required Map<String, int> counts,
  }) async {
    final prefs = _prefs!;
    final mode = _gameMode;
    String mk(String baseKey) => _modeKey(baseKey, mode);

    // Resolve active deck cards via repository (per-mode deck prefs).
    final activeCards =
    await PlayerCollectionRepository.instance.getCurrentActiveDeckCards(
      prefs: prefs,
      gameMode: mode,
    );

    final ownedById = await _loadOwnedById();

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
          owned: owned,
        ),
      );

      snapshotList.add({
        'cardId': card.id,
        'level': cardLevel, // kept for backward compatibility / debugging
      });
    }

    await prefs.setString(mk(kUpgradeDeckSnapshotKey), jsonEncode(snapshotList));
    return rows;
  }

  Future<void> _saveUpgradeCounts() async {
    _prefs ??= await SharedPreferences.getInstance();
    final prefs = _prefs!;
    String mk(String baseKey) => _modeKey(baseKey, _gameMode);

    final mapToSave = _upgradeCounts.map((k, v) => MapEntry(k, v));
    await prefs.setString(mk(kCardUpgradeCountsKey), jsonEncode(mapToSave));
  }

  /// cost = baseCost(rank, cardLevel) * [costScalingFactor(cardLevel)]^ownedCount
  double _computeNextCost({
    required GameCard card,
    required int cardLevel,
    required int ownedCount,
  }) {
    final double baseCost = CardEffects.baseCost(rank: card.rank, level: cardLevel);
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
          owned: r.owned,
        )
            : r,
      )
          .toList();
    });

    await _saveUpgradeCounts();

    widget.onCardUpgradeEffect(card, cardLevel, newCount);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Upgraded ${card.name} (owned this run: $newCount).'),
      ),
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

    final bool canAfford = widget.currentResource >= cost;
    final costText = displayNumber(cost);

    final effectiveOwned = row.owned ??
        OwnedCard(
          cardId: card.id,
          level: cardLevel,
          experience: 0,
        );

    return Opacity(
      opacity: canAfford ? 1.0 : 0.4,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _handlePurchase(row),
        child: Container(
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.45),
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(
              color: canAfford ? Colors.white24 : Colors.white10,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
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
                      card.shortDescription,
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
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: canAfford ? Colors.amber : Colors.grey,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(
                  Icons.info_outline,
                  color: Colors.white,
                ),
                onPressed: () => showGlobalCardInfoDialog(
                  context: context,
                  card: card,
                  owned: effectiveOwned,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
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

class _UpgradeRowData {
  final GameCard card;
  final int ownedCount;

  /// Player's level for this card (from OwnedCard.level or snapshot).
  final int cardLevel;

  /// The actual OwnedCard from the collection, if present.
  final OwnedCard? owned;

  const _UpgradeRowData({
    required this.card,
    required this.ownedCount,
    required this.cardLevel,
    required this.owned,
  });
}
