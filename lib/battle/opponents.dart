import '../cards/card_catalog.dart';

class Opponent {
  final String opponentId;
  final String name;

  /// Campaign/battle level (you can interpret this however you want).
  final int level;

  /// The opponent's deck is hard-coded with fixed card levels + draw probabilities.
  final CardDeck deck;

  const Opponent({
    required this.opponentId,
    required this.name,
    required this.level,
    required this.deck,
  });
}

class OpponentCatalog {
  /// All opponents live here, similar to CardCatalog.
  static final List<Opponent> opponents = [
    Opponent(
      opponentId: 'campaign_opp_lv1',
      name: 'Novice Prospector',
      level: 1,
      deck: CardDeck(
        deckId: 'opp_campaign_lv1_deck',
        entries: const [
          DeckCardEntry(
            cardId: 'lux_aurea_1', // Fool's Gold
            probability: 1.0,
            level: 1,
          ),
        ],
      ),
    ),
    Opponent(
      opponentId: 'player_default_deck',
      name: 'Player Default',
      level: 1,
      deck: CardDeck(
        deckId: 'opp_campaign_lv1_deck',
        entries: const [
          DeckCardEntry(
            cardId: 'lux_aurea_2',
            probability: 1.0,
            level: 1,
          ),
        ],
      ),
    ),
  ];

  static Opponent? byId(String id) {
    for (final o in opponents) {
      if (o.opponentId == id) return o;
    }
    return null;
  }

  /// Convenience: get the opponent for a given campaign level if you want.
  /// Right now it just finds first matching.
  static Opponent? byLevel(int level) {
    for (final o in opponents) {
      if (o.level == level) return o;
    }
    return null;
  }
}
