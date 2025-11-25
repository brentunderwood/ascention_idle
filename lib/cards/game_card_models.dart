import 'package:flutter/foundation.dart';

/// Immutable definition for a card "template" in the game.
/// This is the master data describing what a card IS,
/// regardless of how many copies a player owns.
@immutable
class GameCard {
  /// Unique ID used everywhere (deck lists, collection, saves, etc.)
  final String id;

  /// User-facing name (e.g. "Novice Prospector").
  final String name;

  /// Rarity / rank (you can define your own scale, e.g. 1–5).
  final int rank;

  /// Card level cap or base level behavior can be defined later.
  /// For now this is a "design rank" and not the player's upgrade level.
  final int baseLevel;
  final int evolutionLevel;

  /// Pack ID this card belongs to (e.g. "lux_aurea", "vita_aurum").
  final String packId;

  /// Background asset for the card frame, usually shared within a pack.
  final String backgroundAsset;

  /// Main art for this specific card.
  final String artAsset;

  /// Optional small icon for use in lists, deck builders, etc.
  final String? iconAsset;

  /// Short description of the effect (for UI tooltips).
  final String shortDescription;

  /// Longer explanation of what the card does.
  final String longDescription;

  /// A logical "effect ID" used by your game logic to decide how the card
  /// modifies the run (e.g. "lux_gold_per_second", "antimatter_click_boost").
  final String effectId;

  /// Optional parameter payload for the effect (e.g. magnitude, scaling).
  /// This lets you tune many cards' behavior without new code each time.
  final Map<String, dynamic> effectParams;

  const GameCard({
    required this.id,
    required this.name,
    required this.rank,
    required this.baseLevel,
    required this.evolutionLevel,
    required this.packId,
    required this.backgroundAsset,
    required this.artAsset,
    this.iconAsset,
    required this.shortDescription,
    required this.longDescription,
    required this.effectId,
    this.effectParams = const {}
  });
}

/// Represents what a player actually owns for a given card.
///
/// In this design:
/// - There is only a single copy of any given card in the collection.
/// - Pulling the same card again increases its experience.
/// - Level is the player-upgraded level for that card.
class OwnedCard {
  /// Reference to the master card by ID.
  final String cardId;

  /// Player-specific upgrade level for this card (1+).
  int level;

  /// Experience accumulated toward the next level.
  int experience;

  OwnedCard({
    required this.cardId,
    required this.level,
    required this.experience,
  })  : assert(level >= 1),
        assert(experience >= 0);

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

  Map<String, dynamic> toJson() => {
    'cardId': cardId,
    'level': level,
    'experience': experience,
  };

  factory OwnedCard.fromJson(Map<String, dynamic> json) {
    return OwnedCard(
      cardId: json['cardId'] as String,
      level: (json['level'] as num).toInt(),
      experience: (json['experience'] as num).toInt(),
    );
  }
}


/// Simple data model for a deck: a list of card IDs.
/// Any per-card quantities inside a deck can be encoded later if needed.
class DeckDefinition {
  final String id; // e.g. "deck_1", "deck_2"
  final String name; // e.g. "Lux Starter", "Ore Storm"
  final List<String> cardIds;

  const DeckDefinition({
    required this.id,
    required this.name,
    required this.cardIds,
  });

  DeckDefinition copyWith({
    String? id,
    String? name,
    List<String>? cardIds,
  }) {
    return DeckDefinition(
      id: id ?? this.id,
      name: name ?? this.name,
      cardIds: cardIds ?? List<String>.from(this.cardIds),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'cardIds': cardIds,
  };

  factory DeckDefinition.fromJson(Map<String, dynamic> json) {
    return DeckDefinition(
      id: json['id'] as String,
      name: json['name'] as String,
      cardIds: (json['cardIds'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
    );
  }
}
