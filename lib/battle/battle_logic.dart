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
  // NEW: per-side per-card multiplier persistence
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
      if (deltaMs > 0) elapsedSeconds = (deltaMs ~/ 1000).toDouble();
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

    final oppGold = get_opp_private_gold();
    final playerGold = get_player_private_gold();

    final sharedGold = get_shared_gold();
    final sharedAnti = get_shared_antimatter();
    final sharedComb = get_shared_combustion();
    final sharedDeath = get_shared_death();
    final sharedLife = get_shared_life();
    final sharedQuint = get_shared_quintessence();

    final oppGoldPs = get_opp_private_gold_per_sec();
    final playerGoldPs = get_player_private_gold_per_sec();

    final sharedGoldPs = get_shared_gold_per_sec();
    final sharedAntiPs = get_shared_antimatter_per_sec();
    final sharedCombPs = get_shared_combustion_per_sec();
    final sharedDeathPs = get_shared_death_per_sec();
    final sharedLifePs = get_shared_life_per_sec();
    final sharedQuintPs = get_shared_quintessence_per_sec();

    await _prefs!.setDouble(_kOppPrivateGold, oppGold + oppGoldPs * m);
    await _prefs!.setDouble(_kPlayerPrivateGold, playerGold + playerGoldPs * m);

    await _prefs!.setDouble(_kSharedGold, sharedGold + sharedGoldPs * m);
    await _prefs!.setDouble(_kSharedAntimatter, sharedAnti + sharedAntiPs * m);
    await _prefs!.setDouble(_kSharedCombustion, sharedComb + sharedCombPs * m);
    await _prefs!.setDouble(_kSharedDeath, sharedDeath + sharedDeathPs * m);
    await _prefs!.setDouble(_kSharedLife, sharedLife + sharedLifePs * m);
    await _prefs!.setDouble(_kSharedQuintessence, sharedQuint + sharedQuintPs * m);

    await set_last_tick_ms(DateTime.now().millisecondsSinceEpoch);
    await _recompute_and_store_player_card_purchasable();
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
  /// Perspective helpers
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
  /// Purchasability check (player/opponent)
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
  /// Spend helpers
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
}
