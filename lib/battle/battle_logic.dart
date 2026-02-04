// battle_logic.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../cards/card_catalog.dart';

/// =============================================================
/// battle_logic.dart
/// -------------------------------------------------------------
/// Battle state + persistence + core deck/draw utilities.
///
/// Shared resources are stored from the PLAYER perspective.
/// Opponent perspective reads shared resources as NEGATED values:
///   shared_persp = opponent ? -storedShared : storedShared
/// and writes back by negating again.
///
/// Spending rules:
/// - Negative balances cannot be spent (available = max(0, value)).
/// - For GOLD: spend shared gold first, then private gold for remainder.
/// - For non-gold: spend only from that shared resource (perspective-adjusted).
///
/// Card multiplier persistence:
/// - We persist a per-cardId multiplier for the player deck and opponent deck
///   (under the battle prefix).
/// - Multiplier starts at 1.0 for any unseen cardId.
///
/// Multiplier update rules (your spec):
/// - If PLAYER purchases card X:
///     - playerMultiplier[X] *= factor(playerCard)
///     - oppMultiplier[X]    /= factor(playerCard)
/// - If OPPONENT purchases card X:
///     - oppMultiplier[X]    *= factor(opponentCard)
///     - playerMultiplier[X] /= factor(opponentCard)
///
/// factor(card) uses the "basic multiplier" rule:
///   factor = 1 + 1/level
///
/// IMPORTANT FIX (your “cost doesn’t increase” issue):
/// - We DO NOT store cardMultiplier in the current-card snapshot.
/// - When loading a current card from SharedPrefs, we ALWAYS inject the latest
///   persisted multiplier for that cardId+side so cost updates immediately
///   after purchases.
///
/// Opponent AI:
/// - On every tick, select_action() is evaluated.
/// - If the chosen action is "play" AND the opponent can afford the card,
///   the opponent purchases its current card.
///
/// NEW: Total resources tracking + influence
/// - player_total_resources increases when:
///     * any shared resource increases (stored delta > 0)
///     * player private gold increases (delta > 0)
/// - opp_total_resources increases when:
///     * any shared resource decreases (stored delta < 0, add abs(delta))
///     * opponent private gold increases (delta > 0)
///
/// influence = 0.5
///   + playerOnHand / (oppTotal + 1 + oppHourGains)
///   - oppOnHand    / (playerTotal + 1 + playerHourGains)
///
/// playerOnHand = sum of positive shared values + player private gold
/// oppOnHand    = opp private gold + abs(sum of negative shared values)
///
/// playerHourGains = 3600 * (sum of positive shared per-sec + player private gold per-sec)
/// oppHourGains    = 3600 * (abs(sum of negative shared per-sec) + opp private gold per-sec)
///
/// -------------------------------------------------------------
/// NEW: Hypothetical simulation for draw/play/wait evaluators
///
/// - We snapshot the *current* battle state into a pure Dart object (BattleState)
///   and run hypothetical actions against that object without mutating prefs.
/// - play_value(card): simulate purchasing that card (cost spend + per-sec effect
///   with perspective inversion) on a copy of current state, then score with
///   predict_outcome(hypState).
/// - wait_value(): score predict_outcome(current state).
/// - calculate_draw_value(): for every card in the opponent deck, compute
///   play_value(deckCard) weighted by its probability, and return the sum.
/// =============================================================

class StartGameResult {
  final GameCard? playerCard;
  final GameCard? opponentCard;

  const StartGameResult({
    required this.playerCard,
    required this.opponentCard,
  });
}

class _MinimalCostContext implements CardContext {
  final Map<String, Object?> _stats = <String, Object?>{};
  final Map<String, int> _playedPlayer = <String, int>{};
  final Map<String, int> _playedOpp = <String, int>{};

  @override
  T getStat<T>(String key) {
    final v = _stats[key];
    if (v is T) return v;
    if (T == int) return 0 as T;
    if (T == double) return 0.0 as T;
    if (T == bool) return false as T;
    // ignore: null_check_always_fails
    return null as T;
  }

  @override
  void setStat<T>(String key, T value) {
    _stats[key] = value;
  }

  @override
  int getPlayedPlayer(String cardId) => _playedPlayer[cardId] ?? 0;

  @override
  int getPlayedOpp(String cardId) => _playedOpp[cardId] ?? 0;

  @override
  void incrementPlayedPlayer(String cardId, [int by = 1]) {
    _playedPlayer[cardId] = (_playedPlayer[cardId] ?? 0) + by;
  }

  @override
  void incrementPlayedOpp(String cardId, [int by = 1]) {
    _playedOpp[cardId] = (_playedOpp[cardId] ?? 0) + by;
  }
}

/// -------------------------------------------------------------
/// Pure snapshot state for hypothetical simulation (no prefs)
/// -------------------------------------------------------------
class BattleState {
  // Stored PLAYER perspective values
  double sharedGold;
  double sharedAntimatter;
  double sharedCombustion;
  double sharedDeath;
  double sharedLife;
  double sharedQuintessence;

  double playerPrivateGold;
  double oppPrivateGold;

  // Stored PLAYER perspective per-sec
  double sharedGoldPerSec;
  double sharedAntimatterPerSec;
  double sharedCombustionPerSec;
  double sharedDeathPerSec;
  double sharedLifePerSec;
  double sharedQuintessencePerSec;

  double playerPrivateGoldPerSec;
  double oppPrivateGoldPerSec;

  // Totals
  double playerTotalResources;
  double oppTotalResources;

  BattleState({
    required this.sharedGold,
    required this.sharedAntimatter,
    required this.sharedCombustion,
    required this.sharedDeath,
    required this.sharedLife,
    required this.sharedQuintessence,
    required this.playerPrivateGold,
    required this.oppPrivateGold,
    required this.sharedGoldPerSec,
    required this.sharedAntimatterPerSec,
    required this.sharedCombustionPerSec,
    required this.sharedDeathPerSec,
    required this.sharedLifePerSec,
    required this.sharedQuintessencePerSec,
    required this.playerPrivateGoldPerSec,
    required this.oppPrivateGoldPerSec,
    required this.playerTotalResources,
    required this.oppTotalResources,
  });

  BattleState copy() => BattleState(
    sharedGold: sharedGold,
    sharedAntimatter: sharedAntimatter,
    sharedCombustion: sharedCombustion,
    sharedDeath: sharedDeath,
    sharedLife: sharedLife,
    sharedQuintessence: sharedQuintessence,
    playerPrivateGold: playerPrivateGold,
    oppPrivateGold: oppPrivateGold,
    sharedGoldPerSec: sharedGoldPerSec,
    sharedAntimatterPerSec: sharedAntimatterPerSec,
    sharedCombustionPerSec: sharedCombustionPerSec,
    sharedDeathPerSec: sharedDeathPerSec,
    sharedLifePerSec: sharedLifePerSec,
    sharedQuintessencePerSec: sharedQuintessencePerSec,
    playerPrivateGoldPerSec: playerPrivateGoldPerSec,
    oppPrivateGoldPerSec: oppPrivateGoldPerSec,
    playerTotalResources: playerTotalResources,
    oppTotalResources: oppTotalResources,
  );
}

class BattleLogic extends ChangeNotifier {
  BattleLogic._();
  static final BattleLogic instance = BattleLogic._();

  // -------------------------
  // Pref keys (scoped to "current game")
  // -------------------------
  static const String _kBattlePrefix = 'battle_current_';

  static const String _kPlayerDeck = '${_kBattlePrefix}player_deck_v1';
  static const String _kOppDeck = '${_kBattlePrefix}opp_deck_v1';

  static const String _kPlayerCurrentCard = '${_kBattlePrefix}player_current_card_v1';
  static const String _kOppCurrentCard = '${_kBattlePrefix}opp_current_card_v1';
  static const String _kVictoryProgress = '${_kBattlePrefix}victory_progress_v1';

  // Values (stored PLAYER perspective)
  static const String _kSharedGold = '${_kBattlePrefix}shared_gold_v1';
  static const String _kSharedAntimatter = '${_kBattlePrefix}shared_antimatter_v1';
  static const String _kSharedCombustion = '${_kBattlePrefix}shared_combustion_v1';
  static const String _kSharedDeath = '${_kBattlePrefix}shared_death_v1';
  static const String _kSharedLife = '${_kBattlePrefix}shared_life_v1';
  static const String _kSharedQuintessence = '${_kBattlePrefix}shared_quintessence_v1';

  static const String _kPlayerPrivateGold = '${_kBattlePrefix}player_private_gold_v1';
  static const String _kOppPrivateGold = '${_kBattlePrefix}opp_private_gold_v1';

  // Per-second (stored PLAYER perspective)
  static const String _kSharedGoldPerSec = '${_kBattlePrefix}shared_gold_per_sec_v1';
  static const String _kSharedAntimatterPerSec = '${_kBattlePrefix}shared_antimatter_per_sec_v1';
  static const String _kSharedCombustionPerSec = '${_kBattlePrefix}shared_combustion_per_sec_v1';
  static const String _kSharedDeathPerSec = '${_kBattlePrefix}shared_death_per_sec_v1';
  static const String _kSharedLifePerSec = '${_kBattlePrefix}shared_life_per_sec_v1';
  static const String _kSharedQuintessencePerSec = '${_kBattlePrefix}shared_quintessence_per_sec_v1';

  static const String _kPlayerPrivateGoldPerSec = '${_kBattlePrefix}player_private_gold_per_sec_v1';
  static const String _kOppPrivateGoldPerSec = '${_kBattlePrefix}opp_private_gold_per_sec_v1';

  // Last tick timestamp
  static const String _kLastTickMs = '${_kBattlePrefix}last_tick_ms_v1';

  // Cached purchasability of the player's currently shown card
  static const String _kPlayerCardPurchasable = '${_kBattlePrefix}player_card_purchasable_v1';

  // -------------------------
  // NEW: total resources tracking
  // -------------------------
  static const String _kPlayerTotalResources = '${_kBattlePrefix}player_total_resources_v1';
  static const String _kOppTotalResources = '${_kBattlePrefix}opp_total_resources_v1';

  // -------------------------
  // per-side per-card multiplier persistence
  // -------------------------
  static String _kMulPlayer(String cardId) => '${_kBattlePrefix}mul_player_$cardId';
  static String _kMulOpp(String cardId) => '${_kBattlePrefix}mul_opp_$cardId';

  SharedPreferences? _prefs;
  bool _inited = false;

  Timer? _tickTimer;
  double Function()? _speedProvider;

  Future<void> init() async {
    if (_inited) return;
    _prefs = await SharedPreferences.getInstance();
    _inited = true;
  }

  void _requireInit() {
    if (!_inited || _prefs == null) {
      throw StateError('BattleLogic not initialized. Call BattleLogic.instance.init() first.');
    }
  }

  /// -------------------------------------------------------------
  /// Speed provider
  /// -------------------------------------------------------------
  void configure_speed_provider(double Function() provider) {
    _speedProvider = provider;
  }

  double _currentSpeed() {
    final sp = _speedProvider;
    if (sp == null) return 1.0;
    final v = sp();
    if (v.isNaN || !v.isFinite) return 1.0;
    return v <= 0 ? 0.0 : v;
  }

  void _startTickerIfNeeded() {
    if (_tickTimer != null) return;
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!_inited || _prefs == null) return;
      await update_tick(_currentSpeed());
    });
  }

  void stop_ticker() {
    _tickTimer?.cancel();
    _tickTimer = null;
  }

  /// -------------------------------------------------------------
  /// Last tick timestamp helpers
  /// -------------------------------------------------------------
  int? get_last_tick_ms_sync() {
    _requireInit();
    final v = _prefs!.getInt(_kLastTickMs);
    if (v == null || v <= 0) return null;
    return v;
  }

  Future<void> set_last_tick_ms(int ms) async {
    if (!_inited) await init();
    _requireInit();
    await _prefs!.setInt(_kLastTickMs, ms);
  }

  /// -------------------------------------------------------------
  /// handle_battle_screen_open
  /// -------------------------------------------------------------
  Future<void> handle_battle_screen_open() async {
    if (!_inited) await init();
    _requireInit();

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final lastMs = get_last_tick_ms_sync();

    double elapsedSeconds = 0.0;
    if (lastMs != null) {
      final deltaMs = nowMs - lastMs;
      if (deltaMs > 0) elapsedSeconds = (deltaMs ~/ 1000).toDouble(); // floored
    }

    if (lastMs == null) await set_last_tick_ms(nowMs);
    await calculate_offline_progress(elapsedSeconds);
  }

  Future<void> calculate_offline_progress(double elapsedSeconds) async {
    if (!_inited) await init();
    _requireInit();

    final e = (!elapsedSeconds.isFinite || elapsedSeconds <= 0) ? 0.0 : elapsedSeconds;

    if (e > 0) {
      await update_tick(e);
    } else {
      await set_last_tick_ms(DateTime.now().millisecondsSinceEpoch);
    }

    _startTickerIfNeeded();
    notifyListeners();
  }

  /// -------------------------------------------------------------
  /// clear_game_state
  /// -------------------------------------------------------------
  Future<void> clear_game_state() async {
    if (!_inited) await init();
    _requireInit();

    stop_ticker();

    final keys = _prefs!.getKeys().where((k) => k.startsWith(_kBattlePrefix)).toList();
    for (final k in keys) {
      await _prefs!.remove(k);
    }

    notifyListeners();
  }

  /// -------------------------------------------------------------
  /// set_player_deck / set_opp_deck
  /// -------------------------------------------------------------
  Future<void> set_player_deck(CardDeck deck) async {
    if (!_inited) await init();
    _requireInit();
    await _prefs!.setString(_kPlayerDeck, jsonEncode(_deckToJson(deck)));
    notifyListeners();
  }

  Future<void> set_opp_deck(CardDeck deck) async {
    if (!_inited) await init();
    _requireInit();
    await _prefs!.setString(_kOppDeck, jsonEncode(_deckToJson(deck)));
    notifyListeners();
  }

  /// -------------------------------------------------------------
  /// Multiplier getters/setters
  /// -------------------------------------------------------------
  double _get_multiplier({required bool forOppDeck, required String cardId}) {
    _requireInit();
    final k = forOppDeck ? _kMulOpp(cardId) : _kMulPlayer(cardId);
    final v = _prefs!.getDouble(k);
    if (v == null || !v.isFinite || v <= 0) return 1.0;
    return v;
  }

  Future<void> _set_multiplier({required bool forOppDeck, required String cardId, required double v}) async {
    if (!_inited) await init();
    _requireInit();
    final k = forOppDeck ? _kMulOpp(cardId) : _kMulPlayer(cardId);
    final safe = (!v.isFinite || v <= 0) ? 1.0 : v;
    await _prefs!.setDouble(k, safe);
  }

  double _factor_for_card(GameCard card) {
    final lvl = max(1, card.level);
    return 1.0 + 1.0 / lvl;
  }

  /// -------------------------------------------------------------
  /// draw_card
  /// -------------------------------------------------------------
  GameCard? draw_card(CardDeck deck, {Random? rng, bool forOppDeck = false}) {
    rng ??= Random();

    final entries = deck.entries;
    if (entries.isEmpty) return null;

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
      if (roll <= acc) return _buildDeckFixedCard(e, forOppDeck: forOppDeck);
    }

    for (int i = entries.length - 1; i >= 0; i--) {
      final e = entries[i];
      if (e.probability > 0) return _buildDeckFixedCard(e, forOppDeck: forOppDeck);
    }
    return null;
  }

  /// -------------------------------------------------------------
  /// start_game
  /// -------------------------------------------------------------
  Future<StartGameResult> start_game({Random? rng}) async {
    if (!_inited) await init();
    _requireInit();

    rng ??= Random();

    final playerDeck = get_player_deck_sync();
    final oppDeck = get_opp_deck_sync();

    final playerCard = (playerDeck == null) ? null : draw_card(playerDeck, rng: rng, forOppDeck: false);
    final opponentCard = (oppDeck == null) ? null : draw_card(oppDeck, rng: rng, forOppDeck: true);

    await set_player_current_card(playerCard);
    await set_opp_current_card(opponentCard);

    await set_player_private_gold_per_sec(1.0);
    await set_opp_private_gold_per_sec(1.0);

    await set_last_tick_ms(DateTime.now().millisecondsSinceEpoch);
    _startTickerIfNeeded();

    notifyListeners();
    return StartGameResult(playerCard: playerCard, opponentCard: opponentCard);
  }

  /// -------------------------------------------------------------
  /// Total resources (tracked)
  /// -------------------------------------------------------------
  double get_player_total_resources() => _getD(_kPlayerTotalResources, 0.0);
  double get_opp_total_resources() => _getD(_kOppTotalResources, 0.0);

  Future<void> _set_player_total_resources(double v) async {
    if (!_inited) await init();
    _requireInit();
    await _prefs!.setDouble(_kPlayerTotalResources, v.isFinite ? max(0.0, v) : 0.0);
  }

  Future<void> _set_opp_total_resources(double v) async {
    if (!_inited) await init();
    _requireInit();
    await _prefs!.setDouble(_kOppTotalResources, v.isFinite ? max(0.0, v) : 0.0);
  }

  /// -------------------------------------------------------------
  /// Influence (sync) (PERSISTED STATE)
  /// -------------------------------------------------------------
  double calculate_influence() {
    _requireInit();
    final s = _snapshot_state();
    return _calculate_influence_for_state(s).clamp(0.0, 1.0);
  }

  /// -------------------------------------------------------------
  /// Hypothetical evaluators + prediction
  /// -------------------------------------------------------------

  /// Predict outcome score for a hypothetical state.
  ///
  /// - Simulates forward until influence hits <= 0 or >= 1 (first moment).
  /// - If influence hits 0:  score =  1 / seconds
  /// - If influence hits 1:  score = -1 / seconds
  ///
  /// Uses a 1-second step simulation with a max cap to avoid infinite loops.
  double predict_outcome(BattleState initial) {
    // Safety
    const int maxSeconds = 60*60*24*365; // 24 hours cap
    final s = initial.copy();

    double inf0 = _calculate_influence_for_state(s);
    if (!inf0.isFinite) inf0 = 0.5;

    // If already terminal, treat as 1 second to avoid division by zero.
    if (inf0 <= 0.0) return 1.0 / 1.0;
    if (inf0 >= 1.0) return -1.0 / 1.0;

    for (int t = 1; t <= maxSeconds; t=(t*1.1).floor()) {
      _simulate_tick_for_state(s, (t/11.0).ceilToDouble());

      double inf = _calculate_influence_for_state(s);
      if (!inf.isFinite) inf = 0.5;

      if (inf <= 0.0) {
        return 1.0 / t.toDouble();
      }
      if (inf >= 1.0) {
        return -1.0 / t.toDouble();
      }
    }

    // If no terminal within cap, treat as "neutral / very slow resolution".
    return 0.0;
  }

  /// Wait = prediction from the current state (no action).
  double wait_value() {
    _requireInit();
    final s = _snapshot_state();
    return predict_outcome(s);
  }

  /// Play = prediction from state after hypothetically playing the given card.
  ///
  /// NOTE: for opponent AI, this will typically be called with opponentPerspective=true.
  double play_value(GameCard card, {bool opponentPerspective = true}) {
    _requireInit();
    final base = _snapshot_state();
    final hyp = base.copy();

    final ok = _simulate_purchase_for_state(
      hyp,
      card,
      opponentPerspective: opponentPerspective,
    );

    if (!ok) {
      // If can't play, treat as "just wait".
      return predict_outcome(base);
    }

    return predict_outcome(hyp);
  }

  /// Draw = expected play prediction across every card in opponent's deck,
  /// weighted by deck probability.
  ///
  /// (Your spec: "run a play card prediction for every card in the opponents deck
  /// and weight it by the probability associated with that card.")
  double calculate_draw_value() {
    _requireInit();

    final deck = get_opp_deck_sync();
    if (deck == null || deck.entries.isEmpty) return wait_value();

    // Snapshot once; each play simulation starts from the same current state.
    final baseState = _snapshot_state();

    double totalWeight = 0.0;
    double sum = 0.0;

    for (final e in deck.entries) {
      final w = e.probability;
      if (!w.isFinite || w <= 0) continue;

      // Build the exact card instance the opponent would draw (deck-fixed level + injected multiplier)
      final card = _buildDeckFixedCard(e, forOppDeck: true);
      if (card == null) continue;

      totalWeight += w;

      final hyp = baseState.copy();
      final ok = _simulate_purchase_for_state(hyp, card, opponentPerspective: true);

      final score = ok ? predict_outcome(hyp) : predict_outcome(baseState);
      sum += w * score;
    }

    if (totalWeight <= 0) return wait_value();
    return sum / totalWeight;
  }

  /// Returns "draw", "play", or "wait" based on which value is highest.
  /// "play" is only considered if the opponent can actually purchase the opponent card.
  String select_action() {
    _requireInit();

    final oppCard = get_opp_current_card_sync();

    final drawV = calculate_draw_value();
    final waitV = wait_value();

    double playV = -1e18;
    final canPlay = check_purchasable(oppCard, opponentPerspective: true);
    if (oppCard != null && canPlay) {
      playV = play_value(oppCard, opponentPerspective: true);
    }

    // Deterministic tie-breaking:
    // Prefer play, then draw, then wait (when values are equal).
    if (playV >= drawV && playV >= waitV) return 'play';
    if (drawV >= waitV) return 'draw';
    return 'wait';
  }

  Future<void> _run_opponent_action_if_needed({Random? rng}) async {
    if (!_inited) await init();
    _requireInit();

    rng ??= Random();

    final action = select_action();
    if (action == 'play') {
      // purchase_current_card already checks affordability again.
      await purchase_current_card(rng: rng, opponentPerspective: true);
    }
    // For now, "draw" and "wait" do not trigger any state change.
  }

  /// -------------------------------------------------------------
  /// update_tick
  /// -------------------------------------------------------------
  Future<void> update_tick(double speedMultiplier) async {
    if (!_inited) await init();
    _requireInit();

    final m = speedMultiplier.isFinite ? speedMultiplier : 1.0;
    if (m <= 0) {
      await set_last_tick_ms(DateTime.now().millisecondsSinceEpoch);
      return;
    }

    // Read old values
    final oldOppGold = get_opp_private_gold();
    final oldPlayerGold = get_player_private_gold();

    final oldSharedGold = get_shared_gold();
    final oldSharedAnti = get_shared_antimatter();
    final oldSharedComb = get_shared_combustion();
    final oldSharedDeath = get_shared_death();
    final oldSharedLife = get_shared_life();
    final oldSharedQuint = get_shared_quintessence();

    final oppGoldPs = get_opp_private_gold_per_sec();
    final playerGoldPs = get_player_private_gold_per_sec();

    final sharedGoldPs = get_shared_gold_per_sec();
    final sharedAntiPs = get_shared_antimatter_per_sec();
    final sharedCombPs = get_shared_combustion_per_sec();
    final sharedDeathPs = get_shared_death_per_sec();
    final sharedLifePs = get_shared_life_per_sec();
    final sharedQuintPs = get_shared_quintessence_per_sec();

    // Compute new values
    final newOppGold = oldOppGold + oppGoldPs * m;
    final newPlayerGold = oldPlayerGold + playerGoldPs * m;

    final newSharedGold = oldSharedGold + sharedGoldPs * m;
    final newSharedAnti = oldSharedAnti + sharedAntiPs * m;
    final newSharedComb = oldSharedComb + sharedCombPs * m;
    final newSharedDeath = oldSharedDeath + sharedDeathPs * m;
    final newSharedLife = oldSharedLife + sharedLifePs * m;
    final newSharedQuint = oldSharedQuint + sharedQuintPs * m;

    // Deltas
    final dOppGold = newOppGold - oldOppGold;
    final dPlayerGold = newPlayerGold - oldPlayerGold;

    final dSharedGold = newSharedGold - oldSharedGold;
    final dSharedAnti = newSharedAnti - oldSharedAnti;
    final dSharedComb = newSharedComb - oldSharedComb;
    final dSharedDeath = newSharedDeath - oldSharedDeath;
    final dSharedLife = newSharedLife - oldSharedLife;
    final dSharedQuint = newSharedQuint - oldSharedQuint;

    // Update totals (per your rules)
    double playerTotal = get_player_total_resources();
    double oppTotal = get_opp_total_resources();

    void applySharedDelta(double d) {
      if (!d.isFinite || d == 0) return;
      if (d > 0) {
        playerTotal += d;
      } else {
        oppTotal += (-d);
      }
    }

    applySharedDelta(dSharedGold);
    applySharedDelta(dSharedAnti);
    applySharedDelta(dSharedComb);
    applySharedDelta(dSharedDeath);
    applySharedDelta(dSharedLife);
    applySharedDelta(dSharedQuint);

    if (dPlayerGold.isFinite && dPlayerGold > 0) {
      playerTotal += dPlayerGold;
    }
    if (dOppGold.isFinite && dOppGold > 0) {
      oppTotal += dOppGold;
    }

    await _set_player_total_resources(playerTotal);
    await _set_opp_total_resources(oppTotal);

    // Persist new resource values
    await _prefs!.setDouble(_kOppPrivateGold, newOppGold);
    await _prefs!.setDouble(_kPlayerPrivateGold, newPlayerGold);

    await _prefs!.setDouble(_kSharedGold, newSharedGold);
    await _prefs!.setDouble(_kSharedAntimatter, newSharedAnti);
    await _prefs!.setDouble(_kSharedCombustion, newSharedComb);
    await _prefs!.setDouble(_kSharedDeath, newSharedDeath);
    await _prefs!.setDouble(_kSharedLife, newSharedLife);
    await _prefs!.setDouble(_kSharedQuintessence, newSharedQuint);

    await set_last_tick_ms(DateTime.now().millisecondsSinceEpoch);
    await _recompute_and_store_player_card_purchasable();

    // Opponent selects action every tick; if "play" then purchase.
    await _run_opponent_action_if_needed();

    notifyListeners();
  }

  /// -------------------------------------------------------------
  /// Card cost
  /// -------------------------------------------------------------
  int get_card_cost_sync(GameCard card) {
    final ctx = _MinimalCostContext();
    return card.cost(card, ctx);
  }

  /// -------------------------------------------------------------
  /// Perspective helpers (PERSISTED)
  /// -------------------------------------------------------------
  double _shared_persp_value_for_units(String units, {required bool opponentPerspective}) {
    double stored;
    switch (units) {
      case 'gold':
        stored = get_shared_gold();
        break;
      case 'antimatter':
        stored = get_shared_antimatter();
        break;
      case 'combustion':
        stored = get_shared_combustion();
        break;
      case 'death':
        stored = get_shared_death();
        break;
      case 'life':
        stored = get_shared_life();
        break;
      case 'quintessence':
        stored = get_shared_quintessence();
        break;
      default:
        stored = 0.0;
        break;
    }
    return opponentPerspective ? -stored : stored;
  }

  Future<void> _set_shared_persp_value_for_units(
      String units,
      double newPerspValue, {
        required bool opponentPerspective,
      }) async {
    final storedNew = opponentPerspective ? -newPerspValue : newPerspValue;
    switch (units) {
      case 'gold':
        await set_shared_gold(storedNew);
        break;
      case 'antimatter':
        await set_shared_antimatter(storedNew);
        break;
      case 'combustion':
        await set_shared_combustion(storedNew);
        break;
      case 'death':
        await set_shared_death(storedNew);
        break;
      case 'life':
        await set_shared_life(storedNew);
        break;
      case 'quintessence':
        await set_shared_quintessence(storedNew);
        break;
      default:
        break;
    }
  }

  double _shared_gold_per_sec_persp({required bool opponentPerspective}) {
    final stored = get_shared_gold_per_sec();
    return opponentPerspective ? -stored : stored;
  }

  Future<void> _set_shared_gold_per_sec_persp(
      double newPersp, {
        required bool opponentPerspective,
      }) async {
    final storedNew = opponentPerspective ? -newPersp : newPersp;
    await set_shared_gold_per_sec(storedNew);
  }

  double _private_gold_persp({required bool opponentPerspective}) {
    return opponentPerspective ? get_opp_private_gold() : get_player_private_gold();
  }

  Future<void> _set_private_gold_persp(double v, {required bool opponentPerspective}) async {
    if (opponentPerspective) {
      await set_opp_private_gold(v);
    } else {
      await set_player_private_gold(v);
    }
  }

  /// -------------------------------------------------------------
  /// Purchasability check (player/opponent) (PERSISTED)
  /// -------------------------------------------------------------
  bool check_purchasable(GameCard? card, {bool opponentPerspective = false}) {
    if (card == null) return false;

    final cost = get_card_cost_sync(card);
    if (cost <= 0) return true;

    final units = card.costUnits.toLowerCase().trim();
    final privateAvail = max(0.0, _private_gold_persp(opponentPerspective: opponentPerspective));

    if (units == 'gold') {
      final sharedAvail = max(0.0, _shared_persp_value_for_units('gold', opponentPerspective: opponentPerspective));

      if (sharedAvail >= cost) return true;
      if (privateAvail >= cost) return true;

      return (sharedAvail + privateAvail) >= cost;
    }

    final sharedAvail = max(0.0, _shared_persp_value_for_units(units, opponentPerspective: opponentPerspective));
    return sharedAvail >= cost;
  }

  bool check_purchasable_player(GameCard? card) => check_purchasable(card, opponentPerspective: false);

  Future<void> _recompute_and_store_player_card_purchasable() async {
    if (!_inited) await init();
    _requireInit();
    final card = get_player_current_card_sync();
    await _set_player_card_purchasable(check_purchasable(card, opponentPerspective: false));
  }

  /// -------------------------------------------------------------
  /// Spend helpers (PERSISTED)
  /// -------------------------------------------------------------
  Future<bool> _spend_cost_for_card({
    required int cost,
    required String units,
    required bool opponentPerspective,
  }) async {
    if (cost <= 0) return true;

    final u = units.toLowerCase().trim();

    if (u == 'gold') {
      final sharedGoldPersp = _shared_persp_value_for_units('gold', opponentPerspective: opponentPerspective);
      final privateGoldPersp = _private_gold_persp(opponentPerspective: opponentPerspective);

      final sharedAvail = max(0.0, sharedGoldPersp);
      final privateAvail = max(0.0, privateGoldPersp);

      if ((sharedAvail + privateAvail) < cost) return false;

      // Spend shared first, then private
      final useShared = min(sharedAvail, cost.toDouble());
      final remaining = cost.toDouble() - useShared;

      await _set_shared_persp_value_for_units(
        'gold',
        sharedGoldPersp - useShared,
        opponentPerspective: opponentPerspective,
      );

      if (remaining > 0) {
        await _set_private_gold_persp(
          privateGoldPersp - remaining,
          opponentPerspective: opponentPerspective,
        );
      }

      return true;
    }

    final sharedPersp = _shared_persp_value_for_units(u, opponentPerspective: opponentPerspective);
    final sharedAvail = max(0.0, sharedPersp);
    if (sharedAvail < cost) return false;

    await _set_shared_persp_value_for_units(
      u,
      sharedPersp - cost.toDouble(),
      opponentPerspective: opponentPerspective,
    );
    return true;
  }

  /// -------------------------------------------------------------
  /// Purchase (player/opponent) — multiplier updates + effect inversion
  /// -------------------------------------------------------------
  Future<bool> purchase_current_card({
    Random? rng,
    bool opponentPerspective = false,
  }) async {
    if (!_inited) await init();
    _requireInit();

    rng ??= Random();

    final card = opponentPerspective ? get_opp_current_card_sync() : get_player_current_card_sync();
    if (card == null) return false;

    if (!check_purchasable(card, opponentPerspective: opponentPerspective)) return false;

    final cost = get_card_cost_sync(card);
    final units = card.costUnits.toLowerCase().trim();

    if (cost > 0) {
      final spent = await _spend_cost_for_card(
        cost: cost,
        units: units,
        opponentPerspective: opponentPerspective,
      );
      if (!spent) {
        if (!opponentPerspective) await _recompute_and_store_player_card_purchasable();
        notifyListeners();
        return false;
      }
    }

    final id = card.cardId;
    final factor = _factor_for_card(card);

    // Update per-card multipliers (persisted)
    if (!opponentPerspective) {
      // PLAYER bought:
      final playerMul = _get_multiplier(forOppDeck: false, cardId: id);
      final oppMul = _get_multiplier(forOppDeck: true, cardId: id);

      await _set_multiplier(forOppDeck: false, cardId: id, v: playerMul * factor);
      await _set_multiplier(forOppDeck: true, cardId: id, v: oppMul / factor);
    } else {
      // OPPONENT bought:
      final oppMul = _get_multiplier(forOppDeck: true, cardId: id);
      final playerMul = _get_multiplier(forOppDeck: false, cardId: id);

      await _set_multiplier(forOppDeck: true, cardId: id, v: oppMul * factor);
      await _set_multiplier(forOppDeck: false, cardId: id, v: playerMul / factor);
    }

    // Apply effect with perspective inversion
    final ctx = _MinimalCostContext();
    ctx.setStat<double>('shared_gold_per_sec', _shared_gold_per_sec_persp(opponentPerspective: opponentPerspective));

    card.effect(ctx);

    final newSharedGoldPsPersp = ctx.getStat<double>('shared_gold_per_sec');
    await _set_shared_gold_per_sec_persp(newSharedGoldPsPersp, opponentPerspective: opponentPerspective);

    // Replace card on purchasing side (new draw injects updated multiplier)
    if (!opponentPerspective) {
      final deck = get_player_deck_sync();
      final next = (deck == null) ? null : draw_card(deck, rng: rng, forOppDeck: false);
      await set_player_current_card(next);
      await _recompute_and_store_player_card_purchasable();
    } else {
      final deck = get_opp_deck_sync();
      final next = (deck == null) ? null : draw_card(deck, rng: rng, forOppDeck: true);
      await set_opp_current_card(next);
    }

    notifyListeners();
    return true;
  }

  Future<bool> purchase_player_current_card({Random? rng}) {
    return purchase_current_card(rng: rng, opponentPerspective: false);
  }

  /// -------------------------------------------------------------
  /// Current card persistence
  /// -------------------------------------------------------------
  Future<void> set_player_current_card(GameCard? card) async {
    if (!_inited) await init();
    _requireInit();

    if (card == null) {
      await _prefs!.remove(_kPlayerCurrentCard);
      await _set_player_card_purchasable(true);
      notifyListeners();
      return;
    }

    // IMPORTANT: snapshot does NOT persist multiplier.
    await _prefs!.setString(_kPlayerCurrentCard, jsonEncode(_cardSnapshotToJson(card)));
    await _recompute_and_store_player_card_purchasable();
    notifyListeners();
  }

  Future<void> set_opp_current_card(GameCard? card) async {
    if (!_inited) await init();
    _requireInit();

    if (card == null) {
      await _prefs!.remove(_kOppCurrentCard);
      notifyListeners();
      return;
    }

    // IMPORTANT: snapshot does NOT persist multiplier.
    await _prefs!.setString(_kOppCurrentCard, jsonEncode(_cardSnapshotToJson(card)));
    notifyListeners();
  }

  GameCard? get_player_current_card_sync() {
    _requireInit();
    final raw = _prefs!.getString(_kPlayerCurrentCard);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return _cardSnapshotFromJson(decoded, forOppDeck: false);
    } catch (_) {}
    return null;
  }

  GameCard? get_opp_current_card_sync() {
    _requireInit();
    final raw = _prefs!.getString(_kOppCurrentCard);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return _cardSnapshotFromJson(decoded, forOppDeck: true);
    } catch (_) {}
    return null;
  }

  /// -------------------------------------------------------------
  /// Deck retrieval (sync)
  /// -------------------------------------------------------------
  CardDeck? get_player_deck_sync() {
    _requireInit();
    final raw = _prefs!.getString(_kPlayerDeck);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return _deckFromJson(decoded, deckIdFallback: 'battle_player');
    } catch (_) {}
    return null;
  }

  CardDeck? get_opp_deck_sync() {
    _requireInit();
    final raw = _prefs!.getString(_kOppDeck);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return _deckFromJson(decoded, deckIdFallback: 'battle_opp');
    } catch (_) {}
    return null;
  }

  /// -------------------------------------------------------------
  /// Victory + resources helpers (stored PLAYER perspective)
  /// -------------------------------------------------------------
  double get_victory_progress() {
    _requireInit();
    return _prefs!.getDouble(_kVictoryProgress) ?? 0.5;
  }

  Future<void> set_victory_progress(double v) async {
    if (!_inited) await init();
    _requireInit();
    await _prefs!.setDouble(_kVictoryProgress, v.clamp(0.0, 1.0));
    notifyListeners();
  }

  // Values
  double get_shared_gold() => _getD(_kSharedGold, 0.0);
  double get_shared_antimatter() => _getD(_kSharedAntimatter, 0.0);
  double get_shared_combustion() => _getD(_kSharedCombustion, 0.0);
  double get_shared_death() => _getD(_kSharedDeath, 0.0);
  double get_shared_life() => _getD(_kSharedLife, 0.0);
  double get_shared_quintessence() => _getD(_kSharedQuintessence, 0.0);

  double get_player_private_gold() => _getD(_kPlayerPrivateGold, 0.0);
  double get_opp_private_gold() => _getD(_kOppPrivateGold, 0.0);

  Future<void> set_shared_gold(double v) => _setD(_kSharedGold, v);
  Future<void> set_shared_antimatter(double v) => _setD(_kSharedAntimatter, v);
  Future<void> set_shared_combustion(double v) => _setD(_kSharedCombustion, v);
  Future<void> set_shared_death(double v) => _setD(_kSharedDeath, v);
  Future<void> set_shared_life(double v) => _setD(_kSharedLife, v);
  Future<void> set_shared_quintessence(double v) => _setD(_kSharedQuintessence, v);

  Future<void> set_player_private_gold(double v) => _setD(_kPlayerPrivateGold, v);
  Future<void> set_opp_private_gold(double v) => _setD(_kOppPrivateGold, v);

  // Purchasability cached
  bool get_player_card_purchasable_sync() {
    _requireInit();
    return _prefs!.getBool(_kPlayerCardPurchasable) ?? true;
  }

  Future<void> _set_player_card_purchasable(bool v) async {
    if (!_inited) await init();
    _requireInit();
    await _prefs!.setBool(_kPlayerCardPurchasable, v);
  }

  // Per-second
  double get_shared_gold_per_sec() => _getD(_kSharedGoldPerSec, 0.0);
  double get_shared_antimatter_per_sec() => _getD(_kSharedAntimatterPerSec, 0.0);
  double get_shared_combustion_per_sec() => _getD(_kSharedCombustionPerSec, 0.0);
  double get_shared_death_per_sec() => _getD(_kSharedDeathPerSec, 0.0);
  double get_shared_life_per_sec() => _getD(_kSharedLifePerSec, 0.0);
  double get_shared_quintessence_per_sec() => _getD(_kSharedQuintessencePerSec, 0.0);

  double get_player_private_gold_per_sec() => _getD(_kPlayerPrivateGoldPerSec, 0.0);
  double get_opp_private_gold_per_sec() => _getD(_kOppPrivateGoldPerSec, 0.0);

  Future<void> set_shared_gold_per_sec(double v) => _setD(_kSharedGoldPerSec, v);
  Future<void> set_shared_antimatter_per_sec(double v) => _setD(_kSharedAntimatterPerSec, v);
  Future<void> set_shared_combustion_per_sec(double v) => _setD(_kSharedCombustionPerSec, v);
  Future<void> set_shared_death_per_sec(double v) => _setD(_kSharedDeathPerSec, v);
  Future<void> set_shared_life_per_sec(double v) => _setD(_kSharedLifePerSec, v);
  Future<void> set_shared_quintessence_per_sec(double v) => _setD(_kSharedQuintessencePerSec, v);

  Future<void> set_player_private_gold_per_sec(double v) => _setD(_kPlayerPrivateGoldPerSec, v);
  Future<void> set_opp_private_gold_per_sec(double v) => _setD(_kOppPrivateGoldPerSec, v);

  double _getD(String k, double def) {
    _requireInit();
    return _prefs!.getDouble(k) ?? def;
  }

  Future<void> _setD(String k, double v) async {
    if (!_inited) await init();
    _requireInit();
    await _prefs!.setDouble(k, v);
    notifyListeners();
  }

  /// -------------------------------------------------------------
  /// Helpers: deck/card JSON
  /// -------------------------------------------------------------
  static Map<String, dynamic> _deckToJson(CardDeck deck) {
    return {
      'deckId': deck.deckId,
      'entries': deck.entries.map((e) => e.toJson()).toList(),
    };
  }

  static CardDeck _deckFromJson(Map<String, dynamic> json, {required String deckIdFallback}) {
    final deckId = (json['deckId'] as String?) ?? deckIdFallback;
    final list = json['entries'];
    final entries = <DeckCardEntry>[];

    if (list is List) {
      for (final item in list) {
        if (item is Map) {
          try {
            final entry = DeckCardEntry.fromJson(item.cast<String, dynamic>());
            if (entry.cardId.isNotEmpty) {
              entries.add(
                DeckCardEntry(
                  cardId: entry.cardId,
                  probability: entry.probability.clamp(0.0, 1.0).toDouble(),
                  level: entry.level < 1 ? 1 : entry.level,
                ),
              );
            }
          } catch (_) {}
        }
      }
    }

    return CardDeck(deckId: deckId, entries: entries);
  }

  GameCard? _buildDeckFixedCard(DeckCardEntry e, {required bool forOppDeck}) {
    final base = CardCatalog.byId(e.cardId);
    if (base == null) return null;

    final lvl = max(1, e.level);
    final step = max(1, base.evolveAt);
    final totalXpAtLevelStart = (lvl - 1) * step;

    final mul = _get_multiplier(forOppDeck: forOppDeck, cardId: base.cardId);

    return base.copyWith(
      level: lvl,
      experience: totalXpAtLevelStart,
      cardMultiplier: mul,
    );
  }

  // IMPORTANT: snapshot excludes multiplier so it can change live.
  static Map<String, dynamic> _cardSnapshotToJson(GameCard c) => {
    'cardId': c.cardId,
    'level': c.level,
    'experience': c.experience,
  };

  GameCard? _cardSnapshotFromJson(Map<String, dynamic> json, {required bool forOppDeck}) {
    final id = (json['cardId'] as String?) ?? '';
    if (id.isEmpty) return null;

    final base = CardCatalog.byId(id);
    if (base == null) return null;

    final lvl = (json['level'] as num?)?.toInt() ?? base.level;
    final xp = (json['experience'] as num?)?.toInt() ?? base.experience;

    // Always inject latest persisted multiplier for this side.
    final mul = _get_multiplier(forOppDeck: forOppDeck, cardId: id);

    return base.copyWith(
      level: lvl < 1 ? 1 : lvl,
      experience: xp < 0 ? 0 : xp,
      cardMultiplier: mul,
    );
  }

  /// =============================================================
  /// Hypothetical helpers (pure functions over BattleState)
  /// =============================================================

  BattleState _snapshot_state() {
    _requireInit();
    return BattleState(
      sharedGold: get_shared_gold(),
      sharedAntimatter: get_shared_antimatter(),
      sharedCombustion: get_shared_combustion(),
      sharedDeath: get_shared_death(),
      sharedLife: get_shared_life(),
      sharedQuintessence: get_shared_quintessence(),
      playerPrivateGold: get_player_private_gold(),
      oppPrivateGold: get_opp_private_gold(),
      sharedGoldPerSec: get_shared_gold_per_sec(),
      sharedAntimatterPerSec: get_shared_antimatter_per_sec(),
      sharedCombustionPerSec: get_shared_combustion_per_sec(),
      sharedDeathPerSec: get_shared_death_per_sec(),
      sharedLifePerSec: get_shared_life_per_sec(),
      sharedQuintessencePerSec: get_shared_quintessence_per_sec(),
      playerPrivateGoldPerSec: get_player_private_gold_per_sec(),
      oppPrivateGoldPerSec: get_opp_private_gold_per_sec(),
      playerTotalResources: get_player_total_resources(),
      oppTotalResources: get_opp_total_resources(),
    );
  }

  double _calculate_influence_for_state(BattleState s) {
    // Current values (stored PLAYER perspective)
    final sg = s.sharedGold;
    final sa = s.sharedAntimatter;
    final sc = s.sharedCombustion;
    final sd = s.sharedDeath;
    final sl = s.sharedLife;
    final sq = s.sharedQuintessence;

    final pg = s.playerPrivateGold;
    final og = s.oppPrivateGold;

    // On-hand
    final playerOnHand =
        (sg > 0 ? sg : 0.0) +
            (sa > 0 ? sa : 0.0) +
            (sc > 0 ? sc : 0.0) +
            (sd > 0 ? sd : 0.0) +
            (sl > 0 ? sl : 0.0) +
            (sq > 0 ? sq : 0.0) +
            (pg.isFinite ? pg : 0.0);

    final negSharedSum =
        (sg < 0 ? sg : 0.0) +
            (sa < 0 ? sa : 0.0) +
            (sc < 0 ? sc : 0.0) +
            (sd < 0 ? sd : 0.0) +
            (sl < 0 ? sl : 0.0) +
            (sq < 0 ? sq : 0.0);

    final oppOnHand = (og.isFinite ? og : 0.0) + negSharedSum.abs();

    // 1 hour gains (per-sec)
    final sgps = s.sharedGoldPerSec;
    final saps = s.sharedAntimatterPerSec;
    final scps = s.sharedCombustionPerSec;
    final sdps = s.sharedDeathPerSec;
    final slps = s.sharedLifePerSec;
    final sqps = s.sharedQuintessencePerSec;

    final pgps = s.playerPrivateGoldPerSec;
    final ogps = s.oppPrivateGoldPerSec;

    final playerPosPs =
        (sgps > 0 ? sgps : 0.0) +
            (saps > 0 ? saps : 0.0) +
            (scps > 0 ? scps : 0.0) +
            (sdps > 0 ? sdps : 0.0) +
            (slps > 0 ? slps : 0.0) +
            (sqps > 0 ? sqps : 0.0) +
            (pgps > 0 ? pgps : 0.0);

    final oppNegSharedPs =
        (sgps < 0 ? sgps : 0.0) +
            (saps < 0 ? saps : 0.0) +
            (scps < 0 ? scps : 0.0) +
            (sdps < 0 ? sdps : 0.0) +
            (slps < 0 ? slps : 0.0) +
            (sqps < 0 ? sqps : 0.0);

    final playerHourGains = 3600.0 * playerPosPs;
    final oppHourGains = 3600.0 * (oppNegSharedPs.abs() + (ogps > 0 ? ogps : 0.0));

    final playerTotal = s.playerTotalResources;
    final oppTotal = s.oppTotalResources;

    final denomOpp = (oppTotal + 1.0 + oppHourGains);
    final denomPlayer = (playerTotal + 1.0 + playerHourGains);

    final safeDenomOpp = denomOpp.isFinite && denomOpp > 0 ? denomOpp : 1.0;
    final safeDenomPlayer = denomPlayer.isFinite && denomPlayer > 0 ? denomPlayer : 1.0;

    final influence = 0.5 + (playerOnHand / safeDenomOpp) - (oppOnHand / safeDenomPlayer);

    if (!influence.isFinite) return 0.5;
    return influence;
  }

  void _simulate_tick_for_state(BattleState s, double dt) {
    final m = (!dt.isFinite || dt <= 0) ? 0.0 : dt;
    if (m <= 0) return;

    final oldOppGold = s.oppPrivateGold;
    final oldPlayerGold = s.playerPrivateGold;

    final oldSharedGold = s.sharedGold;
    final oldSharedAnti = s.sharedAntimatter;
    final oldSharedComb = s.sharedCombustion;
    final oldSharedDeath = s.sharedDeath;
    final oldSharedLife = s.sharedLife;
    final oldSharedQuint = s.sharedQuintessence;

    // Apply per-sec deltas
    s.oppPrivateGold = oldOppGold + s.oppPrivateGoldPerSec * m;
    s.playerPrivateGold = oldPlayerGold + s.playerPrivateGoldPerSec * m;

    s.sharedGold = oldSharedGold + s.sharedGoldPerSec * m;
    s.sharedAntimatter = oldSharedAnti + s.sharedAntimatterPerSec * m;
    s.sharedCombustion = oldSharedComb + s.sharedCombustionPerSec * m;
    s.sharedDeath = oldSharedDeath + s.sharedDeathPerSec * m;
    s.sharedLife = oldSharedLife + s.sharedLifePerSec * m;
    s.sharedQuintessence = oldSharedQuint + s.sharedQuintessencePerSec * m;

    // Deltas for totals tracking
    final dOppGold = s.oppPrivateGold - oldOppGold;
    final dPlayerGold = s.playerPrivateGold - oldPlayerGold;

    final dSharedGold = s.sharedGold - oldSharedGold;
    final dSharedAnti = s.sharedAntimatter - oldSharedAnti;
    final dSharedComb = s.sharedCombustion - oldSharedComb;
    final dSharedDeath = s.sharedDeath - oldSharedDeath;
    final dSharedLife = s.sharedLife - oldSharedLife;
    final dSharedQuint = s.sharedQuintessence - oldSharedQuint;

    void applySharedDelta(double d) {
      if (!d.isFinite || d == 0) return;
      if (d > 0) {
        s.playerTotalResources += d;
      } else {
        s.oppTotalResources += (-d);
      }
    }

    applySharedDelta(dSharedGold);
    applySharedDelta(dSharedAnti);
    applySharedDelta(dSharedComb);
    applySharedDelta(dSharedDeath);
    applySharedDelta(dSharedLife);
    applySharedDelta(dSharedQuint);

    if (dPlayerGold.isFinite && dPlayerGold > 0) s.playerTotalResources += dPlayerGold;
    if (dOppGold.isFinite && dOppGold > 0) s.oppTotalResources += dOppGold;

    if (!s.playerTotalResources.isFinite || s.playerTotalResources < 0) s.playerTotalResources = 0.0;
    if (!s.oppTotalResources.isFinite || s.oppTotalResources < 0) s.oppTotalResources = 0.0;
  }

  double _shared_persp_value_for_units_state(BattleState s, String units, {required bool opponentPerspective}) {
    double stored;
    switch (units) {
      case 'gold':
        stored = s.sharedGold;
        break;
      case 'antimatter':
        stored = s.sharedAntimatter;
        break;
      case 'combustion':
        stored = s.sharedCombustion;
        break;
      case 'death':
        stored = s.sharedDeath;
        break;
      case 'life':
        stored = s.sharedLife;
        break;
      case 'quintessence':
        stored = s.sharedQuintessence;
        break;
      default:
        stored = 0.0;
        break;
    }
    return opponentPerspective ? -stored : stored;
  }

  void _set_shared_persp_value_for_units_state(
      BattleState s,
      String units,
      double newPerspValue, {
        required bool opponentPerspective,
      }) {
    final storedNew = opponentPerspective ? -newPerspValue : newPerspValue;
    switch (units) {
      case 'gold':
        s.sharedGold = storedNew;
        break;
      case 'antimatter':
        s.sharedAntimatter = storedNew;
        break;
      case 'combustion':
        s.sharedCombustion = storedNew;
        break;
      case 'death':
        s.sharedDeath = storedNew;
        break;
      case 'life':
        s.sharedLife = storedNew;
        break;
      case 'quintessence':
        s.sharedQuintessence = storedNew;
        break;
      default:
        break;
    }
  }

  double _shared_persp_per_sec_state(BattleState s, String units, {required bool opponentPerspective}) {
    double stored;
    switch (units) {
      case 'gold':
        stored = s.sharedGoldPerSec;
        break;
      case 'antimatter':
        stored = s.sharedAntimatterPerSec;
        break;
      case 'combustion':
        stored = s.sharedCombustionPerSec;
        break;
      case 'death':
        stored = s.sharedDeathPerSec;
        break;
      case 'life':
        stored = s.sharedLifePerSec;
        break;
      case 'quintessence':
        stored = s.sharedQuintessencePerSec;
        break;
      default:
        stored = 0.0;
        break;
    }
    return opponentPerspective ? -stored : stored;
  }

  void _set_shared_persp_per_sec_state(
      BattleState s,
      String units,
      double newPerspPerSec, {
        required bool opponentPerspective,
      }) {
    final storedNew = opponentPerspective ? -newPerspPerSec : newPerspPerSec;
    switch (units) {
      case 'gold':
        s.sharedGoldPerSec = storedNew;
        break;
      case 'antimatter':
        s.sharedAntimatterPerSec = storedNew;
        break;
      case 'combustion':
        s.sharedCombustionPerSec = storedNew;
        break;
      case 'death':
        s.sharedDeathPerSec = storedNew;
        break;
      case 'life':
        s.sharedLifePerSec = storedNew;
        break;
      case 'quintessence':
        s.sharedQuintessencePerSec = storedNew;
        break;
      default:
        break;
    }
  }

  double _private_gold_state(BattleState s, {required bool opponentPerspective}) {
    return opponentPerspective ? s.oppPrivateGold : s.playerPrivateGold;
  }

  void _set_private_gold_state(BattleState s, double v, {required bool opponentPerspective}) {
    if (opponentPerspective) {
      s.oppPrivateGold = v;
    } else {
      s.playerPrivateGold = v;
    }
  }

  bool _check_purchasable_state(BattleState s, GameCard card, {required bool opponentPerspective}) {
    final cost = get_card_cost_sync(card);
    if (cost <= 0) return true;

    final units = card.costUnits.toLowerCase().trim();
    final privateAvail = max(0.0, _private_gold_state(s, opponentPerspective: opponentPerspective));

    if (units == 'gold') {
      final sharedAvail = max(0.0, _shared_persp_value_for_units_state(s, 'gold', opponentPerspective: opponentPerspective));
      return (sharedAvail + privateAvail) >= cost;
    }

    final sharedAvail = max(0.0, _shared_persp_value_for_units_state(s, units, opponentPerspective: opponentPerspective));
    return sharedAvail >= cost;
  }

  bool _spend_cost_for_card_state(
      BattleState s, {
        required int cost,
        required String units,
        required bool opponentPerspective,
      }) {
    if (cost <= 0) return true;

    final u = units.toLowerCase().trim();

    if (u == 'gold') {
      final sharedGoldPersp = _shared_persp_value_for_units_state(s, 'gold', opponentPerspective: opponentPerspective);
      final privateGoldPersp = _private_gold_state(s, opponentPerspective: opponentPerspective);

      final sharedAvail = max(0.0, sharedGoldPersp);
      final privateAvail = max(0.0, privateGoldPersp);

      if ((sharedAvail + privateAvail) < cost) return false;

      // Spend shared first, then private
      final useShared = min(sharedAvail, cost.toDouble());
      final remaining = cost.toDouble() - useShared;

      _set_shared_persp_value_for_units_state(
        s,
        'gold',
        sharedGoldPersp - useShared,
        opponentPerspective: opponentPerspective,
      );

      if (remaining > 0) {
        _set_private_gold_state(
          s,
          privateGoldPersp - remaining,
          opponentPerspective: opponentPerspective,
        );
      }

      return true;
    }

    final sharedPersp = _shared_persp_value_for_units_state(s, u, opponentPerspective: opponentPerspective);
    final sharedAvail = max(0.0, sharedPersp);
    if (sharedAvail < cost) return false;

    _set_shared_persp_value_for_units_state(
      s,
      u,
      sharedPersp - cost.toDouble(),
      opponentPerspective: opponentPerspective,
    );
    return true;
  }

  bool _simulate_purchase_for_state(
      BattleState s,
      GameCard card, {
        required bool opponentPerspective,
      }) {
    // Affordability
    if (!_check_purchasable_state(s, card, opponentPerspective: opponentPerspective)) return false;

    final cost = get_card_cost_sync(card);
    final units = card.costUnits.toLowerCase().trim();

    if (cost > 0) {
      final spent = _spend_cost_for_card_state(
        s,
        cost: cost,
        units: units,
        opponentPerspective: opponentPerspective,
      );
      if (!spent) return false;
    }

    // Apply effect with perspective inversion:
    // We provide per-sec stats to the card in "perspective space"
    // and then write back to stored PLAYER perspective.
    final ctx = _MinimalCostContext();

    // Seed all shared per-sec stats (future-proof for more card types)
    ctx.setStat<double>('shared_gold_per_sec', _shared_persp_per_sec_state(s, 'gold', opponentPerspective: opponentPerspective));
    ctx.setStat<double>('shared_antimatter_per_sec', _shared_persp_per_sec_state(s, 'antimatter', opponentPerspective: opponentPerspective));
    ctx.setStat<double>('shared_combustion_per_sec', _shared_persp_per_sec_state(s, 'combustion', opponentPerspective: opponentPerspective));
    ctx.setStat<double>('shared_death_per_sec', _shared_persp_per_sec_state(s, 'death', opponentPerspective: opponentPerspective));
    ctx.setStat<double>('shared_life_per_sec', _shared_persp_per_sec_state(s, 'life', opponentPerspective: opponentPerspective));
    ctx.setStat<double>('shared_quintessence_per_sec', _shared_persp_per_sec_state(s, 'quintessence', opponentPerspective: opponentPerspective));

    card.effect(ctx);

    // Write back any changes (if key not touched, it will read as seeded value)
    _set_shared_persp_per_sec_state(
      s,
      'gold',
      ctx.getStat<double>('shared_gold_per_sec'),
      opponentPerspective: opponentPerspective,
    );
    _set_shared_persp_per_sec_state(
      s,
      'antimatter',
      ctx.getStat<double>('shared_antimatter_per_sec'),
      opponentPerspective: opponentPerspective,
    );
    _set_shared_persp_per_sec_state(
      s,
      'combustion',
      ctx.getStat<double>('shared_combustion_per_sec'),
      opponentPerspective: opponentPerspective,
    );
    _set_shared_persp_per_sec_state(
      s,
      'death',
      ctx.getStat<double>('shared_death_per_sec'),
      opponentPerspective: opponentPerspective,
    );
    _set_shared_persp_per_sec_state(
      s,
      'life',
      ctx.getStat<double>('shared_life_per_sec'),
      opponentPerspective: opponentPerspective,
    );
    _set_shared_persp_per_sec_state(
      s,
      'quintessence',
      ctx.getStat<double>('shared_quintessence_per_sec'),
      opponentPerspective: opponentPerspective,
    );

    return true;
  }
}
