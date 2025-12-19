import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'game_card_models.dart';
import 'card_catalog.dart';

/// SharedPreferences key for the player's card collection.
///
/// IMPORTANT:
/// This should match the key used elsewhere in the app
/// (e.g. DeckManagementTab, Store, etc.).
const String kPlayerCollectionKey = 'player_collection';

/// Upgrades: map<cardId, count> stored as JSON.
/// NOTE: Stored per-mode by prefixing with 'antimatter_' when needed.
const String kCardUpgradeCountsKey = 'card_upgrade_counts';

/// Snapshot of which cards are upgradeable this run (frozen at rebirth).
/// NOTE: Stored per-mode by prefixing with 'antimatter_' when needed.
const String kUpgradeDeckSnapshotKey = 'rebirth_upgrade_deck_snapshot';

/// Deck persistence keys (same base string values as in deck_management_tab.dart).
const String _deckSlotCountKey = 'rebirth_deck_slot_count';
const String _decksDataKey = 'rebirth_decks_data';
const String _activeDeckIndexKey = 'rebirth_active_deck_index';

/// Active game mode key (must match IdleGameScreen / other screens).
const String _activeGameModeKey = 'active_game_mode';

/// A ready-to-use entry describing a card in the *active upgrade deck*
/// including its current owned level and its upgrade count this run.
class ActiveDeckCard {
  final GameCard card;

  /// Player's current level for this card (from OwnedCard.level).
  /// If not owned, falls back to snapshot level (if present) or baseLevel.
  final int level;

  /// Upgrades purchased this run for this card (per mode).
  final int upgradesThisRun;

  /// The actual OwnedCard entry if present (null if not owned).
  final OwnedCard? owned;

  const ActiveDeckCard({
    required this.card,
    required this.level,
    required this.upgradesThisRun,
    required this.owned,
  });
}

/// Repository for managing the player's card collection.
///
/// - Only one copy of each card ID is stored.
/// - If a card is obtained again, its experience is increased.
/// - Data is persisted in SharedPreferences as a JSON map:
///   {
///     "card_id": {
///       "cardId": "...",
///       "level": ...,
///       "experience": ...
///     },
///     ...
///   }
///
/// For backward compatibility, it also supports an older list-based format:
///   [ { "cardId": "...", "level": ..., "experience": ... }, ... ]
class PlayerCollectionRepository {
  PlayerCollectionRepository._internal();

  static final PlayerCollectionRepository instance =
  PlayerCollectionRepository._internal();

  bool _initialized = false;
  final Map<String, OwnedCard> _cardsById = {};

  /// Cached prefs so we can provide synchronous “easy to call anywhere” accessors.
  /// This is set during init() and reused afterwards.
  SharedPreferences? _prefs;

  /// Map a base key to a per-mode key:
  ///  - gold mode: returns baseKey as-is (backwards compatible).
  ///  - antimatter: returns 'antimatter_<baseKey>'.
  String _modeKey(String baseKey, String gameMode) {
    if (gameMode == 'antimatter') return 'antimatter_$baseKey';
    return baseKey;
  }

  /// Resolve the current game mode from SharedPreferences.
  /// Handles older string values like 'mine_gold' / 'create_antimatter'.
  String resolveCurrentGameMode(SharedPreferences prefs) {
    final storedMode = prefs.getString(_activeGameModeKey);

    if (storedMode == 'mine_gold') return 'gold';
    if (storedMode == 'create_antimatter') return 'antimatter';
    if (storedMode == 'gold' || storedMode == 'antimatter') {
      return storedMode!;
    }
    return 'gold';
  }

  Future<void> init() async {
    if (_initialized) return;

    _prefs ??= await SharedPreferences.getInstance();
    final prefs = _prefs!;
    final jsonStr = prefs.getString(kPlayerCollectionKey);

    _cardsById.clear();

    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final decoded = json.decode(jsonStr);

        if (decoded is Map<String, dynamic>) {
          // Preferred map-based format
          decoded.forEach((cardId, data) {
            if (data is Map<String, dynamic>) {
              _cardsById[cardId] = OwnedCard.fromJson(data);
            }
          });
        } else if (decoded is List) {
          // Backward compatibility: old list-based format
          for (final e in decoded) {
            if (e is Map<String, dynamic>) {
              final oc = OwnedCard.fromJson(e);
              _cardsById[oc.cardId] = oc;
            }
          }
        }
      } catch (_) {
        // If parsing fails, start with an empty collection.
        _cardsById.clear();
      }
    }

    _initialized = true;
  }

  Future<void> _save() async {
    _prefs ??= await SharedPreferences.getInstance();
    final prefs = _prefs!;
    final encoded = _cardsById.map((id, owned) {
      return MapEntry(id, owned.toJson());
    });
    await prefs.setString(kPlayerCollectionKey, json.encode(encoded));
  }

  /// Returns all owned cards as an immutable list.
  List<OwnedCard> get allOwnedCards =>
      List<OwnedCard>.unmodifiable(_cardsById.values);

  /// Returns the owned-entry for [cardId], or null if not owned.
  OwnedCard? getOwnedCard(String cardId) => _cardsById[cardId];

  /// Returns true if the player owns [cardId].
  bool ownsCard(String cardId) => _cardsById.containsKey(cardId);

  /// -------------------------------
  /// UPGRADE COUNTS (PER MODE)
  /// -------------------------------

  /// Synchronous read of per-run upgrade counts for a mode.
  /// Returns cardId -> count.
  Map<String, int> readUpgradeCountsSync(String gameMode) {
    final prefs = _prefs;
    if (prefs == null) return {};

    final mk = (String baseKey) => _modeKey(baseKey, gameMode);
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
    return counts;
  }

  /// -------------------------------
  /// ACTIVE UPGRADE DECK (SYNC)
  /// -------------------------------

  /// Returns the current *active upgrade deck* for the given mode:
  /// - Uses the frozen snapshot list if it exists (PER MODE).
  /// - If missing, falls back to the current active deck selection (PER MODE).
  /// - Merges in:
  ///    * player level (OwnedCard.level)
  ///    * upgrades this run (kCardUpgradeCountsKey)
  ///
  /// This is synchronous and safe to call from card effects.
  /// NOTE: For best results, ensure PlayerCollectionRepository.init() was called
  /// early in app startup (it already is in your deck tab / upgrade screen).
  List<ActiveDeckCard> getActiveUpgradeDeckSync({
    required String gameMode,
  }) {
    final prefs = _prefs;
    if (prefs == null) return const [];

    final mk = (String baseKey) => _modeKey(baseKey, gameMode);

    final counts = readUpgradeCountsSync(gameMode);

    // 1) Try frozen snapshot first (PER MODE).
    final snapshotJson = prefs.getString(mk(kUpgradeDeckSnapshotKey));
    final fromSnapshot = _buildActiveDeckFromSnapshotJson(
      snapshotJson: snapshotJson,
      counts: counts,
    );
    if (fromSnapshot != null && fromSnapshot.isNotEmpty) {
      return fromSnapshot;
    }

    // 2) Fallback: derive from active deck selection (PER MODE).
    final fromDeck = _buildActiveDeckFromCurrentActiveDeckPrefs(
      prefs: prefs,
      gameMode: gameMode,
      counts: counts,
    );

    return fromDeck;
  }

  List<ActiveDeckCard>? _buildActiveDeckFromSnapshotJson({
    required String? snapshotJson,
    required Map<String, int> counts,
  }) {
    if (snapshotJson == null || snapshotJson.isEmpty) return null;

    try {
      final decoded = jsonDecode(snapshotJson);
      if (decoded is! List) return null;

      final List<ActiveDeckCard> rows = [];

      for (final entry in decoded) {
        if (entry is! Map<String, dynamic>) continue;

        final cardId = entry['cardId']?.toString();
        if (cardId == null) continue;

        final card = CardCatalog.getById(cardId);
        if (card == null) continue;

        // Snapshot may include 'level' from older runs; it is fallback only.
        final snapshotLevelRaw = entry['level'];
        int snapshotLevel = 1;
        if (snapshotLevelRaw is int) {
          snapshotLevel = snapshotLevelRaw;
        } else if (snapshotLevelRaw is num) {
          snapshotLevel = snapshotLevelRaw.toInt();
        }

        final owned = _cardsById[cardId];
        final int level = owned?.level ?? snapshotLevel.clamp(1, 9999);

        rows.add(
          ActiveDeckCard(
            card: card,
            level: level,
            upgradesThisRun: counts[cardId] ?? 0,
            owned: owned,
          ),
        );
      }

      return rows;
    } catch (_) {
      return null;
    }
  }

  List<ActiveDeckCard> _buildActiveDeckFromCurrentActiveDeckPrefs({
    required SharedPreferences prefs,
    required String gameMode,
    required Map<String, int> counts,
  }) {
    final mk = (String baseKey) => _modeKey(baseKey, gameMode);

    final deckSlotCount = prefs.getInt(mk(_deckSlotCountKey)) ?? 1;
    final activeDeckIndexZero = prefs.getInt(mk(_activeDeckIndexKey)) ?? 0;
    final decksJson = prefs.getString(mk(_decksDataKey));

    List<_RepoDeckData> decks = [];

    if (decksJson != null && decksJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(decksJson);
        if (decoded is List) {
          decks = decoded
              .whereType<Map<String, dynamic>>()
              .map((m) => _RepoDeckData.fromJson(m))
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
        _RepoDeckData(
          id: 'deck_${index + 1}',
          name: 'Deck ${index + 1}',
          cardIds: const [],
        ),
      );
    }

    int idx = activeDeckIndexZero;
    if (idx < 0 || idx >= decks.length) idx = 0;

    final activeDeck = decks[idx];

    final List<ActiveDeckCard> result = [];
    for (final cardId in activeDeck.cardIds) {
      final card = CardCatalog.getById(cardId);
      if (card == null) continue;

      final owned = _cardsById[cardId];
      final level = owned?.level ?? card.baseLevel;

      result.add(
        ActiveDeckCard(
          card: card,
          level: level,
          upgradesThisRun: counts[cardId] ?? 0,
          owned: owned,
        ),
      );
    }

    return result;
  }

  /// Returns the list of GameCards in the *current active deck* for the given
  /// gameMode ('gold' or 'antimatter'), using the same SharedPreferences deck
  /// schema as DeckManagementTab / UpgradesScreen.
  ///
  /// This does NOT touch the player's collection; it only resolves the deck card IDs
  /// into GameCard objects via CardCatalog.
  Future<List<GameCard>> getCurrentActiveDeckCards({
    required SharedPreferences prefs,
    required String gameMode, // 'gold' or 'antimatter'
  }) async {
    // Keep behavior unchanged (existing logic).
    const String deckSlotCountKey = 'rebirth_deck_slot_count';
    const String decksDataKey = 'rebirth_decks_data';
    const String activeDeckIndexKey = 'rebirth_active_deck_index';

    String mk(String baseKey) {
      if (gameMode == 'antimatter') return 'antimatter_$baseKey';
      return baseKey;
    }

    final deckSlotCount = prefs.getInt(mk(deckSlotCountKey)) ?? 1;
    final activeDeckIndexZero = prefs.getInt(mk(activeDeckIndexKey)) ?? 0;
    final decksJson = prefs.getString(mk(decksDataKey));

    List<_RepoDeckData> decks = [];

    if (decksJson != null && decksJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(decksJson);
        if (decoded is List) {
          decks = decoded
              .whereType<Map<String, dynamic>>()
              .map((m) => _RepoDeckData.fromJson(m))
              .toList();
        }
      } catch (_) {
        decks = [];
      }
    }

    while (decks.length < deckSlotCount) {
      final index = decks.length;
      decks.add(
        _RepoDeckData(
          id: 'deck_${index + 1}',
          name: 'Deck ${index + 1}',
          cardIds: const [],
        ),
      );
    }

    int idx = activeDeckIndexZero;
    if (idx < 0 || idx >= decks.length) idx = 0;

    final activeDeck = decks[idx];

    final List<GameCard> activeCards = [];
    for (final cardId in activeDeck.cardIds) {
      final card = CardCatalog.getById(cardId);
      if (card != null) activeCards.add(card);
    }

    return activeCards;
  }

  /// Grant a card from a pack.
  ///
  /// If the player does not own [cardId], it is added at:
  ///   level = template.baseLevel (or 1 if missing), experience = [expGain].
  ///
  /// If the player *already* owns the card, only experience is increased.
  Future<void> grantCardOrExperience({
    required String cardId,
    int expGain = 0,
  }) async {
    await init();

    final current = _cardsById[cardId];
    if (current == null) {
      // New card
      final templateCard = CardCatalog.getById(cardId);
      final baseLevel = templateCard?.baseLevel ?? 1;

      _cardsById[cardId] = OwnedCard(
        cardId: cardId,
        level: baseLevel,
        experience: expGain,
      );
    } else {
      // Duplicate card: increase experience
      current.experience += expGain;
    }

    await _save();
  }

  /// For future use: update an owned card (e.g., after a level up).
  Future<void> upsertOwnedCard(OwnedCard ownedCard) async {
    await init();
    _cardsById[ownedCard.cardId] = ownedCard;
    await _save();
  }

  /// Clear in-memory state so it matches a wiped SharedPreferences.
  ///
  /// Used by the "Reset all progress" button. We do *not* need to touch
  /// SharedPreferences here if the caller already cleared it.
  Future<void> reset() async {
    _cardsById.clear();
    _initialized = false;
    _prefs = null;
  }
}

/// Private helper model (kept here so the deck JSON parsing stays centralized).
class _RepoDeckData {
  final String id;
  final String name;
  final List<String> cardIds;

  _RepoDeckData({
    required this.id,
    required this.name,
    required this.cardIds,
  });

  factory _RepoDeckData.fromJson(Map<String, dynamic> json) {
    final cardsRaw = json['cards'];
    final List<String> ids;
    if (cardsRaw is List) {
      ids = cardsRaw.map((e) => e.toString()).toList();
    } else {
      ids = const [];
    }

    return _RepoDeckData(
      id: json['id']?.toString() ?? 'deck_1',
      name: json['name']?.toString() ?? 'Deck 1',
      cardIds: ids,
    );
  }
}
