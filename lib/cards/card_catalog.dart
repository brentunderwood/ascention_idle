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
        target.setOrePerSecond(target.getBaseOrePerSecond() + 1.0);
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
        target.setOrePerSecond(target.getBaseOrePerSecond() + 10.0);
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
        target.setOrePerSecond(target.getBaseOrePerSecond() + 100.0);
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
        final delta = math.pow(10.0, 3).toDouble();
        target.setOrePerSecond(target.getBaseOrePerSecond() + delta);
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
        final delta = math.pow(10.0, 4).toDouble();
        target.setOrePerSecond(target.getBaseOrePerSecond() + delta);
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
      shortDescription:
      'A hobby for people who like shiny things, but hate other people.',
      longDescription:
      'Increases your ore per second by 100K. Now we\'re talking.',
      cardEffect: (target, cardLevel, upgradesThisRun) {
        final delta = math.pow(10.0, 5).toDouble();
        target.setOrePerSecond(target.getBaseOrePerSecond() + delta);
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
      shortDescription:
      'There\'s a giant man in the sky and he wants you to give me all your money.',
      longDescription:
      'Increases your ore per second by 1M. People are starving in the streets, but the church needs a new diamond custed altar, so....',
      cardEffect: (target, cardLevel, upgradesThisRun) {
        final delta = math.pow(10.0, 6).toDouble();
        target.setOrePerSecond(target.getBaseOrePerSecond() + delta);
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
      shortDescription:
      'With a waive of my hands...Your wallet is now missing.',
      longDescription:
      'Increases your ore per second by 10M. Now how much does it cost to make the magicians go away?',
      cardEffect: (target, cardLevel, upgradesThisRun) {
        final delta = math.pow(10.0, 7).toDouble();
        target.setOrePerSecond(target.getBaseOrePerSecond() + delta);
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
        final delta = math.pow(10.0, 8).toDouble();
        target.setOrePerSecond(target.getBaseOrePerSecond() + delta);
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
        final delta = math.pow(10.0, 9).toDouble();
        target.setOrePerSecond(target.getBaseOrePerSecond() + delta);
      },
    ),

    'lux_aurea_unique': GameCard(
      id: 'lux_aurea_unique',
      name: 'Aurea Alchemy',
      rank: -1,
      baseLevel: 1,
      evolutionLevel: 1,
      packId: 'lux_aurea',
      backgroundAsset: 'assets/lux_aurea/card_base_lux_aurea.png',
      artAsset: 'assets/lux_aurea/unique/lv_1_aurea_alchemy.png',
      shortDescription: 'Creating gold from gold',
      longDescription:
      'Increases your ore per second by [number purchased] squared. The only ore generating card you need.',
      cardEffect: (target, cardLevel, upgradesThisRun) {
        target.setOrePerSecond(target.getBaseOrePerSecond() + math.pow(upgradesThisRun,2) - math.pow(upgradesThisRun-1,2));
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
        final delta = math.pow(cardLevel, 2).toDouble();
        target.setBaseOrePerClick(target.getBaseOrePerClick() + delta);
      },
    ),

    'vita_orum_2': GameCard(
      id: 'vita_orum_2',
      name: 'Poppers',
      rank: 2,
      baseLevel: 1,
      evolutionLevel: 1,
      packId: 'vita_orum',
      backgroundAsset: 'assets/vita_orum/card_base_vita_orum.png',
      artAsset: 'assets/vita_orum/rank_1/lv_1_poppers.png',
      shortDescription: 'Did you mean the noisy kind or the sniffy kind?',
      longDescription:
      'Allows you to blow through those rocks a little faster to get to that sweet, sweet nugg. Scales based on level and count.',
      cardEffect: (target, cardLevel, upgradesThisRun) {
        target.setManualClickPower(target.getManualClickPower() + cardLevel);
      },
    ),

    'vita_orum_3': GameCard(
      id: 'vita_orum_3',
      name: 'Inertia',
      rank: 3,
      baseLevel: 1,
      evolutionLevel: 1,
      packId: 'vita_orum',
      backgroundAsset: 'assets/vita_orum/card_base_vita_orum.png',
      artAsset: 'assets/vita_orum/rank_3/lv_1_inertia.png',
      shortDescription: '',
      longDescription:
      'Each click is slightly more powerful than the last. Multiplier to click power is capped at [level]',
      cardEffect: (target, cardLevel, upgradesThisRun) {
        target.setMomentumCap(cardLevel.toDouble());
        final currentScale = target.getMomentumScale();
        target.setMomentumScale(currentScale + upgradesThisRun / 1000);
      },
    ),

    'vita_orum_5': GameCard(
      id: 'vita_orum_5',
      name: 'Rouse',
      rank: 5,
      baseLevel: 1,
      evolutionLevel: 1,
      packId: 'vita_orum',
      backgroundAsset: 'assets/vita_orum/card_base_vita_orum.png',
      artAsset: 'assets/vita_orum/rank_5/lv_1_rouse.png',
      shortDescription: 'Mmmmm...just 5 more minutes',
      longDescription:
      'Gives you a skill which allows you to increase resource production for a short time. Multiplier and duration both increase with [# owned] * [level].',
      cardEffect: (target, cardLevel, upgradesThisRun) {
        target.turnOnFrenzy();

        final currentMult = target.getFrenzyMultiplier();
        target.setFrenzyMultiplier(currentMult + cardLevel / 100);

        final currentDuration = target.getFrenzyDuration();
        target.setFrenzyDuration(currentDuration + cardLevel.toDouble());

        target.setFrenzyCooldownFraction(
          10 * math.pow(0.9, cardLevel - 1).toDouble(),
        );
      },
    ),

    'vita_orum_7': GameCard(
      id: 'vita_orum_7',
      name: 'Reciprocity',
      rank: 7,
      baseLevel: 1,
      evolutionLevel: 1,
      packId: 'vita_orum',
      backgroundAsset: 'assets/vita_orum/card_base_vita_orum.png',
      artAsset: 'assets/vita_orum/rank_7/lv_1_reciprocity.png',
      shortDescription: 'Because sharing is caring',
      longDescription:
      'Each upgrade adds 1% of your base click value to your ore per second and .01% * [level] of your base ore per second to your click value.',
      cardEffect: (target, cardLevel, upgradesThisRun) {
        // Bonus click from base ore/sec
        target.setGpsClickCoeff(target.getGpsClickCoeff() + cardLevel / 10000);

        target.setBaseClickOpsCoeff(target.getBaseClickOpsCoeff() + 0.01);
      },
    ),

    'vita_orum_10': GameCard(
      id: 'vita_orum_10',
      name: 'Stone Egg',
      rank: 10,
      baseLevel: 1,
      evolutionLevel: 1,
      packId: 'vita_orum',
      backgroundAsset: 'assets/vita_orum/card_base_vita_orum.png',
      artAsset: 'assets/vita_orum/rank_10/lv_1_stone_egg.png',
      shortDescription: 'It\'s not just a boulder, it\'s a rock.',
      longDescription:
      'A magical egg from the very heart of the earth. Increases your click power based on how much ore you have mined this rebirth. If you hatch it, you will find unlimited power.',
      cardEffect: (target, cardLevel, upgradesThisRun) {
        target.setGpsClickCoeff(target.getGpsClickCoeff() + 1);
      },
    ),

    'vita_orum_unique': GameCard(
      id: 'vita_orum_unique',
      name: 'Pluvia Vitalis',
      rank: -10,
      baseLevel: 1,
      evolutionLevel: 1,
      packId: 'vita_orum',
      backgroundAsset: 'assets/vita_orum/card_base_vita_orum.png',
      artAsset: 'assets/vita_orum/unique/lv_1_pluvia_vitalis.png',
      shortDescription: 'Who doesn\'t love a golden shower?',
      longDescription:
      'Every second has a [rebirth gold this round]x[number purchased]x[level] chance of generating 1 gold nugget. Clicking on these gives you 1 (or more if spawn rate > 1) gold, which you can spend immediately.',
      cardEffect: (target, cardLevel, upgradesThisRun) {
        target.setRandomSpawnChance(target.getCurrentRebirthGold() * upgradesThisRun * cardLevel);
      },
    ),

    //Chronon Epoch
    'chrono_epoch_1': GameCard(
      id: 'chrono_epoch_1',
      name: 'One Small Step',
      rank: 1,
      baseLevel: 1,
      evolutionLevel: 1,
      packId: 'chrono_epoch',
      backgroundAsset: 'assets/chrono_epoch/card_base_chrono_epoch.png',
      artAsset: 'assets/chrono_epoch/rank_1/lv_1_one_small_step.png',
      shortDescription: 'Because even a regular sized step is too hard',
      longDescription:
      'On your next rebirth, add a multipier to resource generation based on how many of this card you have and the amount of gold you have earned this run',
      cardEffect: (target, cardLevel, upgradesThisRun) {
        target.setRebirthMultiplier(upgradesThisRun.toDouble());
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
