import 'game_card_models.dart';

/// Central registry of all card templates in the game.
///
/// To create a new card, add a new [GameCard] entry to [_cardsById].
///
/// For Lux Aurea cards specifically, the runtime behavior is implemented
/// in [CardEffects] (see card_effects.dart). Whenever you see
///   effectId == 'lux_aurea_upgrade'
/// you should call the Lux Aurea helpers in CardEffects to compute
/// resources per tick, costs, etc.
class CardCatalog {
  /// -------------------------------------------------------------------------
  /// Singleton instance, so you can call:
  ///   CardCatalog.instance.getCardsForPack('lux_aurea');
  /// -------------------------------------------------------------------------
  CardCatalog._internal();
  static final CardCatalog instance = CardCatalog._internal();

  /// Internal map of cards keyed by ID.
  ///
  /// This includes the 10 Lux Aurea upgrade cards:
  ///   lux_aurea_1 ... lux_aurea_10
  ///
  /// Shared attributes:
  ///   - baseLevel: 1
  ///   - type: "Upgrade" (via effectParams["cardType"])
  ///   - packId: "lux_aurea"
  ///   - background & art: assets/card_background_lux_aurea.png
  ///
  /// Runtime formulas are *not* duplicated here; instead they live
  /// in card_effects.dart under [CardEffects.luxAurea*].
  static final Map<String, GameCard> _cardsById = {
    'lux_aurea_1': GameCard(
      id: 'lux_aurea_1',
      name: 'Lux_aurea_1',
      rank: 1,
      baseLevel: 1,
      evolutionLevel: 1,
      packId: 'lux_aurea',
      backgroundAsset: 'assets/card_background_lux_aurea.png',
      artAsset: 'assets/card_background_lux_aurea.png',
      shortDescription: 'Rank 1 Lux Aurea upgrade card.',
      longDescription:
      'A rank 1 Lux Aurea upgrade card from the Lux Aurea pack.\n'
          'Its behavior is defined by the shared lux_aurea_upgrade effect.',
      effectId: 'lux_aurea_upgrade',
      effectParams: const {
        'cardType': 'Upgrade',
        'family': 'lux_aurea',
      },
    ),
    'lux_aurea_2': GameCard(
      id: 'lux_aurea_2',
      name: 'Lux_aurea_2',
      rank: 2,
      baseLevel: 1,
      evolutionLevel: 1,
      packId: 'lux_aurea',
      backgroundAsset: 'assets/card_background_lux_aurea.png',
      artAsset: 'assets/card_background_lux_aurea.png',
      shortDescription: 'Rank 2 Lux Aurea upgrade card.',
      longDescription:
      'A rank 2 Lux Aurea upgrade card from the Lux Aurea pack.\n'
          'Its behavior is defined by the shared lux_aurea_upgrade effect.',
      effectId: 'lux_aurea_upgrade',
      effectParams: const {
        'cardType': 'Upgrade',
        'family': 'lux_aurea',
      },
    ),
    'lux_aurea_3': GameCard(
      id: 'lux_aurea_3',
      name: 'Lux_aurea_3',
      rank: 3,
      baseLevel: 1,
      evolutionLevel: 1,
      packId: 'lux_aurea',
      backgroundAsset: 'assets/card_background_lux_aurea.png',
      artAsset: 'assets/card_background_lux_aurea.png',
      shortDescription: 'Rank 3 Lux Aurea upgrade card.',
      longDescription:
      'A rank 3 Lux Aurea upgrade card from the Lux Aurea pack.\n'
          'Its behavior is defined by the shared lux_aurea_upgrade effect.',
      effectId: 'lux_aurea_upgrade',
      effectParams: const {
        'cardType': 'Upgrade',
        'family': 'lux_aurea',
      },
    ),
    'lux_aurea_4': GameCard(
      id: 'lux_aurea_4',
      name: 'Lux_aurea_4',
      rank: 4,
      baseLevel: 1,
      evolutionLevel: 1,
      packId: 'lux_aurea',
      backgroundAsset: 'assets/card_background_lux_aurea.png',
      artAsset: 'assets/card_background_lux_aurea.png',
      shortDescription: 'Rank 4 Lux Aurea upgrade card.',
      longDescription:
      'A rank 4 Lux Aurea upgrade card from the Lux Aurea pack.\n'
          'Its behavior is defined by the shared lux_aurea_upgrade effect.',
      effectId: 'lux_aurea_upgrade',
      effectParams: const {
        'cardType': 'Upgrade',
        'family': 'lux_aurea',
      },
    ),
    'lux_aurea_5': GameCard(
      id: 'lux_aurea_5',
      name: 'Lux_aurea_5',
      rank: 5,
      baseLevel: 1,
      evolutionLevel: 1,
      packId: 'lux_aurea',
      backgroundAsset: 'assets/card_background_lux_aurea.png',
      artAsset: 'assets/card_background_lux_aurea.png',
      shortDescription: 'Rank 5 Lux Aurea upgrade card.',
      longDescription:
      'A rank 5 Lux Aurea upgrade card from the Lux Aurea pack.\n'
          'Its behavior is defined by the shared lux_aurea_upgrade effect.',
      effectId: 'lux_aurea_upgrade',
      effectParams: const {
        'cardType': 'Upgrade',
        'family': 'lux_aurea',
      },
    ),
    'lux_aurea_6': GameCard(
      id: 'lux_aurea_6',
      name: 'Lux_aurea_6',
      rank: 6,
      baseLevel: 1,
      evolutionLevel: 1,
      packId: 'lux_aurea',
      backgroundAsset: 'assets/card_background_lux_aurea.png',
      artAsset: 'assets/card_background_lux_aurea.png',
      shortDescription: 'Rank 6 Lux Aurea upgrade card.',
      longDescription:
      'A rank 6 Lux Aurea upgrade card from the Lux Aurea pack.\n'
          'Its behavior is defined by the shared lux_aurea_upgrade effect.',
      effectId: 'lux_aurea_upgrade',
      effectParams: const {
        'cardType': 'Upgrade',
        'family': 'lux_aurea',
      },
    ),
    'lux_aurea_7': GameCard(
      id: 'lux_aurea_7',
      name: 'Lux_aurea_7',
      rank: 7,
      baseLevel: 1,
      evolutionLevel: 1,
      packId: 'lux_aurea',
      backgroundAsset: 'assets/card_background_lux_aurea.png',
      artAsset: 'assets/card_background_lux_aurea.png',
      shortDescription: 'Rank 7 Lux Aurea upgrade card.',
      longDescription:
      'A rank 7 Lux Aurea upgrade card from the Lux Aurea pack.\n'
          'Its behavior is defined by the shared lux_aurea_upgrade effect.',
      effectId: 'lux_aurea_upgrade',
      effectParams: const {
        'cardType': 'Upgrade',
        'family': 'lux_aurea',
      },
    ),
    'lux_aurea_8': GameCard(
      id: 'lux_aurea_8',
      name: 'Lux_aurea_8',
      rank: 8,
      baseLevel: 1,
      evolutionLevel: 1,
      packId: 'lux_aurea',
      backgroundAsset: 'assets/card_background_lux_aurea.png',
      artAsset: 'assets/card_background_lux_aurea.png',
      shortDescription: 'Rank 8 Lux Aurea upgrade card.',
      longDescription:
      'A rank 8 Lux Aurea upgrade card from the Lux Aurea pack.\n'
          'Its behavior is defined by the shared lux_aurea_upgrade effect.',
      effectId: 'lux_aurea_upgrade',
      effectParams: const {
        'cardType': 'Upgrade',
        'family': 'lux_aurea',
      },
    ),
    'lux_aurea_9': GameCard(
      id: 'lux_aurea_9',
      name: 'Lux_aurea_9',
      rank: 9,
      baseLevel: 1,
      evolutionLevel: 1,
      packId: 'lux_aurea',
      backgroundAsset: 'assets/card_background_lux_aurea.png',
      artAsset: 'assets/card_background_lux_aurea.png',
      shortDescription: 'Rank 9 Lux Aurea upgrade card.',
      longDescription:
      'A rank 9 Lux Aurea upgrade card from the Lux Aurea pack.\n'
          'Its behavior is defined by the shared lux_aurea_upgrade effect.',
      effectId: 'lux_aurea_upgrade',
      effectParams: const {
        'cardType': 'Upgrade',
        'family': 'lux_aurea',
      },
    ),
    'lux_aurea_10': GameCard(
      id: 'lux_aurea_10',
      name: 'Lux_aurea_10',
      rank: 10,
      baseLevel: 1,
      evolutionLevel: 1,
      packId: 'lux_aurea',
      backgroundAsset: 'assets/card_background_lux_aurea.png',
      artAsset: 'assets/card_background_lux_aurea.png',
      shortDescription: 'Rank 10 Lux Aurea upgrade card.',
      longDescription:
      'A rank 10 Lux Aurea upgrade card from the Lux Aurea pack.\n'
          'Its behavior is defined by the shared lux_aurea_upgrade effect.',
      effectId: 'lux_aurea_upgrade',
      effectParams: const {
        'cardType': 'Upgrade',
        'family': 'lux_aurea',
      },
    ),
  };

  /// Returns an immutable list of all card templates.
  static List<GameCard> get allCards =>
      List<GameCard>.unmodifiable(_cardsById.values);

  /// Returns a card by its ID, or null if not found.
  static GameCard? getById(String id) => _cardsById[id];

  /// Returns all cards in a given pack (e.g. "lux_aurea").
  static List<GameCard> cardsInPack(String packId) {
    return _cardsById.values
        .where((card) => card.packId == packId)
        .toList(growable: false);
  }

  /// Quick helper for checking if a card ID is known.
  static bool exists(String id) => _cardsById.containsKey(id);

  // ---------------------------------------------------------------------------
  // Instance helpers – thin wrappers around the static API so that
  // code like `CardCatalog.instance.getCardsForPack('lux_aurea')` works.
  // ---------------------------------------------------------------------------

  List<GameCard> getCardsForPack(String packId) => cardsInPack(packId);

  GameCard? getCardById(String id) => getById(id);

  List<GameCard> get all => allCards;

  bool hasCard(String id) => exists(id);
}
