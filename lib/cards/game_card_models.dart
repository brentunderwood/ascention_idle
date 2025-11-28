import 'package:flutter/foundation.dart';

/// A target that card effects can act on.
///
/// IdleGameScreen's State implements this, so card effects can call:
///  - addOrePerSecond(...)
///  - addOre(...)
///
/// You can extend this later with more operations as needed.
abstract class IdleGameEffectTarget {
  void addOrePerSecond(double amount);
  void addOre(double amount);
  void addBaseOrePerClick(double amount);
}

/// Signature for a card effect function.
///
/// - [target] is the current run's game state (IdleGameScreen state),
///   but seen only through the [IdleGameEffectTarget] interface.
/// - [cardLevel] is the player's level for that card.
/// - [upgradesThisRun] is how many times this card has been upgraded
///   so far in the *current* run.
typedef CardEffectFn = void Function(
    IdleGameEffectTarget target,
    int cardLevel,
    int upgradesThisRun,
    );

/// Immutable definition for a card "template" in the game.
/// This is the master data describing what a card IS,
/// regardless of how many copies a player owns.
@immutable
class GameCard {
  /// Unique ID used everywhere (deck lists, collection, saves, etc.)
  final String id;

  /// User-facing name (e.g. "Novice Prospector").
  final String name;

  /// Rarity / rank (you can define your own scale, e.g. 1–5 or 1–10).
  final int rank;

  /// Design-time base level (not the player's upgrade level).
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

  /// Optional effect method that can be invoked when this card is
  /// upgraded during a run.
  ///
  /// Signature:
  ///   (IdleGameEffectTarget target, int cardLevel, int upgradesThisRun)
  ///
  /// You can call this from the Upgrades tab whenever a purchase is made.
  final CardEffectFn? cardEffect;

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
    this.cardEffect,
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
