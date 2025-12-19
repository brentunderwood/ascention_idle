part of 'idle_game_screen.dart';

class _Nugget {
  final int id;
  final Offset position; // absolute position inside the play area
  final DateTime spawnTime;

  _Nugget({
    required this.id,
    required this.position,
    required this.spawnTime,
  });
}

/// Keys used for deck constraints, shared with DeckManagementTab.
const String kDeckMaxCardsKey = 'rebirth_deck_max_cards';
const String kDeckMaxCapacityKey = 'rebirth_deck_max_capacity';

/// Keys for ore-per-click coefficient persistence.
const String kGpsClickCoeffKey = 'gps_click_coeff';
const String kTotalOreClickCoeffKey = 'total_ore_click_coeff';
const String kClickMultiplicityKey = 'click_multiplicity';

/// Key for ore-per-second coefficient that converts base click into OPS.
const String kBaseClickOpsCoeffKey = 'base_click_ops_coeff';

/// NEW: Per-click transfer amount from ore/sec -> ore/click (per-mode, saved).
const String kOrePerSecondTransferKey = 'ore_per_second_transfer';

/// NEW: last time the rock was clicked (per-mode, resets on rebirth).
const String kLastRockClickTimeKey = 'last_rock_click_millis';

/// NEW: idle boost value (per-mode, resets on rebirth).
const String kIdleBoostKey = 'idle_boost';

/// NEW: time-aging mechanics (per-mode, reset on rebirth).
const String kClickAgingKey = 'click_aging';
const String kClickTimePowerKey = 'click_time_power';
const String kRpsAgingKey = 'rps_aging';
const String kRpsTimePowerKey = 'rps_time_power';
const String kGpsAgingKey = 'gps_aging';
const String kGpsTimePowerKey = 'gps_time_power';

/// NEW: bonus "tics per second" (per-mode, reset on rebirth).
/// Interpreted as "extra simulated seconds" each real second, silently.
const String kTicsPerSecondKey = 'tics_per_second';

/// Key for antimatter polynomial per-term scalars (per-mode).
const String kAntimatterPolynomialScalarsKey =
    'antimatter_polynomial_scalars';

/// Keys for click and manual-click-cycle tracking.
const String kClicksThisRunKey = 'clicks_this_run';
const String kTotalClicksKey = 'total_clicks';
const String kManualClickCyclesThisRunKey = 'manual_click_cycles_this_run';
const String kTotalManualClickCyclesKey = 'total_manual_click_cycles';
const String kMaxCardCountKey = 'max_card_count';

/// Helper: per-mode key mapping.
/// For gameMode == 'gold' -> returns [baseKey] as-is (backwards compatible).
/// For gameMode == 'antimatter' -> returns 'antimatter_<baseKey>'.
String _modeKey(String baseKey, String gameMode) {
  if (gameMode == 'antimatter') {
    return 'antimatter_$baseKey';
  }
  // default: gold
  return baseKey;
}

/// Main game state for the idle game.
///
/// Implements [IdleGameEffectTarget] so card effects can modify the
/// current run's values (ore, orePerSecond, etc.) in a controlled way.
class _IdleGameScreenState extends State<IdleGameScreen>
    with SingleTickerProviderStateMixin, IdleGameEffectTargetMixin {
  int _currentTabIndex = 0;

  /// Active game mode for the *current run*: 'gold' or 'antimatter'.
  String _gameMode = 'gold';

  double _goldOre = 0;
  double _totalGoldOre = 0;

  /// Refined gold currency (meta) – SHARED across all modes.
  double _gold = 0.0;

  /// Dark matter resource (meta) – SHARED across all modes.
  double _darkMatter = 0.0;

  /// Pending dark matter reward (accumulated every tic in antimatter mode,
  /// granted on rebirth).
  double _pendingDarkMatter = 0.0;

  double _orePerSecond = 0;
  double _bonusOrePerSecond = 0.0;
  double _baseOrePerClick = 0.0;
  double _bonusOrePerClick = 0.0;

  /// NEW: amount transferred from ore/sec -> ore/click on each rock click.
  /// Saved per-mode. Default = 0.0.
  double _orePerSecondTransfer = 0.0;

  /// NEW: idle boost value (starts at 0, reset on rebirth).
  /// Saved per-mode.
  double _idleBoost = 0.0;

  /// NEW: last time the rock was clicked (reset on rebirth).
  /// Saved per-mode so it survives app restarts within the run.
  DateTime? _lastRockClickTime;

  /// NEW: time-aging mechanics (reset on rebirth, stored per-mode).
  ///
  /// - clickTimePower increases by clickAging every second; multiplies ore/click
  /// - rpsTimePower increases by rpsAging every second; multiplies ore/sec
  /// - gpsTimePower increases by gpsAging every second; adds refined gold/sec
  double _clickAging = 0.0;
  double _clickTimePower = 1.0;

  double _rpsAging = 0.0;
  double _rpsTimePower = 1.0;

  double _gpsAging = 0.0;
  double _gpsTimePower = 0.0;

  /// NEW: bonus simulated seconds each real second (silent).
  int _ticsPerSecond = 0;

  /// Click/OPS coefficients – RESET on rebirth, stored per-mode.
  double _gpsClickCoeff = 0.0;
  double _totalOreClickCoeff = 0.0;
  double _clickMultiplicity = 1.0;
  double _baseClickOpsCoeff = 0.0;

  /// Total rebirths (meta) – SHARED across all modes.
  int _rebirthCount = 0;

  /// Total refined gold lifetime (meta) – SHARED across all modes.
  double _totalRefinedGold = 0;

  int _momentumClicks = 0;
  DateTime? _lastClickTime;

  /// Momentum upgrade parameters – RESET on rebirth, stored per-mode.
  double _momentumCap = 0.0;
  double _momentumScale = 0.0;

  /// Cached value for previewing how much will be gained on the next click.
  double _lastComputedOrePerClick = 1.0;

  /// Manual clicks on the rock (persisted, reset on rebirth).
  int _manualClickCount = 0;
  int _manualClickPower = 1;

  /// New antimatter-related state.
  ///
  /// - _antimatter: total antimatter produced in this mode (PER MODE, reset).
  /// - _antimatterPerSecond: current antimatter production rate (PER MODE, reset).
  /// - _antimatterPolynomial: polynomial coefficients a_i for i=0..n (PER MODE, reset).
  /// - _antimatterPolynomialScalars: per-term scalars s_i for i=0..n (PER MODE, reset).
  /// - _currentTicNumber: number of ticks since the last rebirth in this mode (PER MODE, reset).
  double _antimatter = 0.0;
  double _antimatterPerSecond = 0.0;
  List<int> _antimatterPolynomial = [];
  List<double> _antimatterPolynomialScalars = [];
  int _currentTicNumber = 0;

  /// New tracked stats:
  /// - manualClickCyclesThisRun: derived from manualClickCount for this rebirth (PER RUN).
  /// - totalManualClickCycles: cumulative across all time (META, SHARED).
  /// - clicksThisRun: physical rock presses this run (PER RUN).
  /// - totalClicks: physical rock presses across all time (META, SHARED).
  /// - maxCardCount: highest per-card upgrade count ever reached (META, SHARED).
  double _manualClickCyclesThisRun = 0.0;
  double _totalManualClickCycles = 0.0;
  int _clicksThisRun = 0;
  int _totalClicks = 0;
  int _maxCardCount = 0;

  /// Animation state for the rock (3D-ish tilt).
  double _rockScale = 1.0;
  double _rockTiltX = 0.0; // tilt forward/back (based on vertical tap)
  double _rockTiltY = 0.0; // tilt left/right (based on horizontal tap)

  /// Small positional offset so the rock can "drag" a bit under the finger.
  double _rockOffsetX = 0.0;
  double _rockOffsetY = 0.0;

  /// Where the initial press happened within the rock, used to compute drag delta.
  Offset? _rockPressLocalPosition;

  /// Frenzy spell state.
  ///
  /// All of these reset on rebirth and are stored per-mode.
  bool _spellFrenzyActive = false;
  DateTime? _spellFrenzyLastTriggerTime;
  double _spellFrenzyDurationSeconds = 0.0;
  double _spellFrenzyCooldownSeconds = 0.0;
  double _spellFrenzyMultiplier = 1.0;

  /// Multipliers
  ///
  /// - _rebirthMultiplier: accumulated during a run, applied to the *next* run
  ///   (run-scoped, PER MODE).
  /// - _overallMultiplier: applied to BOTH ore/sec and ore/click after all
  ///   other effects (phase, frenzy, bonuses) are computed (run-scoped).
  /// - _maxGoldMultiplier: highest rebirth gold ever earned (META, SHARED).
  /// - _achievementMultiplier: starts at 1 and increases by 0.01 per achievement,
  ///   never reset on rebirth (META, SHARED).
  double _rebirthMultiplier = 1.0;
  double _overallMultiplier = 1.0;
  double _maxGoldMultiplier = 1.0;
  double _achievementMultiplier = 1.0;

  /// Random nugget spawn chance (probability per second).
  double _randomSpawnChance = 0.0; // 0.0 by default

  /// Bonus rebirth gold accumulated from clicking nuggets this run.
  int _bonusRebirthGoldFromNuggets = 0;

  /// Nugget state: multiple nuggets allowed.
  final List<_Nugget> _nuggets = [];
  int _nextNuggetId = 0;

  /// Size of the main play area (between top stats and rebirth button).
  Size? _playAreaSize;

  /// Animation for nugget rotation.
  late final AnimationController _nuggetRotationController;

  /// RNG for spawns and bonus rolls.
  final math.Random _rng = math.Random();

  Timer? _timer;
  SharedPreferences? _prefs;
  DateTime? _lastActiveTime;

  @override
  void initState() {
    super.initState();
    _nuggetRotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _initAndStart();

    // Tutorial: show the welcome message the first time the main screen
    // is actually on screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      TutorialManager.instance.onMainScreenFirstShown(context);
    });
  }

  Future<void> _initAndStart() async {
    await PlayerCollectionRepository.instance.init();
    await _loadProgress();
    await _applyOfflineProgress();
    await _evaluateAndApplyAchievements(); // in case offline pushed thresholds
    _updatePreviewPerClick();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _nuggetRotationController.dispose();
    // Save one last time (fire-and-forget)
    _saveProgress();
    super.dispose();
  }

  /// Load the active game mode and then the per-mode state.
  Future<void> _loadProgress() async {
    _prefs ??= await SharedPreferences.getInstance();

    // Load active game mode (global).
    final storedMode = _prefs!.getString(kActiveGameModeKey);
    String resolvedMode;

    if (storedMode == 'mine_gold') {
      resolvedMode = 'gold';
    } else if (storedMode == 'create_antimatter') {
      resolvedMode = 'antimatter';
    } else if (storedMode == 'gold' || storedMode == 'antimatter') {
      resolvedMode = storedMode!;
    } else {
      resolvedMode = 'gold';
    }

    setState(() {
      _gameMode = resolvedMode;
    });

    await _loadModeSpecificProgress();
  }

  /// Helpers for reading shared (global) values, with fallback from old per-mode keys.
  double? _readGlobalDoubleWithFallback(String baseKey) {
    final direct = _prefs!.getDouble(baseKey);
    if (direct != null) return direct;
    return _prefs!.getDouble(_modeKey(baseKey, _gameMode));
  }

  int? _readGlobalIntWithFallback(String baseKey) {
    final direct = _prefs!.getInt(baseKey);
    if (direct != null) return direct;
    return _prefs!.getInt(_modeKey(baseKey, _gameMode));
  }

  /// Load all per-mode state variables for the current [_gameMode].
  /// Data that *resets on rebirth* stays per-mode; anything that survives
  /// rebirth is stored/read globally and shared between modes.
  Future<void> _loadModeSpecificProgress() async {
    _prefs ??= await SharedPreferences.getInstance();

    String mk(String baseKey) => _modeKey(baseKey, _gameMode);

    // ========= PER-MODE / PER-RUN STATE =========

    final storedGoldOre = _prefs!.getDouble(mk(kGoldOreKey));
    final storedTotalGoldOre = _prefs!.getDouble(mk(kTotalGoldOreKey));
    final storedOrePerSecond = _prefs!.getDouble(mk(kOrePerSecondKey));
    final storedBaseOrePerClick = _prefs!.getDouble(mk(kBaseOrePerClickKey));
    final storedLastActive = _prefs!.getInt(mk(kLastActiveKey));
    final storedManualClicks = _prefs!.getInt(mk(kManualClickCountKey));
    final storedManualClickPower = _prefs!.getInt(mk(kManualClickPowerKey));

    final storedFrenzyActive = _prefs!.getBool(mk(kSpellFrenzyActiveKey));
    final storedFrenzyLastTrigger =
    _prefs!.getInt(mk(kSpellFrenzyLastTriggerKey));
    final storedFrenzyDuration =
    _prefs!.getDouble(mk(kSpellFrenzyDurationKey));
    final storedFrenzyCooldown =
    _prefs!.getDouble(mk(kSpellFrenzyCooldownKey));
    final storedFrenzyMultiplier =
    _prefs!.getDouble(mk(kSpellFrenzyMultiplierKey));

    final storedMomentumCap = _prefs!.getDouble(mk(kMomentumCapKey));
    final storedMomentumScale = _prefs!.getDouble(mk(kMomentumScaleKey));

    final storedBonusOrePerSecond =
    _prefs!.getDouble(mk(kBonusOrePerSecondKey));
    final storedBonusOrePerClick =
    _prefs!.getDouble(mk(kBonusOrePerClickKey));

    final storedRebirthMultiplier =
    _prefs!.getDouble(mk(kRebirthMultiplierKey));
    final storedOverallMultiplier =
    _prefs!.getDouble(mk(kOverallMultiplierKey));

    final storedRandomSpawnChance =
    _prefs!.getDouble(mk(kRandomSpawnChanceKey));
    final storedBonusGoldFromNuggets =
    _prefs!.getInt(mk(kBonusRebirthGoldFromNuggetsKey));

    // Ore-per-click related coefficients (per-mode, reset on rebirth).
    final storedGpsClickCoeff = _prefs!.getDouble(mk(kGpsClickCoeffKey));
    final storedTotalOreClickCoeff =
    _prefs!.getDouble(mk(kTotalOreClickCoeffKey));
    final storedClickMultiplicity =
    _prefs!.getDouble(mk(kClickMultiplicityKey));

    // Ore-per-second coefficient (per-mode, reset on rebirth).
    final storedBaseClickOpsCoeff =
    _prefs!.getDouble(mk(kBaseClickOpsCoeffKey));

    // Transfer amount (per-mode).
    final storedOrePerSecondTransfer =
    _prefs!.getDouble(mk(kOrePerSecondTransferKey));

    // NEW: idle boost + last rock click time (per-mode).
    final storedIdleBoost = _prefs!.getDouble(mk(kIdleBoostKey));
    final storedLastRockClickMillis = _prefs!.getInt(mk(kLastRockClickTimeKey));

    // NEW: time-aging mechanics (per-mode).
    final storedClickAging = _prefs!.getDouble(mk(kClickAgingKey));
    final storedClickTimePower = _prefs!.getDouble(mk(kClickTimePowerKey));
    final storedRpsAging = _prefs!.getDouble(mk(kRpsAgingKey));
    final storedRpsTimePower = _prefs!.getDouble(mk(kRpsTimePowerKey));
    final storedGpsAging = _prefs!.getDouble(mk(kGpsAgingKey));
    final storedGpsTimePower = _prefs!.getDouble(mk(kGpsTimePowerKey));
    final storedTicsPerSecond = _prefs!.getInt(mk(kTicsPerSecondKey));

    // Per-run stats.
    final storedClicksThisRun = _prefs!.getInt(mk(kClicksThisRunKey));
    final storedManualClickCyclesThisRun =
    _prefs!.getDouble(mk(kManualClickCyclesThisRunKey));

    // Per-mode antimatter run state.
    final storedAntimatter = _prefs!.getDouble(mk(kAntimatterKey));
    final storedAntimatterPerSecond =
    _prefs!.getDouble(mk(kAntimatterPerSecondKey));
    final storedPolyString = _prefs!.getString(mk(kAntimatterPolynomialKey));
    final storedPolyScalarsString =
    _prefs!.getString(mk(kAntimatterPolynomialScalarsKey));
    final storedCurrentTic = _prefs!.getInt(mk(kCurrentTicNumberKey));

    // ========= SHARED (GLOBAL) META STATE =========

    final storedGold = _readGlobalDoubleWithFallback(kGoldKey);
    final storedTotalRefinedGold =
    _readGlobalDoubleWithFallback(kTotalRefinedGoldKey);
    final storedRebirthCount = _readGlobalIntWithFallback(kRebirthCountKey);

    final storedMaxGoldMultiplier =
    _readGlobalDoubleWithFallback(kMaxGoldMultiplierKey);

    final storedAchievementMultiplier =
    _readGlobalDoubleWithFallback(kAchievementMultiplierKey);

    final storedTotalClicks = _readGlobalIntWithFallback(kTotalClicksKey);
    final storedTotalManualClickCycles =
    _readGlobalDoubleWithFallback(kTotalManualClickCyclesKey);
    final storedMaxCardCount = _readGlobalIntWithFallback(kMaxCardCountKey);

    final storedDarkMatter = _readGlobalDoubleWithFallback(kDarkMatterKey);
    final storedPendingDarkMatter =
    _readGlobalDoubleWithFallback(kPendingDarkMatterKey);

    List<int> poly = [];
    if (storedPolyString != null && storedPolyString.isNotEmpty) {
      try {
        final decoded = jsonDecode(storedPolyString) as List<dynamic>;
        poly = decoded.map((e) => (e as num).toInt()).toList();
      } catch (_) {
        poly = [];
      }
    }

    List<double> polyScalars = [];
    if (storedPolyScalarsString != null &&
        storedPolyScalarsString.isNotEmpty) {
      try {
        final decodedScalars =
        jsonDecode(storedPolyScalarsString) as List<dynamic>;
        polyScalars =
            decodedScalars.map((e) => (e as num).toDouble()).toList();
      } catch (_) {
        polyScalars = [];
      }
    }

    // Ensure scalars length matches polynomial length; default scalar = 1.0.
    if (polyScalars.length < poly.length) {
      polyScalars.addAll(
        List<double>.filled(poly.length - polyScalars.length, 1.0),
      );
    } else if (polyScalars.length > poly.length) {
      polyScalars = polyScalars.sublist(0, poly.length);
    }

    setState(() {
      // ========= PER-MODE / PER-RUN =========
      _goldOre = storedGoldOre ?? 0;
      _totalGoldOre = storedTotalGoldOre ?? 0;

      _orePerSecond = storedOrePerSecond ?? 0;
      // Ensure that in antimatter mode, gold ore per second starts at least at 1.
      if (_gameMode == 'antimatter' && _orePerSecond < 1.0) {
        _orePerSecond = 1.0;
      }

      _baseOrePerClick = storedBaseOrePerClick ?? 0.0;

      _orePerSecondTransfer = storedOrePerSecondTransfer ?? 0.0;

      _idleBoost = storedIdleBoost ?? 0.0;
      _lastRockClickTime = storedLastRockClickMillis != null
          ? DateTime.fromMillisecondsSinceEpoch(storedLastRockClickMillis)
          : null;

      // NEW: time-aging mechanics defaults.
      _clickAging = storedClickAging ?? 0.0;
      _clickTimePower = math.max(1.0, storedClickTimePower ?? 1.0);

      _rpsAging = storedRpsAging ?? 0.0;
      _rpsTimePower = math.max(1.0, storedRpsTimePower ?? 1.0);

      _gpsAging = storedGpsAging ?? 0.0;
      _gpsTimePower = math.max(0.0, storedGpsTimePower ?? 0.0);

      _ticsPerSecond = math.max(0, storedTicsPerSecond ?? 0);

      _rebirthMultiplier = storedRebirthMultiplier ?? 1.0;
      _overallMultiplier = math.max(1.0, storedOverallMultiplier ?? 1.0);

      _manualClickCount = storedManualClicks ?? 0;
      _manualClickPower = storedManualClickPower ?? 1;
      _lastActiveTime = storedLastActive != null
          ? DateTime.fromMillisecondsSinceEpoch(storedLastActive)
          : null;

      _spellFrenzyActive = storedFrenzyActive ?? false;
      _spellFrenzyDurationSeconds = storedFrenzyDuration ?? 0.0;
      _spellFrenzyCooldownSeconds = storedFrenzyCooldown ?? 0.0;
      _spellFrenzyMultiplier = storedFrenzyMultiplier ?? 1.0;
      _spellFrenzyLastTriggerTime = storedFrenzyLastTrigger != null
          ? DateTime.fromMillisecondsSinceEpoch(storedFrenzyLastTrigger)
          : null;

      _momentumCap = storedMomentumCap ?? 0.0;
      _momentumScale = storedMomentumScale ?? 0.0;

      _bonusOrePerSecond = storedBonusOrePerSecond ?? 0.0;
      _bonusOrePerClick = storedBonusOrePerClick ?? 0.0;

      _randomSpawnChance = storedRandomSpawnChance ?? 0.0;
      _bonusRebirthGoldFromNuggets = storedBonusGoldFromNuggets ?? 0;

      _gpsClickCoeff = storedGpsClickCoeff ?? 0.0;
      _totalOreClickCoeff = storedTotalOreClickCoeff ?? 0.0;
      _clickMultiplicity = storedClickMultiplicity ?? 1.0;
      _baseClickOpsCoeff = storedBaseClickOpsCoeff ?? 0.0;

      _clicksThisRun = storedClicksThisRun ?? 0;
      _manualClickCyclesThisRun = storedManualClickCyclesThisRun ?? 0.0;

      _antimatter = storedAntimatter ?? 0.0;
      _antimatterPerSecond = storedAntimatterPerSecond ?? 0.0;
      _antimatterPolynomial = poly;
      _antimatterPolynomialScalars = polyScalars;
      _currentTicNumber = storedCurrentTic ?? 0;

      // ========= SHARED META =========
      _gold = storedGold ?? 0.0;
      _totalRefinedGold = storedTotalRefinedGold ?? 0.0;
      _rebirthCount = storedRebirthCount ?? 0;
      _maxGoldMultiplier = storedMaxGoldMultiplier ?? 1.0;
      _achievementMultiplier = storedAchievementMultiplier ?? 1.0;
      _totalClicks = storedTotalClicks ?? 0;
      _totalManualClickCycles = storedTotalManualClickCycles ?? 0.0;
      _maxCardCount = storedMaxCardCount ?? 0;
      _darkMatter = storedDarkMatter ?? 0.0;
      _pendingDarkMatter = storedPendingDarkMatter ?? 0.0;
    });
  }

  Future<void> _saveProgress() async {
    _prefs ??= await SharedPreferences.getInstance();
    _lastActiveTime = DateTime.now();

    String mk(String baseKey) => _modeKey(baseKey, _gameMode);

    // ========= PER-MODE / PER-RUN =========
    await _prefs!.setDouble(mk(kGoldOreKey), _goldOre);
    await _prefs!.setDouble(mk(kTotalGoldOreKey), _totalGoldOre);
    await _prefs!.setDouble(mk(kOrePerSecondKey), _orePerSecond);
    await _prefs!.setDouble(mk(kBaseOrePerClickKey), _baseOrePerClick);

    await _prefs!.setDouble(mk(kOrePerSecondTransferKey), _orePerSecondTransfer);

    await _prefs!.setDouble(mk(kIdleBoostKey), _idleBoost);
    if (_lastRockClickTime != null) {
      await _prefs!.setInt(
        mk(kLastRockClickTimeKey),
        _lastRockClickTime!.millisecondsSinceEpoch,
      );
    } else {
      await _prefs!.remove(mk(kLastRockClickTimeKey));
    }

    // NEW: time-aging mechanics (per-mode).
    await _prefs!.setDouble(mk(kClickAgingKey), _clickAging);
    await _prefs!.setDouble(mk(kClickTimePowerKey), _clickTimePower);
    await _prefs!.setDouble(mk(kRpsAgingKey), _rpsAging);
    await _prefs!.setDouble(mk(kRpsTimePowerKey), _rpsTimePower);
    await _prefs!.setDouble(mk(kGpsAgingKey), _gpsAging);
    await _prefs!.setDouble(mk(kGpsTimePowerKey), _gpsTimePower);
    await _prefs!.setInt(mk(kTicsPerSecondKey), _ticsPerSecond);

    await _prefs!.setInt(mk(kManualClickCountKey), _manualClickCount);
    await _prefs!.setInt(mk(kManualClickPowerKey), _manualClickPower);
    await _prefs!.setInt(
      mk(kLastActiveKey),
      _lastActiveTime!.millisecondsSinceEpoch,
    );

    await _prefs!.setBool(mk(kSpellFrenzyActiveKey), _spellFrenzyActive);
    await _prefs!.setDouble(
        mk(kSpellFrenzyDurationKey), _spellFrenzyDurationSeconds);
    await _prefs!.setDouble(
        mk(kSpellFrenzyCooldownKey), _spellFrenzyCooldownSeconds);
    await _prefs!.setDouble(
        mk(kSpellFrenzyMultiplierKey), _spellFrenzyMultiplier);

    if (_spellFrenzyLastTriggerTime != null) {
      await _prefs!.setInt(
        mk(kSpellFrenzyLastTriggerKey),
        _spellFrenzyLastTriggerTime!.millisecondsSinceEpoch,
      );
    } else {
      await _prefs!.remove(mk(kSpellFrenzyLastTriggerKey));
    }

    await _prefs!.setDouble(mk(kMomentumCapKey), _momentumCap);
    await _prefs!.setDouble(mk(kMomentumScaleKey), _momentumScale);

    await _prefs!.setDouble(mk(kBonusOrePerSecondKey), _bonusOrePerSecond);
    await _prefs!.setDouble(mk(kBonusOrePerClickKey), _bonusOrePerClick);

    await _prefs!.setDouble(mk(kRebirthMultiplierKey), _rebirthMultiplier);
    await _prefs!.setDouble(mk(kOverallMultiplierKey), _overallMultiplier);

    await _prefs!.setDouble(mk(kRandomSpawnChanceKey), _randomSpawnChance);
    await _prefs!.setInt(
      mk(kBonusRebirthGoldFromNuggetsKey),
      _bonusRebirthGoldFromNuggets,
    );

    // Ore-per-click related coefficients (per-mode).
    await _prefs!.setDouble(mk(kGpsClickCoeffKey), _gpsClickCoeff);
    await _prefs!.setDouble(mk(kTotalOreClickCoeffKey), _totalOreClickCoeff);
    await _prefs!.setDouble(mk(kClickMultiplicityKey), _clickMultiplicity);

    // Ore-per-second coefficient (per-mode).
    await _prefs!.setDouble(mk(kBaseClickOpsCoeffKey), _baseClickOpsCoeff);

    // Per-run stats.
    await _prefs!.setInt(mk(kClicksThisRunKey), _clicksThisRun);
    await _prefs!.setDouble(
        mk(kManualClickCyclesThisRunKey), _manualClickCyclesThisRun);

    // Per-mode antimatter run state.
    await _prefs!.setDouble(mk(kAntimatterKey), _antimatter);
    await _prefs!.setDouble(mk(kAntimatterPerSecondKey), _antimatterPerSecond);
    await _prefs!.setString(
      mk(kAntimatterPolynomialKey),
      jsonEncode(_antimatterPolynomial),
    );
    await _prefs!.setString(
      mk(kAntimatterPolynomialScalarsKey),
      jsonEncode(_antimatterPolynomialScalars),
    );
    await _prefs!.setInt(mk(kCurrentTicNumberKey), _currentTicNumber);

    // ========= SHARED META =========
    await _prefs!.setDouble(kGoldKey, _gold);
    await _prefs!.setDouble(kTotalRefinedGoldKey, _totalRefinedGold);
    await _prefs!.setInt(kRebirthCountKey, _rebirthCount);

    await _prefs!.setDouble(kMaxGoldMultiplierKey, _maxGoldMultiplier);
    await _prefs!.setDouble(kAchievementMultiplierKey, _achievementMultiplier);

    await _prefs!.setInt(kTotalClicksKey, _totalClicks);
    await _prefs!.setDouble(
        kTotalManualClickCyclesKey, _totalManualClickCycles);
    await _prefs!.setInt(kMaxCardCountKey, _maxCardCount);

    // Dark matter (global).
    await _prefs!.setDouble(kDarkMatterKey, _darkMatter);
    await _prefs!.setDouble(kPendingDarkMatterKey, _pendingDarkMatter);

    // Also store the active mode globally.
    await _prefs!.setString(kActiveGameModeKey, _gameMode);
  }

  /// Return the prefs key for the stored level of a given achievement.
  String _achievementLevelKey(String id) => 'achievement_${id}_level';

  /// Return the prefs key for the stored last progress of a given achievement.
  String _achievementProgressKey(String id) => 'achievement_${id}_progress';

  Future<void> _applyAchievementRewards() async {
    _prefs ??= await SharedPreferences.getInstance();

    int maxCards = _prefs!.getInt(kDeckMaxCardsKey) ?? 1;
    int maxCapacity = _prefs!.getInt(kDeckMaxCapacityKey) ?? 1;

    maxCapacity += 1;

    if (math.pow(maxCards + 1, 2) <= maxCapacity && maxCards < 100) {
      maxCards += 1;
    }

    await _prefs!.setInt(kDeckMaxCardsKey, maxCards);
    await _prefs!.setInt(kDeckMaxCapacityKey, maxCapacity);

    setState(() {
      _achievementMultiplier += 0.01;
    });
    await _prefs!.setDouble(kAchievementMultiplierKey, _achievementMultiplier);
  }

  Future<void> _evaluateAndApplyAchievements() async {
    _prefs ??= await SharedPreferences.getInstance();

    for (final def in kAchievementCatalog) {
      final double progress = def.progressFn(this);

      final String levelKey = _achievementLevelKey(def.id);
      final String progressKey = _achievementProgressKey(def.id);

      int level = _prefs!.getInt(levelKey) ?? 0;

      await _prefs!.setDouble(progressKey, progress);

      if (def.unique) {
        final double target = def.baseTarget;

        if (level == 0 && progress >= target) {
          level = 1;
          await _applyAchievementRewards();
          await _prefs!.setInt(levelKey, level);
        }
        continue;
      }

      double target = achievementTargetForLevel(def, level);
      bool leveled = false;

      while (progress >= target) {
        level += 1;
        leveled = true;
        await _applyAchievementRewards();
        target = achievementTargetForLevel(def, level);
      }

      if (leveled) {
        await _prefs!.setInt(levelKey, level);
      }
    }
  }

  Future<void> _changeGameMode(String newMode) async {
    if (newMode != 'gold' && newMode != 'antimatter') return;
    if (newMode == _gameMode) return;

    _prefs ??= await SharedPreferences.getInstance();

    await _saveProgress();

    setState(() {
      _gameMode = newMode;
      _lastActiveTime = null;
    });
    await _prefs!.setString(kActiveGameModeKey, _gameMode);

    await _loadModeSpecificProgress();
    await _applyOfflineProgress();

    _updatePreviewPerClick();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      _prefs ??= await SharedPreferences.getInstance();

      final storedSelected = _prefs!.getString(kNextRunSelectedKey);
      String nextMode;
      if (storedSelected == 'mine_gold') {
        nextMode = 'gold';
      } else if (storedSelected == 'create_antimatter') {
        nextMode = 'antimatter';
      } else if (storedSelected == 'antimatter' || storedSelected == 'gold') {
        nextMode = storedSelected!;
      } else {
        nextMode = _gameMode;
      }

      if (nextMode != _gameMode) {
        await _changeGameMode(nextMode);
      }

      final now = DateTime.now();

      bool momentumChanged = false;
      if (_lastClickTime != null &&
          now.difference(_lastClickTime!) > const Duration(seconds: 10) &&
          _momentumClicks != 0) {
        setState(() {
          _momentumClicks = 0;
        });
        momentumChanged = true;
      }

      // Apply per-second aging BEFORE generating this second's resources.
      setState(() {
        _clickTimePower = math.max(1.0, _clickTimePower + _clickAging);
        _rpsTimePower = math.max(1.0, _rpsTimePower + _rpsAging);
        _gpsTimePower = math.max(0.0, _gpsTimePower + _gpsAging);

        // GPS: add refined gold (spendable) each second; does NOT affect rebirth.
        if (_gpsTimePower > 0) {
          _gold += _gpsTimePower;
        }
      });

      final double effectiveOrePerSecond = _computeOrePerSecond();

      setState(() {
        _goldOre += effectiveOrePerSecond;
        _totalGoldOre += effectiveOrePerSecond;

        _currentTicNumber += 1;

        if (_gameMode == 'antimatter') {
          _antimatter += _antimatterPerSecond;

          final double delta = _evaluateAntimatterPolynomial();
          _antimatterPerSecond = delta;

          _pendingDarkMatter +=
              factorialConversion(_antimatter) / math.pow(10, 10);
        }
      });

      TutorialManager.instance
          .onGoldOreChanged(context, _manualClickCount.toDouble());

      _tickNugget();

      if (momentumChanged) {
        _updatePreviewPerClick();
      }

      // BONUS "tics per second": silently simulate extra seconds each real second.
      if (_ticsPerSecond > 0) {
        await _applyOfflineProgress(
          secondsOverride: _ticsPerSecond,
          showNotification: false,
        );
      }

      await _evaluateAndApplyAchievements();

      _saveProgress();
    });
  }

  void _tickNugget() {
    final now = DateTime.now();
    bool changed = false;

    if (_nuggets.isNotEmpty) {
      final before = _nuggets.length;
      _nuggets.removeWhere(
            (n) => now.difference(n.spawnTime).inSeconds >= 10,
      );
      if (_nuggets.length != before) {
        changed = true;
      }
    }

    if (_randomSpawnChance > 0 && _playAreaSize != null) {
      final double p = _randomSpawnChance.clamp(0.0, 1.0);
      if (_rng.nextDouble() < p) {
        const double nuggetSize = 64.0;
        final width = _playAreaSize!.width;
        final height = _playAreaSize!.height;

        if (width > nuggetSize && height > nuggetSize) {
          final double x = _rng.nextDouble() * (width - nuggetSize);
          final double y = _rng.nextDouble() * (height - nuggetSize);
          _nuggets.add(
            _Nugget(
              id: _nextNuggetId++,
              position: Offset(x, y),
              spawnTime: now,
            ),
          );
          changed = true;
        }
      }
    }

    if (changed) {
      setState(() {});
    }
  }

  double _computeManualClickCyclesFromClicks(int manualClicks) {
    const double scaling_factor = 1.1;
    if (manualClicks < 100) {
      return 0.0;
    }

    double manualClickCycles =
        math.log(manualClicks * (scaling_factor - 1) / 100 + 1) /
            math.log(scaling_factor);
    manualClickCycles = manualClickCycles.floor().toDouble();
    manualClickCycles = manualClickCycles * (manualClickCycles + 1) / 2.0;

    return manualClickCycles;
  }

  // Sum of discrete arithmetic series:
  // P1 = P0 + a*1, P2 = P0 + a*2, ... Pn = P0 + a*n
  // sum(Pk) for k=1..n = n*P0 + a*n(n+1)/2
  double _sumPowerOverSeconds({
    required double power0,
    required double aging,
    required int seconds,
  }) {
    if (seconds <= 0) return 0.0;
    return seconds * power0 + aging * (seconds * (seconds + 1) / 2.0);
  }

  Future<void> _applyOfflineProgress({
    int? secondsOverride,
    bool showNotification = true,
  }) async {
    final double baseCoreOps = _orePerSecond + _bonusOrePerSecond;
    final double baseClick = 1.0 + _baseOrePerClick;
    final double baseCombined = baseCoreOps + _baseClickOpsCoeff * baseClick;

    if (baseCombined <= 0) {
      await _saveProgress();
      return;
    }

    int seconds;
    Duration diff;

    if (secondsOverride != null) {
      if (secondsOverride <= 0) {
        await _saveProgress();
        return;
      }
      seconds = secondsOverride;
      diff = Duration(seconds: secondsOverride);
    } else {
      if (_lastActiveTime == null) {
        await _saveProgress();
        return;
      }

      final now = DateTime.now();
      diff = now.difference(_lastActiveTime!);
      seconds = diff.inSeconds;

      if (seconds <= 60) {
        await _saveProgress();
        return;
      }
    }

    // Apply aging effects across the offline duration (discrete per-second model).
    // We interpret "every second power increases by aging" as:
    // for each second: power += aging; then resource generation uses that second's power.
    //
    // That yields a sum of powers over N seconds:
    // sum_{k=1..N} (P0 + a*k) = N*P0 + a*N(N+1)/2
    final double clickPower0 = _clickTimePower;
    final double rpsPower0 = _rpsTimePower;
    final double gpsPower0 = _gpsTimePower;

    final double rpsPowerSum = _sumPowerOverSeconds(
      power0: rpsPower0,
      aging: _rpsAging,
      seconds: seconds,
    );

    final double gpsPowerSum = _sumPowerOverSeconds(
      power0: gpsPower0,
      aging: _gpsAging,
      seconds: seconds,
    );

    // Update the powers to their final values after "seconds" increments.
    final double finalClickPower =
    math.max(1.0, clickPower0 + _clickAging * seconds);
    final double finalRpsPower =
    math.max(1.0, rpsPower0 + _rpsAging * seconds);
    final double finalGpsPower =
    math.max(0.0, gpsPower0 + _gpsAging * seconds);

    double earned;

    // Base earned is baseCombined * overallMultiplier * rpsTimePower (per-second varying).
    if (_spellFrenzyActive &&
        _spellFrenzyLastTriggerTime != null &&
        _spellFrenzyDurationSeconds > 0) {
      final now = DateTime.now();
      final int offlineEndSec = now.millisecondsSinceEpoch ~/ 1000;
      final int offlineStartSec = offlineEndSec - seconds;

      final int frenzyStartSec =
          _spellFrenzyLastTriggerTime!.millisecondsSinceEpoch ~/ 1000;
      final int frenzyEndSec =
          frenzyStartSec + _spellFrenzyDurationSeconds.round();

      final int overlapStart = math.max(offlineStartSec, frenzyStartSec);
      final int overlapEnd = math.min(offlineEndSec, frenzyEndSec);
      final int frenzyOverlap = math.max(0, overlapEnd - overlapStart);

      final int normalSeconds = math.max(0, seconds - frenzyOverlap);

      // We need rpsPowerSum split into normal vs frenzy portions.
      // Approx: assume the first normalSeconds are "normal" and remaining are frenzyOverlap.
      // This is close enough for gameplay and avoids complex timeline slicing.
      final double normalRpsSum = _sumPowerOverSeconds(
        power0: rpsPower0,
        aging: _rpsAging,
        seconds: normalSeconds,
      );
      final double frenzyRpsSum = _sumPowerOverSeconds(
        power0: math.max(1.0, rpsPower0 + _rpsAging * normalSeconds),
        aging: _rpsAging,
        seconds: frenzyOverlap,
      );

      final double normalEarned =
          baseCombined * _overallMultiplier * normalRpsSum;
      final double frenzyEarned = baseCombined *
          _overallMultiplier *
          _spellFrenzyMultiplier *
          frenzyRpsSum;

      earned = normalEarned + frenzyEarned;
    } else {
      earned = baseCombined * _overallMultiplier * rpsPowerSum;
    }

    setState(() {
      _goldOre += earned;
      _totalGoldOre += earned;

      // GPS refined gold: add spendable refined gold; do NOT touch totalRefinedGold.
      if (gpsPowerSum > 0) {
        _gold += gpsPowerSum;
      }

      // Commit final time powers after offline.
      _clickTimePower = finalClickPower;
      _rpsTimePower = finalRpsPower;
      _gpsTimePower = finalGpsPower;
    });

    if (_gameMode == 'antimatter' && seconds > 0) {
      setState(() {
        _currentTicNumber += seconds;
        _antimatter += _antimatterPerSecond * seconds;
        _antimatterPerSecond = _evaluateAntimatterPolynomial(seconds: seconds);
        _pendingDarkMatter +=
            seconds * factorialConversion(_antimatter) / math.pow(10, 10);
      });
    } else if (seconds > 0) {
      setState(() {
        _currentTicNumber += seconds;
      });
    }

    TutorialManager.instance
        .onGoldOreChanged(context, _manualClickCount.toDouble());

    await _evaluateAndApplyAchievements();
    await _saveProgress();

    if (!showNotification) return;

    final durationText = _formatDuration(diff);

    final message = 'While you were away for $durationText,\n'
        'your miners produced ${earned.toStringAsFixed(0)} gold ore!';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      alert_user(
        context,
        message,
        title: 'Offline Progress',
      );
    });
  }

  String _formatDuration(Duration d) {
    if (d.inHours >= 1) {
      final hours = d.inHours;
      final minutes = d.inMinutes % 60;
      if (minutes > 0) {
        return '${hours}h ${minutes}m';
      }
      return '${hours}h';
    } else if (d.inMinutes >= 1) {
      final minutes = d.inMinutes;
      final seconds = d.inSeconds % 60;
      if (seconds > 0) {
        return '${minutes}m ${seconds}s';
      }
      return '${minutes}m';
    } else {
      return '${d.inSeconds}s';
    }
  }

  double _calculateRebirthGold() {
    if (_goldOre <= 0) return 0;

    double levelRaw = math.pow(_totalGoldOre, 1 / 3).floorToDouble();

    final double manualClickCycles =
    _computeManualClickCyclesFromClicks(_manualClickCount);

    _manualClickCyclesThisRun = manualClickCycles;

    return levelRaw + manualClickCycles;
  }

  Future<void> _clearCardUpgradeCounts() async {
    _prefs ??= await SharedPreferences.getInstance();
    String mk(String baseKey) => _modeKey(baseKey, _gameMode);
    await _prefs!.remove(mk(kCardUpgradeCountsKey));
  }

  Future<void> _clearUpgradeDeckSnapshot() async {
    _prefs ??= await SharedPreferences.getInstance();
    String mk(String baseKey) => _modeKey(baseKey, _gameMode);
    await _prefs!.remove(mk(kUpgradeDeckSnapshotKey));
  }

  Future<void> _attemptRebirth() async {
    final double rebirthGold = _calculateRebirthGold();
    final bool isGoldModeNow = _gameMode == 'gold';

    final double previewDarkMatterReward = _pendingDarkMatter;

    final String confirmText;
    if (isGoldModeNow) {
      confirmText =
      'Rebirth will reset your gold ore, total gold ore, and ore per second '
          'back to 0, and grant you ${rebirthGold.toStringAsFixed(0)} refined gold.\n\n'
          'Do you want to continue?';
    } else {
      confirmText =
      'Rebirth will reset your antimatter reactor (antimatter, ore, and ore per second) back to 0.\n'
          'You will NOT gain refined gold from this rebirth.\n\n'
          'In antimatter mode, the dark matter you gain on rebirth is the amount you have '
          'accumulated over time from the factorial progression.\n'
          'Right now, you will gain approximately '
          '${displayNumber(previewDarkMatterReward)} dark matter.\n\n'
          'Do you want to continue?';
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Rebirth'),
        content: Text(confirmText),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Rebirth'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    _prefs ??= await SharedPreferences.getInstance();
    final selectedModeRaw = _prefs!.getString(kNextRunSelectedKey) ?? 'gold';

    String selectedMode;
    if (selectedModeRaw == 'mine_gold') {
      selectedMode = 'gold';
    } else if (selectedModeRaw == 'create_antimatter') {
      selectedMode = 'antimatter';
    } else if (selectedModeRaw == 'antimatter' || selectedModeRaw == 'gold') {
      selectedMode = selectedModeRaw;
    } else {
      selectedMode = 'gold';
    }

    final double manualCyclesThisRun =
    _computeManualClickCyclesFromClicks(_manualClickCount);

    final bool wasGoldMode = _gameMode == 'gold';

    final double darkMatterReward = _pendingDarkMatter;

    setState(() {
      _manualClickCyclesThisRun = manualCyclesThisRun;
      _totalManualClickCycles += manualCyclesThisRun;

      _clicksThisRun = 0;

      _gameMode = selectedMode;

      if (wasGoldMode && rebirthGold > 0) {
        _gold += rebirthGold;
        _totalRefinedGold += rebirthGold;

        _rebirthCount += 1;

        final double rebirthGoldForMax = rebirthGold <= 0 ? 1.0 : rebirthGold;
        if (rebirthGoldForMax > _maxGoldMultiplier) {
          _maxGoldMultiplier = rebirthGoldForMax;
        }

        final double combined = (1 +
            _rebirthMultiplier *
            _achievementMultiplier *
            (1 + math.log(_maxGoldMultiplier) / math.log(1000)));
        _overallMultiplier = math.max(1.0, combined);
      }

      if (!wasGoldMode && darkMatterReward > 0) {
        _darkMatter += darkMatterReward;
        _pendingDarkMatter = 0.0;
      }

      _rebirthMultiplier = 1.0;

      _goldOre = 0;
      _totalGoldOre = 0;

      _orePerSecond = (_gameMode == 'antimatter') ? 1.0 : 0.0;
      _bonusOrePerSecond = 0.0;

      _baseOrePerClick = 0.0;
      _bonusOrePerClick = 0.0;
      _lastComputedOrePerClick = 1.0;

      _orePerSecondTransfer = 0.0;

      // NEW: reset idle mechanic each rebirth.
      _idleBoost = 0.0;
      _lastRockClickTime = null;

      // NEW: reset time-aging mechanics each rebirth.
      _clickAging = 0.0;
      _clickTimePower = 1.0;

      _rpsAging = 0.0;
      _rpsTimePower = 1.0;

      _gpsAging = 0.0;
      _gpsTimePower = 0.0;

      _ticsPerSecond = 0;

      _momentumClicks = 0;
      _lastClickTime = null;

      _manualClickCount = 0;
      _manualClickPower = 1;

      _nuggets.clear();
      _bonusRebirthGoldFromNuggets = 0;
      _randomSpawnChance = 0.0;

      _spellFrenzyActive = false;
      _spellFrenzyLastTriggerTime = null;
      _spellFrenzyDurationSeconds = 0.0;
      _spellFrenzyCooldownSeconds = 0.0;
      _spellFrenzyMultiplier = 1.0;

      _momentumCap = 0.0;
      _momentumScale = 0.0;

      _gpsClickCoeff = 0.0;
      _totalOreClickCoeff = 0.0;
      _clickMultiplicity = 1.0;
      _baseClickOpsCoeff = 0.0;

      _antimatter = 0.0;
      _antimatterPerSecond = 0.0;
      _antimatterPolynomial = [];
      _antimatterPolynomialScalars = [];
      _currentTicNumber = 0;
    });

    await _clearCardUpgradeCounts();
    await _clearUpgradeDeckSnapshot();

    await _saveProgress();
    _updatePreviewPerClick();

    final runGoalText = _gameMode == 'gold' ? 'Mine gold' : 'Create antimatter';

    String message;
    if (wasGoldMode) {
      message =
      'You rebirthed and gained ${rebirthGold.toStringAsFixed(0)} refined gold!\n'
          'Total rebirths: $_rebirthCount\n'
          'Total refined gold: ${_totalRefinedGold.toStringAsFixed(0)}\n'
          'Game mode: $runGoalText\n'
          'Overall multiplier for this run: x${_overallMultiplier.toStringAsFixed(2)}';
    } else {
      message =
      'You rebirthed in antimatter mode and gained '
          '${displayNumber(darkMatterReward)} dark matter.\n'
          'Total dark matter: ${displayNumber(_darkMatter)}\n'
          'Game mode: $runGoalText\n'
          'Overall multiplier for this run: x${_overallMultiplier.toStringAsFixed(2)}';
    }

    await alert_user(
      context,
      message,
      title: 'Rebirth Complete',
    );
  }

  double _computeIdleClickMultiplier({
    required DateTime now,
    DateTime? lastRockClickTimeOverride,
    double? idleBoostOverride,
  }) {
    final DateTime? last = lastRockClickTimeOverride ?? _lastRockClickTime;
    final double boost = idleBoostOverride ?? _idleBoost;

    if (last == null) return 1.0;

    final int secondsSince = now.difference(last).inSeconds;
    if (secondsSince <= 60) return 1.0;

    // Interpreting your spec as "extra multiplier grows with idle time":
    // multiplier = 1 + idle_boost * (secondsSince - 60)
    final double extra = boost * (secondsSince - 60);
    return math.max(1.0, 1.0 + extra);
  }

  /// Centralized ore-per-click calculation.
  double _computeOrePerClick({
    int? manualClicksOverride,
    DateTime? now,
    DateTime? lastRockClickTimeOverride,
    double? idleBoostOverride,
  }) {
    final int clicks = manualClicksOverride ?? _manualClickCount;

    final int phase = _computeClickPhase(clicks);
    final double phaseMult = (phase == 9) ? 10.0 : 1.0;

    final bool frenzyActiveNow = _isFrenzyCurrentlyActive();
    final double frenzyMult = frenzyActiveNow ? _spellFrenzyMultiplier : 1.0;

    final double baseTerm = 1.0 +
        _baseOrePerClick +
        _gpsClickCoeff * _orePerSecond +
        _totalOreClickCoeff * math.pow(_totalGoldOre, 0.5);

    double momentumFactor = 1.0;
    if (_momentumCap > 0 && _momentumScale > 0) {
      final double scaled = _momentumScale * _momentumClicks;
      final double clamped = scaled.clamp(0.0, _momentumCap);
      momentumFactor += clamped;
    }

    final DateTime t = now ?? DateTime.now();
    final double idleMult = _computeIdleClickMultiplier(
      now: t,
      lastRockClickTimeOverride: lastRockClickTimeOverride,
      idleBoostOverride: idleBoostOverride,
    );

    // NEW: clickTimePower multiplier applied to ore-per-click.
    final double timeMult = math.max(1.0, _clickTimePower);

    return baseTerm *
        phaseMult *
        frenzyMult *
        momentumFactor *
        _overallMultiplier *
        _clickMultiplicity *
        idleMult *
        timeMult;
  }

  double _computeOrePerSecond() {
    final double baseOrePerSecond = _orePerSecond + _bonusOrePerSecond;

    final bool frenzyActiveNow = _isFrenzyCurrentlyActive();
    final double frenzyMult = frenzyActiveNow ? _spellFrenzyMultiplier : 1.0;

    final double baseCombined =
        baseOrePerSecond + _baseClickOpsCoeff * (1.0 + _baseOrePerClick);

    // NEW: rpsTimePower multiplier applied to ore-per-second.
    final double timeMult = math.max(1.0, _rpsTimePower);

    return baseCombined * frenzyMult * _overallMultiplier * timeMult;
  }

  double _evaluateAntimatterPolynomial({int seconds = 1}) {
    if (_antimatterPolynomial.isEmpty) return 0.0;
    for (int i = 0; i < _antimatterPolynomial.length - 1; i++) {
      if (i < _antimatterPolynomial.length - 1) {
        _antimatterPolynomial[i] += (_antimatterPolynomial[i + 1] *
            _antimatterPolynomialScalars[i + 1] *
            seconds)
            .toInt();
      }
    }
    return (_antimatterPolynomial[0] * _antimatterPolynomialScalars[0])
        .toDouble();
  }

  void updateAntimatterPolynomialScalars(int degree, int coefficient) {
    if (degree < 0) return;
    if (degree >= _antimatterPolynomialScalars.length) {
      final int toAdd = degree + 1 - _antimatterPolynomialScalars.length;
      _antimatterPolynomialScalars.addAll(List<double>.filled(toAdd, 1.0));
    }
    _antimatterPolynomialScalars[degree] = coefficient.toDouble();
    if (degree >= _antimatterPolynomial.length) {
      _antimatterPolynomial.addAll(
        List<int>.filled(degree + 1 - _antimatterPolynomial.length, 1),
      );
    }
    _saveProgress();
  }

  void _updatePreviewPerClick() {
    setState(() {
      _lastComputedOrePerClick = _computeOrePerClick(
        manualClicksOverride: _manualClickCount,
        now: DateTime.now(),
      );
    });
  }

  void _applyCardUpgradeEffect(
      GameCard card,
      int cardLevel,
      int upgradesThisRun,
      ) {
    setState(() {
      card.cardEffect?.call(this, cardLevel, upgradesThisRun);

      if (upgradesThisRun > _maxCardCount) {
        _maxCardCount = upgradesThisRun;
      }
    });
    _saveProgress();
  }

  int _computeClickPhase(int manualClicks) {
    double scaling_factor = 1.1;
    if (manualClicks <= 0) return 1;

    double manualClickCycles;
    double lower_bound;
    double upper_bound;
    if (manualClicks < 100) {
      manualClickCycles = 0;
      lower_bound = 0;
      upper_bound = 100;
    } else {
      manualClickCycles =
          math.log(manualClicks * (scaling_factor - 1) / 100 + 1) /
              math.log(scaling_factor);
      manualClickCycles = manualClickCycles.floor().toDouble();
      lower_bound = 100 * (math.pow(scaling_factor, manualClickCycles) - 1) /
          (scaling_factor - 1);
      upper_bound =
          100 * (math.pow(scaling_factor, manualClickCycles + 1) - 1) /
              (scaling_factor - 1);
    }

    double progress = (manualClicks - lower_bound) / (upper_bound - lower_bound);
    int phase = (progress * 9).floor() + 1;

    return phase;
  }

  int _currentClickPhase() => _computeClickPhase(_manualClickCount);

  bool _isFrenzyCurrentlyActive() {
    if (!_spellFrenzyActive || _spellFrenzyLastTriggerTime == null) {
      return false;
    }
    final elapsedSeconds = DateTime.now()
        .difference(_spellFrenzyLastTriggerTime!)
        .inSeconds
        .toDouble();
    return elapsedSeconds >= 0 && elapsedSeconds < _spellFrenzyDurationSeconds;
  }

  double _currentOrePerClickForDisplay() {
    return _computeOrePerClick(now: DateTime.now());
  }

  void _activateFrenzy() {
    final now = DateTime.now();
    setState(() {
      _spellFrenzyLastTriggerTime = now;
    });
    _saveProgress();
  }

  void _onRockPanDown(DragDownDetails details) {
    if (_gameMode != 'gold') return;
    _handleRockPress(details.localPosition);
  }

  void _onRockPanUpdate(DragUpdateDetails details) {
    if (_gameMode != 'gold') return;
    _updateRockTiltAndOffset(details.localPosition);
  }

  void _onRockPanEnd(DragEndDetails details) {
    if (_gameMode != 'gold') return;
    _resetRockTransform();
  }

  void _onRockPanCancel() {
    if (_gameMode != 'gold') return;
    _resetRockTransform();
  }

  void _handleRockPress(Offset localPosition) {
    _rockPressLocalPosition = localPosition;

    final now = DateTime.now();

    if (_lastClickTime == null ||
        now.difference(_lastClickTime!) > const Duration(seconds: 10)) {
      _momentumClicks = 0;
    }
    _momentumClicks += 1;
    _lastClickTime = now;

    const double rockSize = 440.0;
    final double tapX = localPosition.dx.clamp(0.0, rockSize);
    final double tapY = localPosition.dy.clamp(0.0, rockSize);
    final double center = rockSize / 2;

    final double normX = (tapX - center) / center;
    final double normY = (tapY - center) / center;

    const double maxTilt = 4 * math.pi / 18;

    final double tiltX = normY * maxTilt;
    final double tiltY = -normX * maxTilt;

    final double transfer = _orePerSecondTransfer;
    final double nextOrePerSecond = math.max(0.0, _orePerSecond - transfer);
    final double nextBaseOrePerClick = _baseOrePerClick + transfer;

    final int clicksAfterThis =
        _manualClickCount + 1 * _manualClickPower * _clickMultiplicity.toInt();

    final double prevOrePerSecond = _orePerSecond;
    final double prevBaseOrePerClick = _baseOrePerClick;

    _orePerSecond = nextOrePerSecond;
    _baseOrePerClick = nextBaseOrePerClick;

    final double orePerClick = _computeOrePerClick(
      manualClicksOverride: clicksAfterThis,
      now: now,
      // Use the pre-update lastRockClickTime for the idle multiplier.
      lastRockClickTimeOverride: _lastRockClickTime,
      idleBoostOverride: _idleBoost,
    );

    _orePerSecond = prevOrePerSecond;
    _baseOrePerClick = prevBaseOrePerClick;

    setState(() {
      _rockScale = 0.9;
      _rockTiltX = tiltX;
      _rockTiltY = tiltY;

      _rockOffsetX = 0.0;
      _rockOffsetY = 0.0;

      _orePerSecond = nextOrePerSecond;
      _baseOrePerClick = nextBaseOrePerClick;

      _goldOre += orePerClick;
      _totalGoldOre += orePerClick;
      _lastComputedOrePerClick = orePerClick;
      _manualClickCount = clicksAfterThis;

      _clicksThisRun += 1;
      _totalClicks += 1;

      // NEW: update last rock click time for idle mechanic.
      _lastRockClickTime = now;
    });

    TutorialManager.instance
        .onGoldOreChanged(context, _manualClickCount.toDouble());

    _saveProgress();
  }

  void _updateRockTiltAndOffset(Offset localPosition) {
    if (_rockPressLocalPosition == null) {
      const double rockSize = 440.0;
      final double tapX = localPosition.dx.clamp(0.0, rockSize);
      final double tapY = localPosition.dy.clamp(0.0, rockSize);
      final double center = rockSize / 2;

      final double normX = (tapX - center) / center;
      final double normY = (tapY - center) / center;

      const double maxTilt = 4 * math.pi / 18;

      setState(() {
        _rockScale = 0.9;
        _rockTiltX = normY * maxTilt;
        _rockTiltY = -normX * maxTilt;
        _rockOffsetX = 0.0;
        _rockOffsetY = 0.0;
      });
      return;
    }

    const double rockSize = 440.0;
    final double tapX = localPosition.dx.clamp(0.0, rockSize);
    final double tapY = localPosition.dy.clamp(0.0, rockSize);
    final double center = rockSize / 2;

    final double normX = (tapX - center) / center;
    final double normY = (tapY - center) / center;

    const double maxTilt = 4 * math.pi / 18;

    final double tiltX = normY * maxTilt;
    final double tiltY = -normX * maxTilt;

    const double dragFactor = 0.2;
    const double maxOffset = 200.0;

    final Offset delta = localPosition - _rockPressLocalPosition!;
    double offsetX = delta.dx * dragFactor;
    double offsetY = delta.dy * dragFactor;

    offsetX = offsetX.clamp(-maxOffset, maxOffset);
    offsetY = offsetY.clamp(-maxOffset, maxOffset);

    setState(() {
      _rockScale = 0.9;
      _rockTiltX = tiltX;
      _rockTiltY = tiltY;
      _rockOffsetX = offsetX;
      _rockOffsetY = offsetY;
    });
  }

  void _resetRockTransform() {
    if (!mounted) return;
    setState(() {
      _rockScale = 1.0;
      _rockTiltX = 0.0;
      _rockTiltY = 0.0;
      _rockOffsetX = 0.0;
      _rockOffsetY = 0.0;
      _rockPressLocalPosition = null;
    });
  }

  void _onNuggetTap(int id) {
    final index = _nuggets.indexWhere((n) => n.id == id);
    if (index == -1) return;

    final double whole = _randomSpawnChance.floorToDouble();
    final double fractional = _randomSpawnChance - whole;
    int bonus = whole.toInt();
    if (fractional > 0 && _rng.nextDouble() < fractional) {
      bonus += 1;
    }

    setState(() {
      _gold += bonus;
      _nuggets.removeAt(index);
    });

    _saveProgress();
  }

  @override
  Widget build(BuildContext context) {
    return buildIdleGameScaffold(this, context);
  }
}
