// ==================================
// idle_game_state.dart (UPDATED - FULL FILE)  ✅ FIXED chrono/rebirth pipeline
// ==================================
part of 'idle_game_screen.dart';

class _Nugget {
  final int id;
  final Offset position;
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

/// Per-click transfer amount from ore/sec -> ore/click (per-mode, saved).
const String kOrePerSecondTransferKey = 'ore_per_second_transfer';

/// last time the rock was clicked (per-mode, resets on rebirth).
const String kLastRockClickTimeKey = 'last_rock_click_millis';

/// idle boost value (per-mode, resets on rebirth).
const String kIdleBoostKey = 'idle_boost';

/// time-aging mechanics (per-mode, reset on rebirth).
const String kClickAgingKey = 'click_aging';
const String kClickTimePowerKey = 'click_time_power';
const String kRpsAgingKey = 'rps_aging';
const String kRpsTimePowerKey = 'rps_time_power';
const String kGpsAgingKey = 'gps_aging';
const String kGpsTimePowerKey = 'gps_time_power';

/// bonus "tics per second" (per-mode, reset on rebirth).
const String kTicsPerSecondKey = 'tics_per_second';

/// antimatter polynomial per-term scalars (per-mode).
const String kAntimatterPolynomialScalarsKey = 'antimatter_polynomial_scalars';

/// click and manual-click-cycle tracking.
const String kClicksThisRunKey = 'clicks_this_run';
const String kTotalClicksKey = 'total_clicks';
const String kManualClickCyclesThisRunKey = 'manual_click_cycles_this_run';
const String kTotalManualClickCyclesKey = 'total_manual_click_cycles';
const String kMaxCardCountKey = 'max_card_count';

/// per-mode key mapping.
/// - gold: base key
/// - antimatter: antimatter_<baseKey>
/// - monster: monster_<baseKey>
String _modeKey(String baseKey, String gameMode) {
  if (gameMode == 'antimatter') return 'antimatter_$baseKey';
  if (gameMode == 'monster') return 'monster_$baseKey';
  return baseKey;
}

class _IdleGameScreenState extends State<IdleGameScreen>
    with
        SingleTickerProviderStateMixin,
        IdleGameEffectTargetMixin,
        RockDisplayMixin,
        IdleGameGoldMixin,
        IdleGameAntimatterMixin,
        IdleGameRebirthMixin,
        IdleGameMonsterMixin {
  int _currentTabIndex = 0;

  /// Active game mode for the current run: 'gold', 'antimatter', or 'monster'.
  String _gameMode = 'gold';

  // ======================
  // GOLD/ANTIMATTER STATE
  // ======================
  double _goldOre = 0;
  double _totalGoldOre = 0;

  /// Refined gold currency (meta) – SHARED across all modes.
  double _gold = 0.0;

  /// Dark matter resource (meta) – SHARED across all modes.
  double _darkMatter = 0.0;

  /// Pending dark matter reward (granted on rebirth).
  double _pendingDarkMatter = 0.0;

  double _orePerSecond = 0;
  double _bonusOrePerSecond = 0.0;
  double _baseOrePerClick = 0.0;
  double _bonusOrePerClick = 0.0;

  double _orePerSecondTransfer = 0.0;

  double _idleBoost = 0.0;
  DateTime? _lastRockClickTime;

  double _clickAging = 0.0;
  double _clickTimePower = 1.0;

  double _rpsAging = 0.0;
  double _rpsTimePower = 1.0;

  double _gpsAging = 0.0;
  double _gpsTimePower = 0.0;

  int _ticsPerSecond = 0;

  double _gpsClickCoeff = 0.0;
  double _totalOreClickCoeff = 0.0;
  double _clickMultiplicity = 1.0;
  double _baseClickOpsCoeff = 0.0;

  int _rebirthCount = 0;
  double _totalRefinedGold = 0;

  int _momentumClicks = 0;
  DateTime? _lastClickTime;

  double _momentumCap = 0.0;
  double _momentumScale = 0.0;

  double _lastComputedOrePerClick = 1.0;

  int _manualClickCount = 0;
  int _manualClickPower = 1;

  double _antimatter = 0.0;
  double _antimatterPerSecond = 0.0;
  List<int> _antimatterPolynomial = [];
  List<double> _antimatterPolynomialScalars = [];
  int _currentTicNumber = 0;

  double _manualClickCyclesThisRun = 0.0;
  double _totalManualClickCycles = 0.0;
  int _clicksThisRun = 0;
  int _totalClicks = 0;
  int _maxCardCount = 0;

  bool _spellFrenzyActive = false;
  DateTime? _spellFrenzyLastTriggerTime;
  double _spellFrenzyDurationSeconds = 0.0;
  double _spellFrenzyCooldownSeconds = 0.0;
  double _spellFrenzyMultiplier = 1.0;

  /// ✅ Per-run (earned this run) multiplier.
  /// This should NOT affect ore production directly.
  double _rebirthMultiplier = 1.0;

  /// ✅ Carry-over multiplier applied to ore production (next run).
  /// This SHOULD affect ore production (gold code uses it).
  double _chronoStepPMultiplier = 1.0;

  /// ✅ Renamed: maxGoldMultiplier -> maxSingleRunGold
  /// This is global (NOT mode-dependent).
  double _maxSingleRunGold = 1.0;

  /// Achievement multiplier is global (NOT mode-dependent).
  double _achievementMultiplier = 1.0;

  double _randomSpawnChance = 0.0;
  int _bonusRebirthGoldFromNuggets = 0;

  final List<_Nugget> _nuggets = [];
  int _nextNuggetId = 0;
  Size? _playAreaSize;

  late final AnimationController _nuggetRotationController;
  final math.Random _rng = math.Random();

  Timer? _timer;
  SharedPreferences? _prefs;
  DateTime? _lastActiveTime;

  // ======================
  // MONSTER MODE STATE
  // ======================
  int _monsterPlayerLevel = 1;

  /// Player RAGE (stored under the "range" key for compatibility).
  double _monsterPlayerRage = 1.0;

  /// Player attack (see monster rules). We keep it int.
  int _monsterPlayerAttack = 1;

  int _monsterPlayerExperience = 0;

  /// Selected combat tactic: "head", "body", "hyde", "aura"
  String _monsterAttackMode = 'head';

  String _monsterClassRaw = '';
  int _monsterRarity = 1;
  int _monsterLevel = 1;
  int _monsterStatPoints = 0;

  double _monsterBaseHp = 0.0;
  double _monsterBaseDef = 0.0;
  double _monsterBaseRegen = 0.0;
  double _monsterBaseAura = 0.0;

  double _monsterCurrentHp = 0.0;
  double _monsterCurrentDef = 0.0;
  double _monsterCurrentRegen = 0.0;
  double _monsterCurrentAura = 0.0;

  int _monsterKillCount = 0;

  String _monsterName = '';
  String _monsterImagePath = '';

  @override
  void initState() {
    super.initState();
    _nuggetRotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _initAndStart();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      TutorialManager.instance.onMainScreenFirstShown(context);
    });
  }

  Future<void> _initAndStart() async {
    await PlayerCollectionRepository.instance.init();
    await _loadProgress();

    // Monster mode doesn't use offline ore production logic; keep it simple.
    if (_gameMode != 'monster') {
      await _applyOfflineProgress();
    } else {
      ensureMonsterInitialized();
      await _saveProgress();
    }

    await _evaluateAndApplyAchievements();
    _updatePreviewPerClick();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _nuggetRotationController.dispose();
    _saveProgress();
    super.dispose();
  }

  Future<void> _loadProgress() async {
    _prefs ??= await SharedPreferences.getInstance();

    final storedMode = _prefs!.getString(kActiveGameModeKey);
    String resolvedMode;

    if (storedMode == 'mine_gold') {
      resolvedMode = 'gold';
    } else if (storedMode == 'create_antimatter') {
      resolvedMode = 'antimatter';
    } else if (storedMode == 'monster' || storedMode == 'monster_hunting') {
      resolvedMode = 'monster';
    } else if (storedMode == 'gold' ||
        storedMode == 'antimatter' ||
        storedMode == 'monster') {
      resolvedMode = storedMode!;
    } else {
      resolvedMode = 'gold';
    }

    setState(() {
      _gameMode = resolvedMode;
    });

    await _loadModeSpecificProgress();
  }

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

  Future<void> _loadModeSpecificProgress() async {
    _prefs ??= await SharedPreferences.getInstance();

    String mk(String baseKey) => _modeKey(baseKey, _gameMode);

    // ✅ Monster keys should ALWAYS be stored under monster_... regardless of current _gameMode.
    String mkMonster(String baseKey) => _modeKey(baseKey, 'monster');

    // Back-compat helpers: try monster_ key first, then current-mode key, then raw base.
    int? readMonsterInt(String baseKey) =>
        _prefs!.getInt(mkMonster(baseKey)) ??
            _prefs!.getInt(mk(baseKey)) ??
            _prefs!.getInt(baseKey);

    double? readMonsterDouble(String baseKey) =>
        _prefs!.getDouble(mkMonster(baseKey)) ??
            _prefs!.getDouble(mk(baseKey)) ??
            _prefs!.getDouble(baseKey);

    String? readMonsterString(String baseKey) =>
        _prefs!.getString(mkMonster(baseKey)) ??
            _prefs!.getString(mk(baseKey)) ??
            _prefs!.getString(baseKey);

    // ========= PER-MODE =========
    final storedGoldOre = _prefs!.getDouble(mk(kGoldOreKey));
    final storedTotalGoldOre = _prefs!.getDouble(mk(kTotalGoldOreKey));
    final storedOrePerSecond = _prefs!.getDouble(mk(kOrePerSecondKey));
    final storedBaseOrePerClick = _prefs!.getDouble(mk(kBaseOrePerClickKey));
    final storedLastActive = _prefs!.getInt(mk(kLastActiveKey));
    final storedManualClicks = _prefs!.getInt(mk(kManualClickCountKey));
    final storedManualClickPower = _prefs!.getInt(mk(kManualClickPowerKey));

    final storedFrenzyActive = _prefs!.getBool(mk(kSpellFrenzyActiveKey));
    final storedFrenzyLastTrigger = _prefs!.getInt(mk(kSpellFrenzyLastTriggerKey));
    final storedFrenzyDuration = _prefs!.getDouble(mk(kSpellFrenzyDurationKey));
    final storedFrenzyCooldown = _prefs!.getDouble(mk(kSpellFrenzyCooldownKey));
    final storedFrenzyMultiplier = _prefs!.getDouble(mk(kSpellFrenzyMultiplierKey));

    final storedMomentumCap = _prefs!.getDouble(mk(kMomentumCapKey));
    final storedMomentumScale = _prefs!.getDouble(mk(kMomentumScaleKey));

    final storedBonusOrePerSecond = _prefs!.getDouble(mk(kBonusOrePerSecondKey));
    final storedBonusOrePerClick = _prefs!.getDouble(mk(kBonusOrePerClickKey));

    // ✅ IMPORTANT: these are distinct and must NOT be mirrored on load.
    final storedRebirthMultiplier = _prefs!.getDouble(mk(kRebirthMultiplierKey));
    final storedChronoStepP = _prefs!.getDouble(mk(kOverallMultiplierKey));

    final storedRandomSpawnChance = _prefs!.getDouble(mk(kRandomSpawnChanceKey));
    final storedBonusGoldFromNuggets = _prefs!.getInt(mk(kBonusRebirthGoldFromNuggetsKey));

    final storedGpsClickCoeff = _prefs!.getDouble(mk(kGpsClickCoeffKey));
    final storedTotalOreClickCoeff = _prefs!.getDouble(mk(kTotalOreClickCoeffKey));
    final storedClickMultiplicity = _prefs!.getDouble(mk(kClickMultiplicityKey));
    final storedBaseClickOpsCoeff = _prefs!.getDouble(mk(kBaseClickOpsCoeffKey));

    final storedOrePerSecondTransfer = _prefs!.getDouble(mk(kOrePerSecondTransferKey));

    final storedIdleBoost = _prefs!.getDouble(mk(kIdleBoostKey));
    final storedLastRockClickMillis = _prefs!.getInt(mk(kLastRockClickTimeKey));

    final storedClickAging = _prefs!.getDouble(mk(kClickAgingKey));
    final storedClickTimePower = _prefs!.getDouble(mk(kClickTimePowerKey));
    final storedRpsAging = _prefs!.getDouble(mk(kRpsAgingKey));
    final storedRpsTimePower = _prefs!.getDouble(mk(kRpsTimePowerKey));
    final storedGpsAging = _prefs!.getDouble(mk(kGpsAgingKey));
    final storedGpsTimePower = _prefs!.getDouble(mk(kGpsTimePowerKey));
    final storedTicsPerSecond = _prefs!.getInt(mk(kTicsPerSecondKey));

    final storedClicksThisRun = _prefs!.getInt(mk(kClicksThisRunKey));
    final storedManualClickCyclesThisRun = _prefs!.getDouble(mk(kManualClickCyclesThisRunKey));

    final storedAntimatter = _prefs!.getDouble(mk(kAntimatterKey));
    final storedAntimatterPerSecond = _prefs!.getDouble(mk(kAntimatterPerSecondKey));
    final storedPolyString = _prefs!.getString(mk(kAntimatterPolynomialKey));
    final storedPolyScalarsString = _prefs!.getString(mk(kAntimatterPolynomialScalarsKey));
    final storedCurrentTic = _prefs!.getInt(mk(kCurrentTicNumberKey));

    // ========= MONSTER (ALWAYS monster_...) =========
    final storedMonsterPlayerLevel = readMonsterInt(kMonsterPlayerLevelKey);
    final storedMonsterPlayerRage = readMonsterDouble(kMonsterPlayerRangeKey); // stored under "range"
    final storedMonsterPlayerAttack = readMonsterInt(kMonsterPlayerAttackKey);
    final storedMonsterPlayerExperience = readMonsterInt(kMonsterPlayerExperienceKey);

    final storedMonsterAttackMode = readMonsterString(kMonsterAttackModeKey);

    final storedMonsterClass = readMonsterString(kMonsterClassKey);
    final storedMonsterRarity = readMonsterInt(kMonsterRarityKey);
    final storedMonsterLevel = readMonsterInt(kMonsterLevelKey);
    final storedMonsterStatPoints = readMonsterInt(kMonsterStatPointsKey);

    final storedBaseHp = readMonsterDouble(kMonsterBaseHpKey);
    final storedBaseDef = readMonsterDouble(kMonsterBaseDefKey);
    final storedBaseRegen = readMonsterDouble(kMonsterBaseRegenKey);
    final storedBaseAura = readMonsterDouble(kMonsterBaseAuraKey);

    final storedCurHp = readMonsterDouble(kMonsterCurrentHpKey);
    final storedCurDef = readMonsterDouble(kMonsterCurrentDefKey);
    final storedCurRegen = readMonsterDouble(kMonsterCurrentRegenKey);
    final storedCurAura = readMonsterDouble(kMonsterCurrentAuraKey);

    final storedKillCount = readMonsterInt(kMonsterKillCountKey);

    final storedMonsterName = readMonsterString(kMonsterNameKey);
    final storedMonsterImagePath = readMonsterString(kMonsterImagePathKey);

    // ========= SHARED META =========
    final storedGold = _readGlobalDoubleWithFallback(kGoldKey);
    final storedTotalRefinedGold = _readGlobalDoubleWithFallback(kTotalRefinedGoldKey);
    final storedRebirthCount = _readGlobalIntWithFallback(kRebirthCountKey);

    final storedMaxSingleRunGold = _readGlobalDoubleWithFallback(kMaxGoldMultiplierKey);
    final storedAchievementMultiplier = _readGlobalDoubleWithFallback(kAchievementMultiplierKey);

    final storedTotalClicks = _readGlobalIntWithFallback(kTotalClicksKey);
    final storedTotalManualClickCycles = _readGlobalDoubleWithFallback(kTotalManualClickCyclesKey);
    final storedMaxCardCount = _readGlobalIntWithFallback(kMaxCardCountKey);

    final storedDarkMatter = _readGlobalDoubleWithFallback(kDarkMatterKey);
    final storedPendingDarkMatter = _readGlobalDoubleWithFallback(kPendingDarkMatterKey);

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
    if (storedPolyScalarsString != null && storedPolyScalarsString.isNotEmpty) {
      try {
        final decodedScalars = jsonDecode(storedPolyScalarsString) as List<dynamic>;
        polyScalars = decodedScalars.map((e) => (e as num).toDouble()).toList();
      } catch (_) {
        polyScalars = [];
      }
    }

    if (polyScalars.length < poly.length) {
      polyScalars.addAll(List<double>.filled(poly.length - polyScalars.length, 1.0));
    } else if (polyScalars.length > poly.length) {
      polyScalars = polyScalars.sublist(0, poly.length);
    }

    // ✅ Migration/fallback rules:
    // - chronoStepPMultiplier is the carry-over production multiplier (should persist across runs)
    // - rebirthMultiplier is earned this run only (usually 1 unless deck effects changed it)
    double loadedRebirth = storedRebirthMultiplier ?? 1.0;
    double loadedChrono;
    if (storedChronoStepP != null) {
      loadedChrono = storedChronoStepP;
    } else if (storedRebirthMultiplier != null && storedChronoStepP == null) {
      // Older saves might have only had one value; keep a reasonable fallback.
      loadedChrono = storedRebirthMultiplier;
    } else {
      loadedChrono = 1.0;
    }

    loadedRebirth = math.max(1.0, loadedRebirth);
    loadedChrono = math.max(1.0, loadedChrono);

    setState(() {
      _goldOre = storedGoldOre ?? 0;
      _totalGoldOre = storedTotalGoldOre ?? 0;

      _orePerSecond = storedOrePerSecond ?? 0;
      if (_gameMode == 'antimatter' && _orePerSecond < 1.0) {
        _orePerSecond = 1.0;
      }

      _baseOrePerClick = storedBaseOrePerClick ?? 0.0;
      _orePerSecondTransfer = storedOrePerSecondTransfer ?? 0.0;

      _idleBoost = storedIdleBoost ?? 0.0;
      _lastRockClickTime = storedLastRockClickMillis != null
          ? DateTime.fromMillisecondsSinceEpoch(storedLastRockClickMillis)
          : null;

      _clickAging = storedClickAging ?? 0.0;
      _clickTimePower = math.max(1.0, storedClickTimePower ?? 1.0);

      _rpsAging = storedRpsAging ?? 0.0;
      _rpsTimePower = math.max(1.0, storedRpsTimePower ?? 1.0);

      _gpsAging = storedGpsAging ?? 0.0;
      _gpsTimePower = math.max(0.0, storedGpsTimePower ?? 0.0);

      _ticsPerSecond = math.max(0, storedTicsPerSecond ?? 0);

      // ✅ FIX: do NOT mirror these.
      _rebirthMultiplier = loadedRebirth;
      _chronoStepPMultiplier = loadedChrono;

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

      _gold = storedGold ?? 0.0;
      _totalRefinedGold = storedTotalRefinedGold ?? 0.0;
      _rebirthCount = storedRebirthCount ?? 0;

      _maxSingleRunGold = storedMaxSingleRunGold ?? 1.0;
      _achievementMultiplier = storedAchievementMultiplier ?? 1.0;

      _totalClicks = storedTotalClicks ?? 0;
      _totalManualClickCycles = storedTotalManualClickCycles ?? 0.0;
      _maxCardCount = storedMaxCardCount ?? 0;

      _darkMatter = storedDarkMatter ?? 0.0;
      _pendingDarkMatter = storedPendingDarkMatter ?? 0.0;

      // Monster (always monster_...)
      _monsterPlayerLevel = math.max(1, storedMonsterPlayerLevel ?? 1);

      final double fallbackRage = (_monsterPlayerLevel * _monsterPlayerLevel).toDouble();
      _monsterPlayerRage = (storedMonsterPlayerRage ?? fallbackRage).clamp(1.0, double.infinity);

      _monsterKillCount = math.max(0, storedKillCount ?? 0);

      // Attack = kill count (min 1 so it isn't a hard lock)
      _monsterPlayerAttack = math.max(1, storedMonsterPlayerAttack ?? _monsterKillCount);

      _monsterPlayerExperience = math.max(0, storedMonsterPlayerExperience ?? 0);

      _monsterAttackMode =
      (storedMonsterAttackMode == null || storedMonsterAttackMode.isEmpty)
          ? 'head'
          : storedMonsterAttackMode;

      _monsterClassRaw = storedMonsterClass ?? '';
      _monsterRarity = math.max(1, storedMonsterRarity ?? 1);
      _monsterLevel = math.max(1, storedMonsterLevel ?? 1);
      _monsterStatPoints = math.max(0, storedMonsterStatPoints ?? 0);

      _monsterBaseHp = math.max(0.0, storedBaseHp ?? 0.0);
      _monsterBaseDef = math.max(0.0, storedBaseDef ?? 0.0);
      _monsterBaseRegen = math.max(0.0, storedBaseRegen ?? 0.0);
      _monsterBaseAura = math.max(0.0, storedBaseAura ?? 0.0);

      _monsterCurrentHp = (storedCurHp ?? 0.0).clamp(0.0, _monsterBaseHp);
      _monsterCurrentDef = (storedCurDef ?? 0.0).clamp(0.0, _monsterBaseDef);
      _monsterCurrentRegen = (storedCurRegen ?? 0.0).clamp(0.0, _monsterBaseRegen);
      _monsterCurrentAura = (storedCurAura ?? 0.0).clamp(0.0, _monsterBaseAura);

      _monsterName = storedMonsterName ?? '';
      _monsterImagePath = storedMonsterImagePath ?? '';
    });

    if (_gameMode == 'monster') {
      ensureMonsterInitialized();
    }
  }

  Future<void> _saveProgress() async {
    _prefs ??= await SharedPreferences.getInstance();
    _lastActiveTime = DateTime.now();

    String mk(String baseKey) => _modeKey(baseKey, _gameMode);

    // ✅ Monster keys should ALWAYS be stored under monster_... regardless of current _gameMode.
    String mkMonster(String baseKey) => _modeKey(baseKey, 'monster');

    await _prefs!.setDouble(mk(kGoldOreKey), _goldOre);
    await _prefs!.setDouble(mk(kTotalGoldOreKey), _totalGoldOre);
    await _prefs!.setDouble(mk(kOrePerSecondKey), _orePerSecond);
    await _prefs!.setDouble(mk(kBaseOrePerClickKey), _baseOrePerClick);

    await _prefs!.setDouble(mk(kOrePerSecondTransferKey), _orePerSecondTransfer);

    await _prefs!.setDouble(mk(kIdleBoostKey), _idleBoost);
    if (_lastRockClickTime != null) {
      await _prefs!.setInt(mk(kLastRockClickTimeKey), _lastRockClickTime!.millisecondsSinceEpoch);
    } else {
      await _prefs!.remove(mk(kLastRockClickTimeKey));
    }

    await _prefs!.setDouble(mk(kClickAgingKey), _clickAging);
    await _prefs!.setDouble(mk(kClickTimePowerKey), _clickTimePower);
    await _prefs!.setDouble(mk(kRpsAgingKey), _rpsAging);
    await _prefs!.setDouble(mk(kRpsTimePowerKey), _rpsTimePower);
    await _prefs!.setDouble(mk(kGpsAgingKey), _gpsAging);
    await _prefs!.setDouble(mk(kGpsTimePowerKey), _gpsTimePower);
    await _prefs!.setInt(mk(kTicsPerSecondKey), _ticsPerSecond);

    await _prefs!.setInt(mk(kManualClickCountKey), _manualClickCount);
    await _prefs!.setInt(mk(kManualClickPowerKey), _manualClickPower);
    await _prefs!.setInt(mk(kLastActiveKey), _lastActiveTime!.millisecondsSinceEpoch);

    await _prefs!.setBool(mk(kSpellFrenzyActiveKey), _spellFrenzyActive);
    await _prefs!.setDouble(mk(kSpellFrenzyDurationKey), _spellFrenzyDurationSeconds);
    await _prefs!.setDouble(mk(kSpellFrenzyCooldownKey), _spellFrenzyCooldownSeconds);
    await _prefs!.setDouble(mk(kSpellFrenzyMultiplierKey), _spellFrenzyMultiplier);

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

    // ✅ FIX: persist BOTH independently.
    await _prefs!.setDouble(mk(kRebirthMultiplierKey), _rebirthMultiplier);
    await _prefs!.setDouble(mk(kOverallMultiplierKey), _chronoStepPMultiplier);

    await _prefs!.setDouble(mk(kRandomSpawnChanceKey), _randomSpawnChance);
    await _prefs!.setInt(mk(kBonusRebirthGoldFromNuggetsKey), _bonusRebirthGoldFromNuggets);

    await _prefs!.setDouble(mk(kGpsClickCoeffKey), _gpsClickCoeff);
    await _prefs!.setDouble(mk(kTotalOreClickCoeffKey), _totalOreClickCoeff);
    await _prefs!.setDouble(mk(kClickMultiplicityKey), _clickMultiplicity);
    await _prefs!.setDouble(mk(kBaseClickOpsCoeffKey), _baseClickOpsCoeff);

    await _prefs!.setInt(mk(kClicksThisRunKey), _clicksThisRun);
    await _prefs!.setDouble(mk(kManualClickCyclesThisRunKey), _manualClickCyclesThisRun);

    await _prefs!.setDouble(mk(kAntimatterKey), _antimatter);
    await _prefs!.setDouble(mk(kAntimatterPerSecondKey), _antimatterPerSecond);
    await _prefs!.setString(mk(kAntimatterPolynomialKey), jsonEncode(_antimatterPolynomial));
    await _prefs!.setString(mk(kAntimatterPolynomialScalarsKey), jsonEncode(_antimatterPolynomialScalars));
    await _prefs!.setInt(mk(kCurrentTicNumberKey), _currentTicNumber);

    // ✅ Monster saves (ALWAYS monster_...)
    await _prefs!.setInt(mkMonster(kMonsterPlayerLevelKey), _monsterPlayerLevel);
    await _prefs!.setDouble(mkMonster(kMonsterPlayerRangeKey), _monsterPlayerRage);
    await _prefs!.setInt(mkMonster(kMonsterPlayerAttackKey), _monsterPlayerAttack);
    await _prefs!.setInt(mkMonster(kMonsterPlayerExperienceKey), _monsterPlayerExperience);

    await _prefs!.setString(mkMonster(kMonsterAttackModeKey), _monsterAttackMode);

    await _prefs!.setString(mkMonster(kMonsterClassKey), _monsterClassRaw);
    await _prefs!.setInt(mkMonster(kMonsterRarityKey), _monsterRarity);
    await _prefs!.setInt(mkMonster(kMonsterLevelKey), _monsterLevel);
    await _prefs!.setInt(mkMonster(kMonsterStatPointsKey), _monsterStatPoints);

    await _prefs!.setDouble(mkMonster(kMonsterBaseHpKey), _monsterBaseHp);
    await _prefs!.setDouble(mkMonster(kMonsterBaseDefKey), _monsterBaseDef);
    await _prefs!.setDouble(mkMonster(kMonsterBaseRegenKey), _monsterBaseRegen);
    await _prefs!.setDouble(mkMonster(kMonsterBaseAuraKey), _monsterBaseAura);

    await _prefs!.setDouble(mkMonster(kMonsterCurrentHpKey), _monsterCurrentHp);
    await _prefs!.setDouble(mkMonster(kMonsterCurrentDefKey), _monsterCurrentDef);
    await _prefs!.setDouble(mkMonster(kMonsterCurrentRegenKey), _monsterCurrentRegen);
    await _prefs!.setDouble(mkMonster(kMonsterCurrentAuraKey), _monsterCurrentAura);

    await _prefs!.setInt(mkMonster(kMonsterKillCountKey), _monsterKillCount);
    await _prefs!.setString(mkMonster(kMonsterNameKey), _monsterName);
    await _prefs!.setString(mkMonster(kMonsterImagePathKey), _monsterImagePath);

    // Shared meta
    await _prefs!.setDouble(kGoldKey, _gold);
    await _prefs!.setDouble(kTotalRefinedGoldKey, _totalRefinedGold);
    await _prefs!.setInt(kRebirthCountKey, _rebirthCount);

    await _prefs!.setDouble(kMaxGoldMultiplierKey, _maxSingleRunGold);
    await _prefs!.setDouble(kAchievementMultiplierKey, _achievementMultiplier);

    await _prefs!.setInt(kTotalClicksKey, _totalClicks);
    await _prefs!.setDouble(kTotalManualClickCyclesKey, _totalManualClickCycles);
    await _prefs!.setInt(kMaxCardCountKey, _maxCardCount);

    await _prefs!.setDouble(kDarkMatterKey, _darkMatter);
    await _prefs!.setDouble(kPendingDarkMatterKey, _pendingDarkMatter);

    await _prefs!.setString(kActiveGameModeKey, _gameMode);
  }

  Future<void> _changeGameMode(String newMode) async {
    if (newMode != 'gold' && newMode != 'antimatter' && newMode != 'monster') return;
    if (newMode == _gameMode) return;

    _prefs ??= await SharedPreferences.getInstance();
    await _saveProgress();

    setState(() {
      _gameMode = newMode;
      _lastActiveTime = null;
    });
    await _prefs!.setString(kActiveGameModeKey, _gameMode);

    await _loadModeSpecificProgress();

    if (_gameMode != 'monster') {
      await _applyOfflineProgress();
    } else {
      ensureMonsterInitialized();
      await _saveProgress();
    }

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
      } else if (storedSelected == 'monster' || storedSelected == 'monster_hunting') {
        nextMode = 'monster';
      } else if (storedSelected == 'antimatter' ||
          storedSelected == 'gold' ||
          storedSelected == 'monster') {
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

      // Aging + GPS refined gold
      _tickAgingAndGps();

      // Gold/antimatter ore tick only (monster mode does not auto-generate ore)
      if (_gameMode != 'monster') {
        final double effectiveOrePerSecond = _computeOrePerSecond();
        setState(() {
          _goldOre += effectiveOrePerSecond;
          _totalGoldOre += effectiveOrePerSecond;
          _currentTicNumber += 1;
        });
      } else {
        setState(() {
          _currentTicNumber += 1;
        });
      }

      if (_gameMode == 'antimatter') {
        _tickAntimatterSecond(seconds: 1);
      }

      if (_gameMode == 'monster') {
        tickMonsterSecond(seconds: 1);
      }

      TutorialManager.instance.onGoldOreChanged(context, _manualClickCount.toDouble());

      _tickNugget();

      if (momentumChanged) {
        _updatePreviewPerClick();
      }

      if (_ticsPerSecond > 0 && _gameMode != 'monster') {
        await _applyOfflineProgress(
          secondsOverride: _ticsPerSecond,
          showNotification: false,
        );
      }

      await _evaluateAndApplyAchievements();
      _saveProgress();
    });
  }

  void _applyCardUpgradeEffect(GameCard card, int cardLevel, int upgradesThisRun) {
    setState(() {
      card.cardEffect?.call(this, cardLevel, upgradesThisRun);
      if (upgradesThisRun > _maxCardCount) {
        _maxCardCount = upgradesThisRun;
      }
    });
    _saveProgress();
  }

  @override
  Widget build(BuildContext context) {
    return buildIdleGameScaffold(this, context);
  }
}
