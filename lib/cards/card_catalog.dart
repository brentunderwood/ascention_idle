import 'game_card_models.dart';
import 'dart:math' as math;

/// Central registry of all card templates in the game.
///
/// To create a new card, add a new [GameCard] entry to [_cardsById].
///
/// For Lux Aurea cards specifically, their runtime cost formulas are
/// handled in CardEffects. Here we embed *per-card effects* via the
/// [cardEffect] function so that behavior lives next to the card data.
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
  ///   - type: "Upgrade"-style behavior in your game logic
  ///   - packId: "lux_aurea"
  ///   - background & art: Lux Aurea frame + per-rank art
  ///
  /// Per-card effects live directly in the [cardEffect] field.
  static final Map<String, GameCard> _cardsById = {
    'lux_aurea_1': GameCard(
      id: 'lux_aurea_1',
      name: 'Fool\'s Gold',
      rank: 1,
      baseLevel: 1,
      evolutionLevel: 1,
      packId: 'lux_aurea',
      backgroundAsset: 'assets/lux_aurea/card_base_lux_aurea.png',
      artAsset: 'assets/lux_aurea/rank_1/lv_1_fools_gold.png',
      shortDescription: 'Ooh, shiny',
      longDescription:
      'Increases your ore per second by 1. Not much, but it\'s a start.',
      cardEffect: (target, cardLevel, upgradesThisRun) {
        target.addOrePerSecond(1.0);
      },
    ),
    'lux_aurea_2': GameCard(
      id: 'lux_aurea_2',
      name: 'Counterfeit Coin',
      rank: 2,
      baseLevel: 1,
      evolutionLevel: 1,
      packId: 'lux_aurea',
      backgroundAsset: 'assets/lux_aurea/card_base_lux_aurea.png',
      artAsset: 'assets/lux_aurea/rank_2/lv_1_counterfeit_coin.png',
      shortDescription: '*Bite* Tastes like prison.',
      longDescription:
      'Increases your ore per second by 10. Just don\'t get caught trying to spend it.',
      cardEffect: (target, cardLevel, upgradesThisRun) {
        target.addOrePerSecond(10.0);
      },
    ),
    'lux_aurea_3': GameCard(
      id: 'lux_aurea_3',
      name: 'Filthy Beggar',
      rank: 3,
      baseLevel: 1,
      evolutionLevel: 1,
      packId: 'lux_aurea',
      backgroundAsset: 'assets/lux_aurea/card_base_lux_aurea.png',
      artAsset: 'assets/lux_aurea/rank_3/lv_1_filthy_beggar.png',
      shortDescription: 'Please sir, do you have any gold bulion to spare?',
      longDescription:
      'Increases your ore per second by 100. Smells like dirt and capitalism.',
      cardEffect: (target, cardLevel, upgradesThisRun) {
        target.addOrePerSecond(100.0);
      },
    ),
    'lux_aurea_4': GameCard(
      id: 'lux_aurea_4',
      name: 'Skid Row',
      rank: 4,
      baseLevel: 1,
      evolutionLevel: 1,
      packId: 'lux_aurea',
      backgroundAsset: 'assets/lux_aurea/card_base_lux_aurea.png',
      artAsset: 'assets/lux_aurea/rank_4/lv_1_skid_row.png',
      shortDescription: 'Down on Skid, down on Skid, down on Skid Roooow!',
      longDescription:
      'Increases your ore per second by 1K. Maybe now you can afford to move somewhere nicer.',
      cardEffect: (target, cardLevel, upgradesThisRun) {
        target.addOrePerSecond(math.pow(10.0,3).toDouble());
      },
    ),
    'lux_aurea_5': GameCard(
      id: 'lux_aurea_5',
      name: 'Abandoned Town',
      rank: 5,
      baseLevel: 1,
      evolutionLevel: 1,
      packId: 'lux_aurea',
      backgroundAsset: 'assets/lux_aurea/card_base_lux_aurea.png',
      artAsset: 'assets/lux_aurea/rank_5/lv_1_abandoned_town.png',
      shortDescription: 'A ghost town. Sounds like a greeat investment.',
      longDescription:
      'Increases your ore per second by 10K. No people, but somehow plenty of gold.',
      cardEffect: (target, cardLevel, upgradesThisRun) {
        target.addOrePerSecond(math.pow(10.0,4).toDouble());
      },
    ),
    'lux_aurea_6': GameCard(
      id: 'lux_aurea_6',
      name: 'Prospecting',
      rank: 6,
      baseLevel: 1,
      evolutionLevel: 1,
      packId: 'lux_aurea',
      backgroundAsset: 'assets/lux_aurea/card_base_lux_aurea.png',
      artAsset: 'assets/lux_aurea/rank_6/lv_1_prospecting.png',
      shortDescription: 'A hobby for people who like shiny things, but hate other people.',
      longDescription:
      'Increases your ore per second by 100K. Now we\'re talking.',
      cardEffect: (target, cardLevel, upgradesThisRun) {
        target.addOrePerSecond(math.pow(10.0,5).toDouble());
      },
    ),
    'lux_aurea_7': GameCard(
      id: 'lux_aurea_7',
      name: 'Collect Alms',
      rank: 7,
      baseLevel: 1,
      evolutionLevel: 1,
      packId: 'lux_aurea',
      backgroundAsset: 'assets/lux_aurea/card_base_lux_aurea.png',
      artAsset: 'assets/lux_aurea/rank_7/lv_1_collect_alms.png',
      shortDescription: 'There\'s a giant man in the sky and he wants you to give me all your money.',
      longDescription:
      'Increases your ore per second by 1M. People are starving in the streets, but the church needs a new diamond custed altar, so....',
      cardEffect: (target, cardLevel, upgradesThisRun) {
        target.addOrePerSecond(math.pow(10.0,6).toDouble());
      },
    ),
    'lux_aurea_8': GameCard(
      id: 'lux_aurea_8',
      name: 'Prestidigitation',
      rank: 8,
      baseLevel: 1,
      evolutionLevel: 1,
      packId: 'lux_aurea',
      backgroundAsset: 'assets/lux_aurea/card_base_lux_aurea.png',
      artAsset: 'assets/lux_aurea/rank_8/lv_1_prestidigitation.png',
      shortDescription: 'With a waive of my hands...Your wallet is now missing.',
      longDescription:
      'Increases your ore per second by 10M. Now how much does it cost to make the magicians go away?',
      cardEffect: (target, cardLevel, upgradesThisRun) {
        target.addOrePerSecond(math.pow(10.0,7).toDouble());
      },
    ),
    'lux_aurea_9': GameCard(
      id: 'lux_aurea_9',
      name: 'Unsung Hero',
      rank: 9,
      baseLevel: 1,
      evolutionLevel: 1,
      packId: 'lux_aurea',
      backgroundAsset: 'assets/lux_aurea/card_base_lux_aurea.png',
      artAsset: 'assets/lux_aurea/rank_9/lv_1_unsung_hero.png',
      shortDescription: 'Better than an unhung zero.',
      longDescription:
      'Increases your ore per second by 100M. We must be running out of cards...right?',
      cardEffect: (target, cardLevel, upgradesThisRun) {
        target.addOrePerSecond(math.pow(10.0,8).toDouble());
      },
    ),
    'lux_aurea_10': GameCard(
      id: 'lux_aurea_10',
      name: 'Golden Egg',
      rank: 10,
      baseLevel: 1,
      evolutionLevel: 1,
      packId: 'lux_aurea',
      backgroundAsset: 'assets/lux_aurea/card_base_lux_aurea.png',
      artAsset: 'assets/lux_aurea/rank_10/lv_1_golden_egg.png',
      shortDescription: 'Where\'s the goose?',
      longDescription:
      'Increases your ore per second by 1B. If you can raise it to a full dragon, you will have riches beyond measure.',
      cardEffect: (target, cardLevel, upgradesThisRun) {
        target.addOrePerSecond(math.pow(10.0,9).toDouble());
      },
    ),

    // VITA ORUM CARDS
    'vita_orum_1': GameCard(
      id: 'vita_orum_1',
      name: 'Simple Pickaxe',
      rank: 1,
      baseLevel: 1,
      evolutionLevel: 1,
      packId: 'vita_orum',
      backgroundAsset: 'assets/vita_orum/card_base_vita_orum.png',
      artAsset: 'assets/vita_orum/rank_1/lv_1_simple_pickaxe.png',
      shortDescription: 'Breaking rocks in the hot sun...',
      longDescription:
      'Each pickaxe increases your resource generation per click by [Card Level] squared. You\'re welcome.',
      cardEffect: (target, cardLevel, upgradesThisRun) {
        target.addBaseOrePerClick(math.pow(cardLevel,2).toDouble());
      },
    ),

    'vita_orum_2': GameCard(
      id: 'vita_orum_2',
      name: 'Rouse',
      rank: 3,
      baseLevel: 1,
      evolutionLevel: 1,
      packId: 'vita_orum',
      backgroundAsset: 'assets/vita_orum/card_base_vita_orum.png',
      artAsset: 'assets/vita_orum/rank_3/lv_1_rouse.png',
      shortDescription: 'Mmmmm...just 5 more minutes',
      longDescription:
      'Gives you a skill which allows you to increase resource production for a short time. Improves with card level.',
      cardEffect: (target, cardLevel, upgradesThisRun) {
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
