import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../cards/card_catalog.dart';

/// Global persisted player data.
///
/// - Stores currency: currentGold, totalGoldEarned, currentDarkMatter
/// - Stores card collection via PlayerCollection (persistent, unique by cardId)
///
/// Usage pattern:
///   await PlayerDataRepository.instance.init();
///   final gold = PlayerDataRepository.instance.currentGold;
///   await PlayerDataRepository.instance.spendGold(50);
///   final card = PlayerDataRepository.instance.getOwnedCard('lux_aurea_1');
class PlayerDataRepository {
  PlayerDataRepository._();

  static final PlayerDataRepository instance = PlayerDataRepository._();

  // -------------------------
  // SharedPreferences keys
  // -------------------------
  static const String _kCurrentGold = 'player_current_gold';
  static const String _kTotalGold = 'player_total_gold_earned';
  static const String _kCurrentDarkMatter = 'player_current_dark_matter';

  /// LEGACY (v1) JSON map of cardId -> OwnedCard json.
  /// This is migrated once into PlayerCollection (card_catalog.dart) and then removed.
  static const String _kOwnedCardsJsonLegacy = 'player_owned_cards_v1';

  SharedPreferences? _prefs;
  bool _initialized = false;

  double _currentGold = 0;
  double _totalGoldEarned = 0;
  double _currentDarkMatter = 0;

  bool get isInitialized => _initialized;

  // -------------------------
  // Init / load
  // -------------------------
  Future<void> init() async {
    if (_initialized) return;

    _prefs = await SharedPreferences.getInstance();

    _currentGold = _prefs!.getDouble(_kCurrentGold) ?? 0.0;
    _totalGoldEarned = _prefs!.getDouble(_kTotalGold) ?? 0.0;
    _currentDarkMatter = _prefs!.getDouble(_kCurrentDarkMatter) ?? 0.0;

    // Init the new persistent player collection.
    await PlayerCollection.instance.init();

    // One-time migration from legacy OwnedCard store into PlayerCollection store.
    await _migrateLegacyOwnedCardsIfPresent();

    _initialized = true;
  }

  void _requireInit() {
    if (!_initialized || _prefs == null) {
      throw StateError(
        'PlayerDataRepository not initialized. Call PlayerDataRepository.instance.init() first.',
      );
    }
  }

  // -------------------------
  // Currency getters
  // -------------------------
  double get currentGold {
    _requireInit();
    return _currentGold;
  }

  double get totalGoldEarned {
    _requireInit();
    return _totalGoldEarned;
  }

  double get currentDarkMatter {
    _requireInit();
    return _currentDarkMatter;
  }

  // -------------------------
  // Currency mutation helpers
  // -------------------------

  /// Adds gold to currentGold and also increments totalGoldEarned.
  Future<void> addGold(double amount) async {
    _requireInit();
    if (amount <= 0) return;

    _currentGold += amount;
    _totalGoldEarned += amount;

    await _prefs!.setDouble(_kCurrentGold, _currentGold);
    await _prefs!.setDouble(_kTotalGold, _totalGoldEarned);
  }

  /// Spend gold from currentGold only (does NOT affect totalGoldEarned).
  /// Returns false if insufficient funds.
  Future<bool> spendGold(double amount) async {
    _requireInit();
    if (amount <= 0) return true;
    if (_currentGold < amount) return false;

    _currentGold -= amount;
    await _prefs!.setDouble(_kCurrentGold, _currentGold);
    return true;
  }

  /// Directly set current gold (useful for loading saves / debugging).
  Future<void> setCurrentGold(double value) async {
    _requireInit();
    _currentGold = value < 0 ? 0 : value;
    await _prefs!.setDouble(_kCurrentGold, _currentGold);
  }

  /// Adds dark matter to currentDarkMatter.
  Future<void> addDarkMatter(double amount) async {
    _requireInit();
    if (amount <= 0) return;

    _currentDarkMatter += amount;
    await _prefs!.setDouble(_kCurrentDarkMatter, _currentDarkMatter);
  }

  /// Spend dark matter. Returns false if insufficient.
  Future<bool> spendDarkMatter(double amount) async {
    _requireInit();
    if (amount <= 0) return true;
    if (_currentDarkMatter < amount) return false;

    _currentDarkMatter -= amount;
    await _prefs!.setDouble(_kCurrentDarkMatter, _currentDarkMatter);
    return true;
  }

  Future<void> setCurrentDarkMatter(double value) async {
    _requireInit();
    _currentDarkMatter = value < 0 ? 0 : value;
    await _prefs!.setDouble(_kCurrentDarkMatter, _currentDarkMatter);
  }

  // -------------------------
  // Card collection API (delegates to PlayerCollection)
  // -------------------------

  /// Unmodifiable view of the player's owned cards (compat view).
  /// NOTE: experience here is "XP into current level" (remainder), matching old behavior.
  List<OwnedCard> get allOwnedCards {
    _requireInit();
    final instances = PlayerCollection.instance.allOwnedCardsAsInstances();
    final out = <OwnedCard>[];

    for (final c in instances) {
      final base = CardCatalog.byId(c.cardId);
      final step = max(1, base?.evolveAt ?? 1);
      final xpIntoLevel = c.experience % step;

      out.add(
        OwnedCard(
          cardId: c.cardId,
          level: c.level < 1 ? 1 : c.level,
          experience: xpIntoLevel < 0 ? 0 : xpIntoLevel,
        ),
      );
    }

    return List<OwnedCard>.unmodifiable(out);
  }

  /// True if the player owns the cardId.
  bool ownsCard(String cardId) {
    _requireInit();
    return PlayerCollection.instance.ownsCard(cardId);
  }

  /// Returns the owned card instance (compat view), or null.
  /// NOTE: experience here is "XP into current level" (remainder), matching old behavior.
  OwnedCard? getOwnedCard(String cardId) {
    _requireInit();

    final rec = PlayerCollection.instance.ownedRecord(cardId);
    if (rec == null) return null;

    final base = CardCatalog.byId(cardId);
    final step = max(1, base?.evolveAt ?? 1);

    final level = PlayerCollection.instance.derivedLevel(cardId);
    final xpIntoLevel = rec.totalXp % step;

    return OwnedCard(
      cardId: cardId,
      level: level < 1 ? 1 : level,
      experience: xpIntoLevel < 0 ? 0 : xpIntoLevel,
    );
  }

  /// Insert or update a card directly (useful for migrations/debug).
  ///
  /// NOTE:
  /// PlayerCollection stores TOTAL XP. This function will only ever INCREASE
  /// progress (it won’t reduce XP/level if you pass smaller values).
  Future<void> upsertOwnedCard(OwnedCard card) async {
    _requireInit();

    final base = CardCatalog.byId(card.cardId);
    if (base == null) return;

    final step = max(1, base.evolveAt);
    final desiredTotalXp =
    max(0, (max(1, card.level) - 1) * step + max(0, card.experience));

    final existing = PlayerCollection.instance.ownedRecord(card.cardId);
    final currentTotalXp = existing?.totalXp ?? 0;

    if (desiredTotalXp <= currentTotalXp) {
      // No-op (we don't decrease).
      return;
    }

    await PlayerCollection.instance.addOrUpdateCard(
      cardId: card.cardId,
      xpGain: (desiredTotalXp - currentTotalXp).toInt(),
    );
  }

  /// Called when the player "finds" a copy of a card they already own.
  ///
  /// Rule:
  /// - Only one copy exists in collection.
  /// - New copy adds experience (xpGain).
  /// - Level-ups are derived from TOTAL XP and the card's evolveAt.
  ///
  /// Returns the updated compat OwnedCard (level + xp remainder).
  Future<OwnedCard> addOrUpdateCard({
    required String cardId,
    required int xpGain,
    int baseLevelIfNew = 1, // kept for API compatibility (ignored; level derives from XP)
    int Function(int level)? expToNextLevel, // kept for API compatibility (ignored)
  }) async {
    _requireInit();

    // Ensure card exists in catalog; if not, still allow storage but it won't level properly.
    await PlayerCollection.instance.addOrUpdateCard(
      cardId: cardId,
      xpGain: xpGain,
    );

    final owned = getOwnedCard(cardId);
    if (owned != null) return owned;

    // Fallback (should rarely happen unless cardId is invalid)
    return OwnedCard(cardId: cardId, level: max(1, baseLevelIfNew), experience: 0);
  }

  // -------------------------
  // Deck helpers (optional convenience)
  // -------------------------

  /// Each activity can have its own persisted deck by giving it a unique deckId.
  Future<CardDeck> loadDeck(String deckId) async {
    _requireInit();
    return CardDeck.load(deckId);
  }

  // -------------------------
  // Legacy migration
  // -------------------------

  Future<void> _migrateLegacyOwnedCardsIfPresent() async {
    final raw = _prefs!.getString(_kOwnedCardsJsonLegacy);
    if (raw == null || raw.trim().isEmpty) return;

    // If the new store already has cards, we still migrate missing ones, then remove legacy.
    Map<String, dynamic>? decoded;
    try {
      final v = jsonDecode(raw);
      if (v is Map<String, dynamic>) decoded = v;
    } catch (_) {
      decoded = null;
    }

    if (decoded == null) {
      // Corrupted legacy store; just remove it.
      await _prefs!.remove(_kOwnedCardsJsonLegacy);
      return;
    }

    // Convert legacy (level + remainder XP) into the new TOTAL XP model using evolveAt.
    // NOTE: legacy used a different XP curve; this migration prioritizes preserving
    // the *visible* level as best as possible by mapping:
    // totalXp ~= (level-1)*evolveAt + experience
    for (final entry in decoded.entries) {
      final cardId = entry.key;
      final v = entry.value;
      if (v is! Map<String, dynamic>) continue;

      final legacy = OwnedCard.fromJson(v).copyWith(cardId: cardId);

      final base = CardCatalog.byId(cardId);
      if (base == null) {
        // Unknown card id; skip.
        continue;
      }

      if (PlayerCollection.instance.ownsCard(cardId)) {
        // Already present in new store; skip.
        continue;
      }

      final step = max(1, base.evolveAt);
      final totalXp =
      max(0, (max(1, legacy.level) - 1) * step + max(0, legacy.experience));

      if (totalXp > 0) {
        await PlayerCollection.instance.addOrUpdateCard(
          cardId: cardId,
          xpGain: totalXp.toInt(),
        );
      } else {
        // Ensure the card is marked owned even if xp is 0.
        await PlayerCollection.instance.addOrUpdateCard(
          cardId: cardId,
          xpGain: 0,
        );
      }
    }

    // Remove legacy key so we never re-migrate.
    await _prefs!.remove(_kOwnedCardsJsonLegacy);
  }
}

/// Compat view of a player's owned card (kept because UI already expects this).
///
/// NOTE:
/// - level is derived from PlayerCollection.totalXp and card.evolveAt.
/// - experience is XP INTO CURRENT LEVEL (remainder), matching your old display.
class OwnedCard {
  final String cardId;
  final int level;
  final int experience;

  const OwnedCard({
    required this.cardId,
    required this.level,
    required this.experience,
  });

  OwnedCard copyWith({
    String? cardId,
    int? level,
    int? experience,
  }) {
    return OwnedCard(
      cardId: cardId ?? this.cardId,
      level: level ?? this.level,
      experience: experience ?? this.experience,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'cardId': cardId,
    'level': level,
    'experience': experience,
  };

  static OwnedCard fromJson(Map<String, dynamic> json) {
    final id = (json['cardId'] as String?) ?? '';
    final level = (json['level'] as num?)?.toInt() ?? 1;
    final exp = (json['experience'] as num?)?.toInt() ?? 0;
    return OwnedCard(
      cardId: id,
      level: level < 1 ? 1 : level,
      experience: exp < 0 ? 0 : exp,
    );
  }
}
