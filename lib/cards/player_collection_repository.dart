import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'game_card_models.dart'; // assumes OwnedCard is defined here
import 'card_catalog.dart';

/// SharedPreferences key for the player's card collection.
const String kPlayerCollectionKey = 'player_collection_v1';

/// Repository for managing the player's card collection.
///
/// - Only one copy of each card ID is stored.
/// - If a card is obtained again, its experience is increased.
/// - Data is persisted in SharedPreferences as a JSON map:
///   { "card_id": { "cardId": "...", "level": ..., "experience": ... }, ... }
class PlayerCollectionRepository {
  PlayerCollectionRepository._internal();

  static final PlayerCollectionRepository instance =
  PlayerCollectionRepository._internal();

  bool _initialized = false;
  final Map<String, OwnedCard> _cardsById = {};

  Future<void> init() async {
    if (_initialized) return;

    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(kPlayerCollectionKey);

    if (jsonStr != null && jsonStr.isNotEmpty) {
      final decoded = json.decode(jsonStr) as Map<String, dynamic>;
      decoded.forEach((cardId, data) {
        if (data is Map<String, dynamic>) {
          _cardsById[cardId] = OwnedCard.fromJson(data);
        }
      });
    }

    _initialized = true;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
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
}
