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

/// Main game state for the idle game.
///
/// Implements [IdleGameEffectTarget] so card effects can modify the
/// current run's values (ore, orePerSecond, etc.) in a controlled way.
class _IdleGameScreenState extends State<IdleGameScreen>
    with SingleTickerProviderStateMixin
    implements IdleGameEffectTarget {
  int _currentTabIndex = 0;

  double _goldOre = 0;
  double _totalGoldOre = 0;
  double _gold = 0.0;

  /// Core ore per second from standard upgrades.
  double _orePerSecond = 0;

  /// Additive bonus ore per second (applied before Frenzy & overall multiplier).
  double _bonusOrePerSecond = 0.0;

  /// Flat bonus added to the base 1.0 ore per click.
  double _baseOrePerClick = 0.0;

  /// Additive bonus ore per click (applied before multipliers).
  double _bonusOrePerClick = 0.0;

  int _rebirthCount = 0;
  double _totalRefinedGold = 0;

  /// Which goal applies to the *current* run
  /// (e.g., 'mine_gold' or 'create_antimatter').
  String _rebirthGoal = 'mine_gold';

  /// Momentum system for clicks (kept for future use).
  int _momentumClicks = 0;
  DateTime? _lastClickTime;

  /// Momentum tuning values (persisted).
  double _momentumCap = 0.0;
  double _momentumScale = 1.0;

  /// Cached value for previewing how much will be gained on the next click.
  double _lastComputedOrePerClick = 1.0;

  /// Manual clicks on the rock (persisted, reset on rebirth).
  int _manualClickCount = 0;

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
  bool _spellFrenzyActive = false;
  DateTime? _spellFrenzyLastTriggerTime;
  double _spellFrenzyDurationSeconds = 0.0;
  double _spellFrenzyCooldownSeconds = 0.0;
  double _spellFrenzyMultiplier = 1.0;

  /// Multipliers
  ///
  /// - _rebirthMultiplier: accumulated during a run, applied to the *next* run.
  /// - _overallMultiplier: applied to BOTH ore/sec and ore/click after all
  ///   other effects (phase, frenzy, bonuses) are computed. Min value: 1.
  /// - _maxGoldMultiplier: highest rebirth gold ever earned. Starts at 1,
  ///   updated on rebirth if you beat the record.
  /// - _achievementMultiplier: starts at 1 and increases by 0.01 per achievement,
  ///   never reset on rebirth.
  double _rebirthMultiplier = 1.0;
  double _overallMultiplier = 1.0;
  double _maxGoldMultiplier = 1.0;
  double _achievementMultiplier = 1.0;

  /// Random nugget spawn chance (probability per second).
  ///
  /// Default should be 0, but set to 1.0 for testing.
  double _randomSpawnChance = 0.0; // CHANGE AFTER TESTING (set to 0.0)

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

  Future<void> _loadProgress() async {
    _prefs ??= await SharedPreferences.getInstance();

    final storedGoldOre = _prefs!.getDouble(kGoldOreKey);
    final storedTotalGoldOre = _prefs!.getDouble(kTotalGoldOreKey);
    final storedGold = _prefs!.getDouble(kGoldKey);
    final storedOrePerSecond = _prefs!.getDouble(kOrePerSecondKey);
    final storedBaseOrePerClick = _prefs!.getDouble(kBaseOrePerClickKey);
    final storedLastActive = _prefs!.getInt(kLastActiveKey);
    final storedRebirthCount = _prefs!.getInt(kRebirthCountKey);
    final storedTotalRefinedGold = _prefs!.getDouble(kTotalRefinedGoldKey);
    final storedRebirthGoal = _prefs!.getString(kRebirthGoalKey);
    final storedManualClicks = _prefs!.getInt(kManualClickCountKey);

    final storedFrenzyActive = _prefs!.getBool(kSpellFrenzyActiveKey);
    final storedFrenzyLastTrigger = _prefs!.getInt(kSpellFrenzyLastTriggerKey);
    final storedFrenzyDuration =
    _prefs!.getDouble(kSpellFrenzyDurationKey);
    final storedFrenzyCooldown =
    _prefs!.getDouble(kSpellFrenzyCooldownKey);
    final storedFrenzyMultiplier =
    _prefs!.getDouble(kSpellFrenzyMultiplierKey);

    final storedMomentumCap = _prefs!.getDouble(kMomentumCapKey);
    final storedMomentumScale = _prefs!.getDouble(kMomentumScaleKey);

    final storedBonusOrePerSecond =
    _prefs!.getDouble(kBonusOrePerSecondKey);
    final storedBonusOrePerClick =
    _prefs!.getDouble(kBonusOrePerClickKey);

    final storedRebirthMultiplier =
    _prefs!.getDouble(kRebirthMultiplierKey);
    final storedOverallMultiplier =
    _prefs!.getDouble(kOverallMultiplierKey);
    final storedMaxGoldMultiplier =
    _prefs!.getDouble(kMaxGoldMultiplierKey);
    final storedAchievementMultiplier =
    _prefs!.getDouble(kAchievementMultiplierKey);

    final storedRandomSpawnChance =
    _prefs!.getDouble(kRandomSpawnChanceKey);
    final storedBonusGoldFromNuggets =
    _prefs!.getInt(kBonusRebirthGoldFromNuggetsKey);

    setState(() {
      _goldOre = storedGoldOre ?? 0;
      _totalGoldOre = storedTotalGoldOre ?? 0;
      _gold = storedGold ?? 0;
      _orePerSecond = storedOrePerSecond ?? 0;
      _baseOrePerClick = storedBaseOrePerClick ?? 0.0;
      _rebirthCount = storedRebirthCount ?? 0;
      _totalRefinedGold = storedTotalRefinedGold ?? 0;
      _rebirthGoal = storedRebirthGoal ?? 'mine_gold';
      _manualClickCount = storedManualClicks ?? 0;
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
      _momentumScale = storedMomentumScale ?? 1.0;

      _bonusOrePerSecond = storedBonusOrePerSecond ?? 0.0;
      _bonusOrePerClick = storedBonusOrePerClick ?? 0.0;

      _rebirthMultiplier = storedRebirthMultiplier ?? 1.0;
      _overallMultiplier =
          math.max(1.0, storedOverallMultiplier ?? 1.0);
      _maxGoldMultiplier = storedMaxGoldMultiplier ?? 1.0;
      _achievementMultiplier = storedAchievementMultiplier ?? 1.0;

      _randomSpawnChance =
          storedRandomSpawnChance ?? 0.0;
      _bonusRebirthGoldFromNuggets =
          storedBonusGoldFromNuggets ?? 0;
    });
  }

  Future<void> _saveProgress() async {
    _prefs ??= await SharedPreferences.getInstance();
    _lastActiveTime = DateTime.now();

    await _prefs!.setDouble(kGoldOreKey, _goldOre);
    await _prefs!.setDouble(kTotalGoldOreKey, _totalGoldOre);
    await _prefs!.setDouble(kGoldKey, _gold);
    await _prefs!.setDouble(kOrePerSecondKey, _orePerSecond);
    await _prefs!.setDouble(kBaseOrePerClickKey, _baseOrePerClick);
    await _prefs!.setInt(kRebirthCountKey, _rebirthCount);
    await _prefs!.setDouble(kTotalRefinedGoldKey, _totalRefinedGold);
    await _prefs!.setString(kRebirthGoalKey, _rebirthGoal);
    await _prefs!.setInt(kManualClickCountKey, _manualClickCount);
    await _prefs!
        .setInt(kLastActiveKey, _lastActiveTime!.millisecondsSinceEpoch);

    await _prefs!.setBool(kSpellFrenzyActiveKey, _spellFrenzyActive);
    await _prefs!.setDouble(
        kSpellFrenzyDurationKey, _spellFrenzyDurationSeconds);
    await _prefs!.setDouble(
        kSpellFrenzyCooldownKey, _spellFrenzyCooldownSeconds);
    await _prefs!.setDouble(
        kSpellFrenzyMultiplierKey, _spellFrenzyMultiplier);
    if (_spellFrenzyLastTriggerTime != null) {
      await _prefs!.setInt(
        kSpellFrenzyLastTriggerKey,
        _spellFrenzyLastTriggerTime!.millisecondsSinceEpoch,
      );
    } else {
      await _prefs!.remove(kSpellFrenzyLastTriggerKey);
    }

    await _prefs!.setDouble(kMomentumCapKey, _momentumCap);
    await _prefs!.setDouble(kMomentumScaleKey, _momentumScale);

    await _prefs!.setDouble(kBonusOrePerSecondKey, _bonusOrePerSecond);
    await _prefs!.setDouble(kBonusOrePerClickKey, _bonusOrePerClick);

    await _prefs!.setDouble(kRebirthMultiplierKey, _rebirthMultiplier);
    await _prefs!.setDouble(kOverallMultiplierKey, _overallMultiplier);
    await _prefs!.setDouble(kMaxGoldMultiplierKey, _maxGoldMultiplier);
    await _prefs!.setDouble(
        kAchievementMultiplierKey, _achievementMultiplier);

    await _prefs!.setDouble(kRandomSpawnChanceKey, _randomSpawnChance);
    await _prefs!.setInt(
        kBonusRebirthGoldFromNuggetsKey, _bonusRebirthGoldFromNuggets);
  }

  /// Return the prefs key for the stored level of a given achievement.
  String _achievementLevelKey(String id) => 'achievement_${id}_level';

  /// Return the prefs key for the stored last progress of a given achievement.
  String _achievementProgressKey(String id) =>
      'achievement_${id}_progress';

  /// Apply rewards for a single completed achievement level:
  /// - +1 max deck capacity.
  /// - +1 max cards if maxCards < sqrt(maxCapacity) after the capacity bump.
  /// - +0.01 to the achievement multiplier.
  Future<void> _applyAchievementRewards() async {
    _prefs ??= await SharedPreferences.getInstance();

    int maxCards = _prefs!.getInt(kDeckMaxCardsKey) ?? 1;
    int maxCapacity = _prefs!.getInt(kDeckMaxCapacityKey) ?? 1;

    // +1 capacity per completed achievement level
    maxCapacity += 1;

    // If maxCards < sqrt(maxCapacity) AFTER increasing capacity, +1 max cards.
    if (math.pow(maxCards+1,2) <= maxCapacity && maxCards<100) {
      maxCards += 1;
    }

    await _prefs!.setInt(kDeckMaxCardsKey, maxCards);
    await _prefs!.setInt(kDeckMaxCapacityKey, maxCapacity);

    // Increase achievement multiplier (never reset on rebirth).
    setState(() {
      _achievementMultiplier += 0.01;
    });
    await _prefs!.setDouble(
        kAchievementMultiplierKey, _achievementMultiplier);
  }

  /// Evaluate all achievements using the current game state, and apply
  /// rewards if any thresholds are crossed.
  ///
  /// Driven entirely from [kAchievementCatalog], so adding a new achievement
  /// only requires changes in achievements_catalog.dart.
  ///
  /// Semantics:
  /// - For unique == false:
  ///     * Scaling (recurring) achievement.
  /// - For unique == true:
  ///     * One-shot achievement: only level 0 -> 1 once.
  Future<void> _evaluateAndApplyAchievements() async {
    _prefs ??= await SharedPreferences.getInstance();

    for (final def in kAchievementCatalog) {
      // Compute current progress using the shared catalog progressFn.
      final double progress = def.progressFn(this);

      final String levelKey = _achievementLevelKey(def.id);
      final String progressKey = _achievementProgressKey(def.id);

      int level = _prefs!.getInt(levelKey) ?? 0;

      // Always store the latest progress so the AchievementsTab can display it.
      await _prefs!.setDouble(progressKey, progress);

      if (def.unique) {
        // One-shot achievement: only go from level 0 -> 1 once.
        final double target = def.baseTarget;

        if (level == 0 && progress >= target) {
          level = 1;
          await _applyAchievementRewards();
          await _prefs!.setInt(levelKey, level);
        }

        // No scaling beyond that; continue to next achievement.
        continue;
      }

      // Scaling achievements: baseTarget * 10^level for each level.
      double target = achievementTargetForLevel(def, level);
      bool leveled = false;

      while (progress >= target) {
        level += 1;
        leveled = true;
        await _applyAchievementRewards();

        // Next level's target.
        target = achievementTargetForLevel(def, level);
      }

      if (leveled) {
        await _prefs!.setInt(levelKey, level);
      }
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
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

      // Apply Frenzy + overall multiplier to (base + bonus) ore per second.
      final bool frenzyActiveNow = _isFrenzyCurrentlyActive();
      final double frenzyMult =
      frenzyActiveNow ? _spellFrenzyMultiplier : 1.0;
      final double baseOrePerSecond =
          _orePerSecond + _bonusOrePerSecond;
      final double effectiveOrePerSecond =
          baseOrePerSecond * frenzyMult * _overallMultiplier;

      setState(() {
        _goldOre += effectiveOrePerSecond;
        _totalGoldOre += effectiveOrePerSecond;
      });

      // Handle nugget spawn / expiry once per second.
      _tickNugget();

      if (momentumChanged) {
        _updatePreviewPerClick();
      }

      // Evaluate achievements based on the updated state.
      await _evaluateAndApplyAchievements();

      _saveProgress();
    });
  }

  /// Handles nugget spawn/despawn logic.
  void _tickNugget() {
    final now = DateTime.now();
    bool changed = false;

    // Despawn any nuggets older than 10 seconds.
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
      // Probability of at least one spawn this second (clamped to 1).
      final double p = _randomSpawnChance.clamp(0.0, 1.0);
      if (_rng.nextDouble() < p) {
        const double nuggetSize = 64.0;
        final width = _playAreaSize!.width;
        final height = _playAreaSize!.height;

        if (width > nuggetSize && height > nuggetSize) {
          final double x =
              _rng.nextDouble() * (width - nuggetSize);
          final double y =
              _rng.nextDouble() * (height - nuggetSize);
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

  Future<void> _applyOfflineProgress() async {
    final double baseOrePerSecond =
        _orePerSecond + _bonusOrePerSecond;

    if (_lastActiveTime == null || baseOrePerSecond <= 0) {
      // Nothing to do, just update last active.
      await _saveProgress();
      return;
    }

    final now = DateTime.now();
    final diff = now.difference(_lastActiveTime!);
    final int seconds = diff.inSeconds;

    // Ignore very short gaps (e.g., app switch for a second)
    if (seconds <= 60) {
      await _saveProgress();
      return;
    }

    double earned;

    // If Frenzy is enabled and was triggered at some point, account for the
    // overlap between the offline window and the frenzy window.
    if (_spellFrenzyActive &&
        _spellFrenzyLastTriggerTime != null &&
        _spellFrenzyDurationSeconds > 0) {
      final int offlineStartSec =
          _lastActiveTime!.millisecondsSinceEpoch ~/ 1000;
      final int offlineEndSec = now.millisecondsSinceEpoch ~/ 1000;
      final int frenzyStartSec =
          _spellFrenzyLastTriggerTime!.millisecondsSinceEpoch ~/ 1000;
      final int frenzyEndSec =
          frenzyStartSec + _spellFrenzyDurationSeconds.round();

      final int overlapStart = math.max(offlineStartSec, frenzyStartSec);
      final int overlapEnd = math.min(offlineEndSec, frenzyEndSec);
      final int frenzyOverlap = math.max(0, overlapEnd - overlapStart);

      final int normalSeconds = math.max(0, seconds - frenzyOverlap);

      final double normalEarned =
          normalSeconds * baseOrePerSecond * _overallMultiplier;
      final double frenzyEarned = frenzyOverlap *
          baseOrePerSecond *
          _spellFrenzyMultiplier *
          _overallMultiplier;

      earned = normalEarned + frenzyEarned;
    } else {
      // No relevant Frenzy interval: use (base + bonus) orePerSecond only.
      earned = seconds * baseOrePerSecond * _overallMultiplier;
    }

    setState(() {
      _goldOre += earned;
      _totalGoldOre += earned;
    });

    // Achievements may be completed from offline gains.
    await _evaluateAndApplyAchievements();
    await _saveProgress();

    final durationText = _formatDuration(diff);

    final message = 'While you were away for $durationText,\n'
        'your miners produced ${earned.toStringAsFixed(0)} gold ore!';

    // Show the alert *after* first frame to avoid context issues in initState.
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
    if (_totalGoldOre <= 0) return 0;

    // level = floor(log_100(total_gold_ore))
    double levelRaw = math.log(_totalGoldOre) / math.log(100);
    levelRaw *= levelRaw;

    double manualClick;
    if (_manualClickCount == 0) {
      manualClick = 0;
    } else {
      manualClick = math.log(_manualClickCount) / math.log(10) - 1;
      manualClick = math.max(manualClick.floor(), 0).toDouble();
    }

    // Add bonus rebirth gold from random nuggets.
    final double nuggetBonus =
    _bonusRebirthGoldFromNuggets.toDouble();

    return levelRaw.floorToDouble() + manualClick + nuggetBonus;
  }

  Future<void> _clearCardUpgradeCounts() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.remove(kCardUpgradeCountsKey);
  }

  Future<void> _clearUpgradeDeckSnapshot() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.remove(kUpgradeDeckSnapshotKey);
  }

  Future<void> _attemptRebirth() async {
    final rebirthGold = _calculateRebirthGold();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Rebirth'),
        content: Text(
          'Rebirth will reset your gold ore, total gold ore, and ore per second '
              'back to 0, and grant you ${rebirthGold.toStringAsFixed(0)} refined gold.\n\n'
              'Do you want to continue?',
        ),
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

    // Determine which Next Run option is currently selected
    _prefs ??= await SharedPreferences.getInstance();
    final selectedGoal =
        _prefs!.getString(kNextRunSelectedKey) ?? 'mine_gold';

    setState(() {
      // Update the rebirth goal for this run
      _rebirthGoal = selectedGoal;

      // Award gold + total refined gold
      _gold += rebirthGold;
      _totalRefinedGold += rebirthGold;

      // Increment rebirth count only if reward > 0
      if (rebirthGold > 0) {
        _rebirthCount += 1;
      }

      // Update max gold multiplier with this rebirth result
      final double rebirthGoldForMax =
      rebirthGold <= 0 ? 1.0 : rebirthGold;
      if (rebirthGoldForMax > _maxGoldMultiplier) {
        _maxGoldMultiplier = rebirthGoldForMax;
      }

      // At the START of the new rebirth:
      // overallMultiplier = rebirthMultiplier * achievementMultiplier * sqrt(maxGoldMultiplier)
      final double combined = _rebirthMultiplier *
          _achievementMultiplier *
          math.sqrt(_maxGoldMultiplier);
      _overallMultiplier = math.max(1.0, combined);

      // Rebirth multiplier no longer applies; reset it to 1 for the new run.
      _rebirthMultiplier = 1.0;

      // Reset ore values
      _goldOre = 0;
      _totalGoldOre = 0;
      _orePerSecond = 0;
      _bonusOrePerSecond = 0.0;

      // Reset click-related stats for the new run
      _baseOrePerClick = 0.0;
      _bonusOrePerClick = 0.0;
      _lastComputedOrePerClick = 1.0;

      // Reset momentum for the new run
      _momentumClicks = 0;
      _lastClickTime = null;

      // Reset manual click count for the new run
      _manualClickCount = 0;

      // Reset nugget-related state (including spawn chance back to 0).
      _nuggets.clear();
      _bonusRebirthGoldFromNuggets = 0;
      _randomSpawnChance = 0.0;

      // Reset Frenzy trigger time (cooldown/effect reset)
      _spellFrenzyLastTriggerTime = null;
    });

    // Clear per-run card upgrades and the frozen upgrade deck snapshot
    // so the next run's upgrade pool is rebuilt from the active deck.
    await _clearCardUpgradeCounts();
    await _clearUpgradeDeckSnapshot();

    await _saveProgress();
    _updatePreviewPerClick();

    final runGoalText =
    _rebirthGoal == 'mine_gold' ? 'Mine gold' : _rebirthGoal;

    await alert_user(
      context,
      'You rebirthed and gained ${rebirthGold.toStringAsFixed(0)} refined gold!\n'
          'Total rebirths: $_rebirthCount\n'
          'Total refined gold: ${_totalRefinedGold.toStringAsFixed(0)}\n'
          'Run goal: $runGoalText\n'
          'Overall multiplier for this run: x${_overallMultiplier.toStringAsFixed(2)}',
      title: 'Rebirth Complete',
    );
  }

  /// For now: click value is base 1 per click + any per-click bonuses.
  void _updatePreviewPerClick() {
    setState(() {
      _lastComputedOrePerClick =
          (1.0 + _baseOrePerClick + _bonusOrePerClick) *
              _overallMultiplier;
    });
  }

  /// Called when an upgrade is purchased in the Upgrades tab.
  ///
  /// [cardLevel] is the player's level for this card.
  /// [upgradesThisRun] is how many times this card has been upgraded
  /// so far in the *current* run (after this purchase).
  void _applyCardUpgradeEffect(
      GameCard card,
      int cardLevel,
      int upgradesThisRun,
      ) {
    setState(() {
      card.cardEffect?.call(this, cardLevel, upgradesThisRun);
    });
    _saveProgress();
  }

  // ===== IdleGameEffectTarget implementation =====
  @override
  List<OwnedCard> getAllOwnedCards() {
    return PlayerCollectionRepository.instance.allOwnedCards;
  }

  @override
  double getGold() {
    return _gold;
  }

  @override
  double getTotalRefinedGold() {
    return _totalRefinedGold;
  }

  @override
  double getOrePerSecond() {
    return _orePerSecond;
  }

  @override
  double getCurrentRebirthGold() {
    return _calculateRebirthGold();
  }

  @override
  int getRebirthCount() {
    return _rebirthCount;
  }

  @override
  double getBaseOrePerClick() {
    // "Base click" value used for Reciprocity – 1 + core per-click bonus.
    return 1.0 + _baseOrePerClick;
  }

  @override
  double getBonusOrePerSecond() => _bonusOrePerSecond;

  @override
  double getBonusOrePerClick() => _bonusOrePerClick;

  @override
  double getFrenzyMultiplier() => _spellFrenzyMultiplier;

  @override
  double getFrenzyDuration() => _spellFrenzyDurationSeconds;

  @override
  double getMomentumScale() => _momentumScale;

  void addGold(double value) {
    _gold += value;
    _totalRefinedGold += value;
  }

  @override
  void setGold(double value) {
    _gold = value;
  }

  @override
  void setTotalRefinedGold(double value) {
    _totalRefinedGold = value;
  }

  /// Applies an ore/s value to the core ore-per-second.
  @override
  void setOrePerSecond(double value) {
    _orePerSecond = value;
  }

  /// Set bonus ore per second (applied before multipliers).
  @override
  void setBonusOrePerSecond(double value) {
    _bonusOrePerSecond = value;
  }

  /// Applies an instant ore gain.
  @override
  void addOre(double amount) {
    _goldOre += amount;
    _totalGoldOre += amount;
  }

  /// Sets base ore per click (before phase & multipliers).
  /// Incoming value is the "base click" (1 + stored bonus).
  @override
  void setBaseOrePerClick(double value) {
    _baseOrePerClick = value - 1.0;
    _updatePreviewPerClick();
  }

  /// Sets bonus ore per click (applied before multipliers).
  @override
  void setBonusOrePerClick(double value) {
    _bonusOrePerClick = value;
    _updatePreviewPerClick();
  }

  @override
  void turnOnFrenzy() {
    _spellFrenzyActive = true;
  }

  @override
  void setFrenzyMultiplier(double value) {
    _spellFrenzyMultiplier = value;
  }

  @override
  void setFrenzyDuration(double value) {
    _spellFrenzyDurationSeconds = value;
  }

  @override
  void setFrenzyCooldownFraction(double amount) {
    _spellFrenzyCooldownSeconds =
        _spellFrenzyDurationSeconds * amount;
  }

  /// Set the momentum cap (overwrites existing value).
  @override
  void setMomentumCap(double amount) {
    _momentumCap = amount;
  }

  /// Set the momentum scale.
  @override
  void setMomentumScale(double value) {
    _momentumScale = value;
  }

  // ===== Multipliers API (getters / setters) =====

  /// Getter for the rebirth multiplier (applies to *next* rebirth).
  @override
  double getRebirthMultiplier() => _rebirthMultiplier;

  /// Setter for the rebirth multiplier.
  @override
  void setRebirthMultiplier(double value) {
    setState(() {
      _rebirthMultiplier = value;
    });
    _saveProgress();
  }

  /// Getter for the overall multiplier (applies to this run).
  double getOverallMultiplier() => _overallMultiplier;

  /// Setter for the overall multiplier. Clamped to at least 1.
  void setOverallMultiplier(double value) {
    setState(() {
      _overallMultiplier = math.max(1.0, value);
    });
    _updatePreviewPerClick();
    _saveProgress();
  }

  /// Optional helpers for achievements / UI if you need them later.
  double getAchievementMultiplier() => _achievementMultiplier;

  void addAchievementMultiplier(double delta) {
    setState(() {
      _achievementMultiplier += delta;
    });
    _saveProgress();
  }

  double getMaxGoldMultiplier() => _maxGoldMultiplier;

  // ===== Random spawn chance API =====

  double getRandomSpawnChance() => _randomSpawnChance;

  @override
  void setRandomSpawnChance(double value) {
    setState(() {
      _randomSpawnChance = value;
    });
    _saveProgress();
  }

  // ====== Helper logic ======

  /// Compute click phase for a given manual click count.
  ///
  /// log_clicks = ceil(log10(manualClicks)), with a minimum of 2
  /// phase = floor(manualClicks * 10 / 10^log_clicks)
  /// Clamped to [1, 9] so we always have a valid rock_0x.png.
  int _computeClickPhase(int manualClicks) {
    if (manualClicks <= 0) return 1;

    final double rawLog = math.log(manualClicks) / math.log(10);
    int logClicks = rawLog.ceil();
    if (logClicks < 2) logClicks = 2;

    final double denom = math.pow(10, logClicks).toDouble();
    final double value = manualClicks * 10 / denom;

    int phase = value.floor();
    if (phase <= 0) phase = 1;
    if (phase > 9) phase = 9;
    return phase;
  }

  /// Convenience wrapper that uses the current stored _manualClickCount.
  int _currentClickPhase() => _computeClickPhase(_manualClickCount);

  /// Returns true if frenzy is currently active (within duration window).
  bool _isFrenzyCurrentlyActive() {
    if (!_spellFrenzyActive || _spellFrenzyLastTriggerTime == null) {
      return false;
    }
    final elapsedSeconds = DateTime.now()
        .difference(_spellFrenzyLastTriggerTime!)
        .inSeconds
        .toDouble();
    return elapsedSeconds >= 0 &&
        elapsedSeconds < _spellFrenzyDurationSeconds;
  }

  /// Helper for "current ore per click" for display.
  /// Base is (1 + base + bonus), with 10x in phase 9, and
  /// additional multiplier if Frenzy and overall are active.
  double _currentOrePerClickForDisplay() {
    final base = 1.0 + _baseOrePerClick + _bonusOrePerClick;
    final phase = _currentClickPhase();
    final phaseMult = phase == 9 ? 10.0 : 1.0;
    final frenzyMult =
    _isFrenzyCurrentlyActive() ? _spellFrenzyMultiplier : 1.0;
    return base * phaseMult * frenzyMult * _overallMultiplier;
  }

  /// Activate Frenzy at the current time.
  void _activateFrenzy() {
    final now = DateTime.now();
    setState(() {
      _spellFrenzyLastTriggerTime = now;
    });
    _saveProgress();
  }

  // ====== ROCK INTERACTION LOGIC ======

  /// Handle the *start* of a press/drag on the rock.
  /// Awards ore once and sets the initial tilt based on touch position.
  void _onRockPanDown(DragDownDetails details) {
    _handleRockPress(details.localPosition);
  }

  /// While dragging, update tilt and small positional offset to follow the finger.
  void _onRockPanUpdate(DragUpdateDetails details) {
    _updateRockTiltAndOffset(details.localPosition);
  }

  /// On release, rebound rock to normal.
  void _onRockPanEnd(DragEndDetails details) {
    _resetRockTransform();
  }

  /// Also rebound if the gesture is cancelled.
  void _onRockPanCancel() {
    _resetRockTransform();
  }

  void _handleRockPress(Offset localPosition) {
    // Remember where the press started for drag calculations.
    _rockPressLocalPosition = localPosition;

    // Momentum handling (future use)
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

    // Normalize to [-1, 1], where 0 is center.
    final double normX = (tapX - center) / center; // left -1, right +1
    final double normY = (tapY - center) / center; // top -1, bottom +1

    // Max tilt angle for a "pressed in" feel.
    const double maxTilt = 4 * math.pi / 18;

    // We want the rock to tilt *toward* the press.
    final double tiltX = normY * maxTilt;
    final double tiltY = -normX * maxTilt;

    // Compute phase for this click using the *new* click index.
    final int clicksAfterThis = _manualClickCount + 1;
    final int phase = _computeClickPhase(clicksAfterThis);
    final double phaseMult = phase == 9 ? 10.0 : 1.0;

    // Frenzy multiplier if active.
    final bool frenzyActiveNow = _isFrenzyCurrentlyActive();
    final double frenzyMult =
    frenzyActiveNow ? _spellFrenzyMultiplier : 1.0;

    final double baseClick =
        1.0 + _baseOrePerClick + _bonusOrePerClick;
    final double orePerClick =
        baseClick * phaseMult * frenzyMult * _overallMultiplier;

    setState(() {
      // Animate: shrink + 3D tilt toward tap point.
      _rockScale = 0.9;
      _rockTiltX = tiltX;
      _rockTiltY = tiltY;

      // No drag offset yet; only applied once the finger moves.
      _rockOffsetX = 0.0;
      _rockOffsetY = 0.0;

      // Game logic.
      _goldOre += orePerClick;
      _totalGoldOre += orePerClick;
      _lastComputedOrePerClick = orePerClick;
      _manualClickCount = clicksAfterThis;
    });

    _saveProgress();
  }

  void _updateRockTiltAndOffset(Offset localPosition) {
    // If for some reason we missed the press, just tilt without offset.
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

    // Tilt based on where inside the rock the finger currently is.
    const double rockSize = 440.0;
    final double tapX = localPosition.dx.clamp(0.0, rockSize);
    final double tapY = localPosition.dy.clamp(0.0, rockSize);
    final double center = rockSize / 2;

    final double normX = (tapX - center) / center; // -1 to 1
    final double normY = (tapY - center) / center; // -1 to 1

    const double maxTilt = 4 * math.pi / 18;

    final double tiltX = normY * maxTilt;
    final double tiltY = -normX * maxTilt;

    // Drag offset: 20% of the cursor movement from the press point.
    const double dragFactor = 0.2;
    const double maxOffset = 200.0; // keep it small

    final Offset delta = localPosition - _rockPressLocalPosition!;
    double offsetX = delta.dx * dragFactor;
    double offsetY = delta.dy * dragFactor;

    // Clamp to a small radius so it doesn't fly away.
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

  /// Called when a nugget is tapped.
  void _onNuggetTap(int id) {
    final index = _nuggets.indexWhere((n) => n.id == id);
    if (index == -1) return;

    // Reward logic:
    // If spawnChance > 1, add floor(spawnChance) gold,
    // plus fractional-chance of one more.
    final double whole = _randomSpawnChance.floorToDouble();
    final double fractional = _randomSpawnChance - whole;
    int bonus = whole.toInt();
    if (fractional > 0 && _rng.nextDouble() < fractional) {
      bonus += 1;
    }

    setState(() {
      _gold += bonus; // <-- now grants actual gold
      _nuggets.removeAt(index); // remove the clicked nugget
    });

    _saveProgress();
  }

  // ====== END ROCK / NUGGET LOGIC ======

  @override
  Widget build(BuildContext context) {
    return buildIdleGameScaffold(this, context);
  }
}
