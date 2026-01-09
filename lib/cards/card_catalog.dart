import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

abstract class CardContext {
  T getStat<T>(String key);
  void setStat<T>(String key, T value);

  int getPlayedPlayer(String cardId);
  int getPlayedOpp(String cardId);

  void incrementPlayedPlayer(String cardId, [int by = 1]);
  void incrementPlayedOpp(String cardId, [int by = 1]);
}

/// Effect signature.
typedef CardEffect = void Function(CardContext ctx);

/// Cost signature.
typedef CardCost = int Function(GameCard card, CardContext ctx);
typedef CostMultiplier = double Function(GameCard card, CardContext ctx);

class GameCard {
  final String cardId;
  final String cardName;
  final String cardPack;
  final String description;
  final String imagePath;

  /// int rarity levels (1..N).
  final int rarity;

  /// Instance stats (these can be "player-derived" or "deck-fixed").
  final int level;
  final int experience;

  /// Mutable counters on the instance (optional usage).
  int playCount;

  final CardEffect effect;
  final CardCost cost;

  final int evolution;
  final bool isPrivate;
  final CostMultiplier costMultiplier;

  /// XP needed per level step for this card (simple curve).
  final int evolveAt;

  GameCard({
    required this.cardId,
    required this.cardName,
    required this.cardPack,
    required this.description,
    required this.imagePath,
    required this.rarity,
    required this.level,
    required this.experience,
    required this.playCount,
    required this.effect,
    required this.cost,
    required this.evolution,
    required this.isPrivate,
    required this.costMultiplier,
    required this.evolveAt,
  });

  GameCard copyWith({
    int? level,
    int? experience,
    int? playCount,
    String? imagePath,
    String? description,
  }) {
    return GameCard(
      cardId: cardId,
      cardName: cardName,
      cardPack: cardPack,
      description: description ?? this.description,
      imagePath: imagePath ?? this.imagePath,
      rarity: rarity,
      level: level ?? this.level,
      experience: experience ?? this.experience,
      playCount: playCount ?? this.playCount,
      effect: effect,
      cost: cost,
      evolution: evolution,
      isPrivate: isPrivate,
      costMultiplier: costMultiplier,
      evolveAt: evolveAt,
    );
  }
}

class CardCatalog {
  /// Not const because cards contain closures (effects/cost) and mutable counters.
  static final List<GameCard> cards = [
    GameCard(
      cardId: 'lux_aurea_1',
      cardName: 'Fool\'s Gold',
      cardPack: 'lux_aurea',
      description: 'Generate 1 dirt per second',
      imagePath: 'assets/lux_aurea/rank_1/lv_1_fools_gold.png',
      rarity: 1,
      level: 1,
      experience: 0,
      playCount: 0,
      effect: (CardContext ctx) {
        final int ops = ctx.getStat<int>('ore_per_second');
        ctx.setStat<int>('ore_per_second', ops + 1);
      },
      cost: _basicCost,
      evolution: 1,
      isPrivate: false,
      costMultiplier: _basicMultiplier,
      evolveAt: 2500,
    ),
  ];

  static GameCard? byId(String id) {
    for (final c in cards) {
      if (c.cardId == id) return c;
    }
    return null;
  }
}

int _basicCost(GameCard card, CardContext ctx) {
  final double base = pow(10, card.rarity).toDouble();
  final double finalCost = base * card.costMultiplier(card, ctx);
  return finalCost.floor();
}

double _basicMultiplier(GameCard card, CardContext ctx) {
  final double m = 1.0 + 1.0 / card.level;
  return pow(m, card.playCount).toDouble();
}

/// =============================================================
/// PLAYER COLLECTION (PERSISTED)
/// =============================================================

class PlayerOwnedCard {
  final String cardId;

  /// Total XP accumulated for this card.
  int totalXp;

  /// Optional persisted playcount.
  int playCount;

  PlayerOwnedCard({
    required this.cardId,
    required this.totalXp,
    required this.playCount,
  });

  Map<String, dynamic> toJson() => {
    'cardId': cardId,
    'totalXp': totalXp,
    'playCount': playCount,
  };

  static PlayerOwnedCard fromJson(Map<String, dynamic> json) {
    return PlayerOwnedCard(
      cardId: (json['cardId'] as String?) ?? '',
      totalXp: (json['totalXp'] as num?)?.toInt() ?? 0,
      playCount: (json['playCount'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Persistent store for "what the player owns" plus XP/level.
/// - Unique by cardId
/// - Levels derived from total XP and evolveAt
class PlayerCollection {
  static const String _prefsKey = 'player_collection_v1';

  PlayerCollection._();
  static final PlayerCollection instance = PlayerCollection._();

  bool _inited = false;

  final Map<String, PlayerOwnedCard> _owned = {};

  Future<void> init() async {
    if (_inited) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          _owned.clear();
          for (final entry in decoded.entries) {
            final v = entry.value;
            if (v is Map<String, dynamic>) {
              final owned = PlayerOwnedCard.fromJson(v);
              if (owned.cardId.isNotEmpty) {
                _owned[owned.cardId] = owned;
              }
            }
          }
        }
      } catch (_) {
        _owned.clear();
      }
    }
    _inited = true;
  }

  bool get isInited => _inited;

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    final map = <String, dynamic>{};
    for (final e in _owned.entries) {
      map[e.key] = e.value.toJson();
    }
    await prefs.setString(_prefsKey, jsonEncode(map));
  }

  bool ownsCard(String cardId) => _owned.containsKey(cardId);

  PlayerOwnedCard? ownedRecord(String cardId) => _owned[cardId];

  int derivedLevel(String cardId) {
    final owned = _owned[cardId];
    if (owned == null) return 0;
    final base = CardCatalog.byId(cardId);
    if (base == null) return 1;
    final step = max(1, base.evolveAt);
    return 1 + (owned.totalXp ~/ step);
  }

  /// Builds a *new* instance representing the player's current version.
  GameCard? buildPlayerCard(String cardId) {
    final base = CardCatalog.byId(cardId);
    if (base == null) return null;
    final owned = _owned[cardId];
    if (owned == null) return null;

    final lvl = derivedLevel(cardId);
    final xp = owned.totalXp;

    return base.copyWith(
      level: lvl,
      experience: xp,
      playCount: owned.playCount,
    );
  }

  Future<GameCard?> addOrUpdateCard({
    required String cardId,
    required int xpGain,
    int initialPlayCount = 0,
  }) async {
    if (!_inited) {
      await init();
    }

    final base = CardCatalog.byId(cardId);
    if (base == null) return null;

    final owned = _owned.putIfAbsent(
      cardId,
          () => PlayerOwnedCard(cardId: cardId, totalXp: 0, playCount: initialPlayCount),
    );

    owned.totalXp = max(0, owned.totalXp + max(0, xpGain));
    await save();
    return buildPlayerCard(cardId);
  }

  Future<void> incrementPlayCount(String cardId, {int by = 1}) async {
    if (!_inited) await init();
    final owned = _owned[cardId];
    if (owned == null) return;
    owned.playCount += max(0, by);
    await save();
  }

  List<GameCard> allOwnedCardsAsInstances() {
    final out = <GameCard>[];
    for (final id in _owned.keys) {
      final c = buildPlayerCard(id);
      if (c != null) out.add(c);
    }
    return out;
  }
}

/// =============================================================
/// DECKS (PERSISTED) — EACH CARD HAS PROBABILITY + FIXED LEVEL
/// =============================================================

class DeckCardEntry {
  final String cardId;

  /// Chance weight in range [0, 1]. (Not required to sum to 1; drawing uses weights.)
  final double probability;

  /// Fixed level for this deck entry. This overrides the player collection level.
  final int level;

  const DeckCardEntry({
    required this.cardId,
    required this.probability,
    required this.level,
  });

  DeckCardEntry copyWith({
    String? cardId,
    double? probability,
    int? level,
  }) {
    return DeckCardEntry(
      cardId: cardId ?? this.cardId,
      probability: probability ?? this.probability,
      level: level ?? this.level,
    );
  }

  Map<String, dynamic> toJson() => {
    'cardId': cardId,
    'probability': probability,
    'level': level,
  };

  static DeckCardEntry fromJson(Map<String, dynamic> json) {
    final id = (json['cardId'] as String?) ?? '';
    final prob = (json['probability'] as num?)?.toDouble() ?? 0.0;
    final lvl = (json['level'] as num?)?.toInt() ?? 1;

    return DeckCardEntry(
      cardId: id,
      probability: prob.isNaN ? 0.0 : prob,
      level: lvl < 1 ? 1 : lvl,
    );
  }
}

class CardDeck {
  /// Stored as: deck_<deckId>_v2
  static String _prefsKeyFor(String deckId) => 'deck_${deckId}_v2';

  final String deckId;

  /// Ordered entries (easy UI + deterministic export).
  final List<DeckCardEntry> entries;

  CardDeck({
    required this.deckId,
    List<DeckCardEntry>? entries,
  }) : entries = entries ?? [];

  /// Easy init: load existing if present, otherwise empty deck.
  static Future<CardDeck> load(String deckId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKeyFor(deckId));
    if (raw == null || raw.trim().isEmpty) {
      return CardDeck(deckId: deckId);
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final list = decoded['entries'];
        if (list is List) {
          return CardDeck(
            deckId: deckId,
            entries: list
                .whereType<Map>()
                .map((m) => DeckCardEntry.fromJson(m.cast<String, dynamic>()))
                .where((e) => e.cardId.isNotEmpty)
                .toList(),
          );
        }
      }
    } catch (_) {
      // corrupted -> return empty (don’t crash)
    }

    return CardDeck(deckId: deckId);
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKeyFor(deckId),
      jsonEncode({
        'entries': entries.map((e) => e.toJson()).toList(),
      }),
    );
  }

  /// Adds or replaces an entry by cardId.
  Future<void> upsertEntry(DeckCardEntry entry) async {
    if (entry.cardId.isEmpty) return;

    final clampedProb = entry.probability.clamp(0.0, 1.0);
    final safeLvl = entry.level < 1 ? 1 : entry.level;

    final idx = entries.indexWhere((e) => e.cardId == entry.cardId);
    final normalized = DeckCardEntry(
      cardId: entry.cardId,
      probability: clampedProb.toDouble(),
      level: safeLvl,
    );

    if (idx >= 0) {
      entries[idx] = normalized;
    } else {
      entries.add(normalized);
    }
    await save();
  }

  Future<void> removeCard(String cardId) async {
    entries.removeWhere((e) => e.cardId == cardId);
    await save();
  }

  Future<void> clear() async {
    entries.clear();
    await save();
  }

  /// Returns a deck-fixed card instance:
  /// - level is taken from the deck entry
  /// - experience is set consistently for that level (total XP style)
  /// - does NOT depend on PlayerCollection at all
  GameCard? buildDeckCard(String cardId, {required int level}) {
    final base = CardCatalog.byId(cardId);
    if (base == null) return null;

    final safeLvl = max(1, level);
    final step = max(1, base.evolveAt);

    // Set experience as total XP at the start of that level.
    // (If you prefer 0 always, change this to 0.)
    final totalXpAtLevelStart = (safeLvl - 1) * step;

    return base.copyWith(
      level: safeLvl,
      experience: totalXpAtLevelStart,
      playCount: 0,
    );
  }

  /// Weighted draw using probabilities (weights). Returns a deck-fixed GameCard.
  /// - If probabilities don't sum to 1, this still works (relative weights).
  /// - Entries with probability <= 0 are ignored.
  GameCard? drawRandomCard({Random? rng}) {
    rng ??= Random();

    double total = 0.0;
    for (final e in entries) {
      final p = e.probability;
      if (p > 0) total += p;
    }
    if (total <= 0) return null;

    final roll = rng.nextDouble() * total;
    double acc = 0.0;
    for (final e in entries) {
      final p = e.probability;
      if (p <= 0) continue;
      acc += p;
      if (roll <= acc) {
        return buildDeckCard(e.cardId, level: e.level);
      }
    }

    // Fallback due to floating error: take last positive.
    for (int i = entries.length - 1; i >= 0; i--) {
      final e = entries[i];
      if (e.probability > 0) return buildDeckCard(e.cardId, level: e.level);
    }
    return null;
  }
}
