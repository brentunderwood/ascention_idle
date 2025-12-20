// ==================================
// idle_game_gold.dart (FULL FILE)
// ==================================
part of 'idle_game_screen.dart';

/// ✅ FIXED: no `on _IdleGameScreenState` constraint (prevents self-superinterface cycle).
mixin IdleGameGoldMixin on State<IdleGameScreen> {
  _IdleGameScreenState get _s => this as _IdleGameScreenState;

  // =========================
  // NEW: Monster Hunter multipliers
  // =========================

  double _monsterHunterGoldMultiplier() {
    // Gold multiplier = Hunter Lv (minimum 1).
    final int lvl = (_s._monsterPlayerLevel <= 0) ? 1 : _s._monsterPlayerLevel;
    return lvl.toDouble();
  }

  double _effectiveGoldOverallMultiplier() {
    // Gold overall multiplier is boosted by Hunter Lv.
    return _s._overallMultiplier * _monsterHunterGoldMultiplier();
  }

  void _tickAgingAndGps() {
    _s.setState(() {
      _s._clickTimePower = math.max(1.0, _s._clickTimePower + _s._clickAging);
      _s._rpsTimePower = math.max(1.0, _s._rpsTimePower + _s._rpsAging);
      _s._gpsTimePower = math.max(0.0, _s._gpsTimePower + _s._gpsAging);

      // GPS: add refined gold (spendable) each second; does NOT affect rebirth.
      if (_s._gpsTimePower > 0) {
        _s._gold += _s._gpsTimePower;
      }
    });
  }

  void _tickNugget() {
    final now = DateTime.now();
    bool changed = false;

    if (_s._nuggets.isNotEmpty) {
      final before = _s._nuggets.length;
      _s._nuggets.removeWhere((n) => now.difference(n.spawnTime).inSeconds >= 10);
      if (_s._nuggets.length != before) {
        changed = true;
      }
    }

    if (_s._randomSpawnChance > 0 && _s._playAreaSize != null) {
      final double p = _s._randomSpawnChance.clamp(0.0, 1.0);
      if (_s._rng.nextDouble() < p) {
        const double nuggetSize = 64.0;
        final width = _s._playAreaSize!.width;
        final height = _s._playAreaSize!.height;

        if (width > nuggetSize && height > nuggetSize) {
          final double x = _s._rng.nextDouble() * (width - nuggetSize);
          final double y = _s._rng.nextDouble() * (height - nuggetSize);
          _s._nuggets.add(
            _Nugget(
              id: _s._nextNuggetId++,
              position: Offset(x, y),
              spawnTime: now,
            ),
          );
          changed = true;
        }
      }
    }

    if (changed) {
      _s.setState(() {});
    }
  }

  double _computeIdleClickMultiplier({
    required DateTime now,
    DateTime? lastRockClickTimeOverride,
    double? idleBoostOverride,
  }) {
    final DateTime? last = lastRockClickTimeOverride ?? _s._lastRockClickTime;
    final double boost = idleBoostOverride ?? _s._idleBoost;

    if (last == null) return 1.0;

    final int secondsSince = now.difference(last).inSeconds;
    if (secondsSince <= 60) return 1.0;

    final double extra = boost * (secondsSince - 60);
    return math.max(1.0, 1.0 + extra);
  }

  double _computeOrePerClick({
    int? manualClicksOverride,
    DateTime? now,
    DateTime? lastRockClickTimeOverride,
    double? idleBoostOverride,
  }) {
    final int clicks = manualClicksOverride ?? _s._manualClickCount;

    final int phase = _computeClickPhase(clicks);
    final double phaseMult = (phase == 9) ? 10.0 : 1.0;

    final bool frenzyActiveNow = _isFrenzyCurrentlyActive();
    final double frenzyMult = frenzyActiveNow ? _s._spellFrenzyMultiplier : 1.0;

    final double baseTerm = 1.0 +
        _s._baseOrePerClick +
        _s._gpsClickCoeff * _s._orePerSecond +
        _s._totalOreClickCoeff * math.pow(_s._totalGoldOre, 0.5);

    double momentumFactor = 1.0;
    if (_s._momentumCap > 0 && _s._momentumScale > 0) {
      final double scaled = _s._momentumScale * _s._momentumClicks;
      final double clamped = scaled.clamp(0.0, _s._momentumCap);
      momentumFactor += clamped;
    }

    final DateTime t = now ?? DateTime.now();
    final double idleMult = _computeIdleClickMultiplier(
      now: t,
      lastRockClickTimeOverride: lastRockClickTimeOverride,
      idleBoostOverride: idleBoostOverride,
    );

    final double timeMult = math.max(1.0, _s._clickTimePower);

    return baseTerm *
        phaseMult *
        frenzyMult *
        momentumFactor *
        _effectiveGoldOverallMultiplier() *
        _s._clickMultiplicity *
        idleMult *
        timeMult;
  }

  double _computeOrePerSecond() {
    final double baseOrePerSecond = _s._orePerSecond + _s._bonusOrePerSecond;

    final bool frenzyActiveNow = _isFrenzyCurrentlyActive();
    final double frenzyMult = frenzyActiveNow ? _s._spellFrenzyMultiplier : 1.0;

    final double baseCombined =
        baseOrePerSecond + _s._baseClickOpsCoeff * (1.0 + _s._baseOrePerClick);

    final double timeMult = math.max(1.0, _s._rpsTimePower);

    return baseCombined * frenzyMult * _effectiveGoldOverallMultiplier() * timeMult;
  }

  void _updatePreviewPerClick() {
    _s.setState(() {
      _s._lastComputedOrePerClick = _computeOrePerClick(
        manualClicksOverride: _s._manualClickCount,
        now: DateTime.now(),
      );
    });
  }

  int _computeClickPhase(int manualClicks) {
    const double scalingFactor = 1.1;
    if (manualClicks <= 0) return 1;

    double manualClickCycles;
    double lowerBound;
    double upperBound;

    if (manualClicks < 100) {
      manualClickCycles = 0;
      lowerBound = 0;
      upperBound = 100;
    } else {
      manualClickCycles =
          math.log(manualClicks * (scalingFactor - 1) / 100 + 1) /
              math.log(scalingFactor);
      manualClickCycles = manualClickCycles.floorToDouble();
      lowerBound = 100 * (math.pow(scalingFactor, manualClickCycles) - 1) / (scalingFactor - 1);
      upperBound =
          100 * (math.pow(scalingFactor, manualClickCycles + 1) - 1) /
              (scalingFactor - 1);
    }

    final double progress = (manualClicks - lowerBound) / (upperBound - lowerBound);
    final int phase = (progress * 9).floor() + 1;
    return phase;
  }

  int _currentClickPhase() => _computeClickPhase(_s._manualClickCount);

  bool _isFrenzyCurrentlyActive() {
    if (!_s._spellFrenzyActive || _s._spellFrenzyLastTriggerTime == null) {
      return false;
    }
    final elapsedSeconds =
    DateTime.now().difference(_s._spellFrenzyLastTriggerTime!).inSeconds.toDouble();
    return elapsedSeconds >= 0 && elapsedSeconds < _s._spellFrenzyDurationSeconds;
  }

  double _currentOrePerClickForDisplay() {
    return _computeOrePerClick(now: DateTime.now());
  }

  void _activateFrenzy() {
    final now = DateTime.now();
    _s.setState(() {
      _s._spellFrenzyLastTriggerTime = now;
    });
    _s._saveProgress();
  }

  // Sum of discrete arithmetic series over seconds.
  double _sumPowerOverSeconds({
    required double power0,
    required double aging,
    required int seconds,
  }) {
    if (seconds <= 0) return 0.0;
    return seconds * power0 + aging * (seconds * (seconds + 1) / 2.0);
  }

  String _formatDuration(Duration d) {
    if (d.inHours >= 1) {
      final hours = d.inHours;
      final minutes = d.inMinutes % 60;
      if (minutes > 0) return '${hours}h ${minutes}m';
      return '${hours}h';
    } else if (d.inMinutes >= 1) {
      final minutes = d.inMinutes;
      final seconds = d.inSeconds % 60;
      if (seconds > 0) return '${minutes}m ${seconds}s';
      return '${minutes}m';
    } else {
      return '${d.inSeconds}s';
    }
  }

  Future<void> _applyOfflineProgress({
    int? secondsOverride,
    bool showNotification = true,
  }) async {
    int seconds;
    Duration diff;

    if (secondsOverride != null) {
      if (secondsOverride <= 0) {
        await _s._saveProgress();
        return;
      }
      seconds = secondsOverride;
      diff = Duration(seconds: secondsOverride);
    } else {
      if (_s._lastActiveTime == null) {
        await _s._saveProgress();
        return;
      }

      final now = DateTime.now();
      diff = now.difference(_s._lastActiveTime!);
      seconds = diff.inSeconds;

      if (seconds <= 60) {
        await _s._saveProgress();
        return;
      }
    }

    // ✅ Monster offline simulation: keep fighting + rage decay while offline.
    // (No ore production in monster mode.)
    if (_s._gameMode == 'monster') {
      _s.ensureMonsterInitialized();

      _s.setState(() {
        _s._currentTicNumber += seconds;
      });

      _s.tickMonsterSecond(seconds: seconds);

      await _s._evaluateAndApplyAchievements();
      await _s._saveProgress();
      return;
    }

    // ---- Normal (gold/antimatter) offline ore logic below ----
    final double baseCoreOps = _s._orePerSecond + _s._bonusOrePerSecond;
    final double baseClick = 1.0 + _s._baseOrePerClick;
    final double baseCombined = baseCoreOps + _s._baseClickOpsCoeff * baseClick;

    if (baseCombined <= 0) {
      await _s._saveProgress();
      return;
    }

    final double clickPower0 = _s._clickTimePower;
    final double rpsPower0 = _s._rpsTimePower;
    final double gpsPower0 = _s._gpsTimePower;

    final double rpsPowerSum = _sumPowerOverSeconds(
      power0: rpsPower0,
      aging: _s._rpsAging,
      seconds: seconds,
    );

    final double gpsPowerSum = _sumPowerOverSeconds(
      power0: gpsPower0,
      aging: _s._gpsAging,
      seconds: seconds,
    );

    final double finalClickPower = math.max(1.0, clickPower0 + _s._clickAging * seconds);
    final double finalRpsPower = math.max(1.0, rpsPower0 + _s._rpsAging * seconds);
    final double finalGpsPower = math.max(0.0, gpsPower0 + _s._gpsAging * seconds);

    final double effectiveOverall =
    (_s._gameMode == 'gold') ? _effectiveGoldOverallMultiplier() : _s._overallMultiplier;

    double earned;

    if (_s._spellFrenzyActive &&
        _s._spellFrenzyLastTriggerTime != null &&
        _s._spellFrenzyDurationSeconds > 0) {
      final now = DateTime.now();
      final int offlineEndSec = now.millisecondsSinceEpoch ~/ 1000;
      final int offlineStartSec = offlineEndSec - seconds;

      final int frenzyStartSec =
          _s._spellFrenzyLastTriggerTime!.millisecondsSinceEpoch ~/ 1000;
      final int frenzyEndSec =
          frenzyStartSec + _s._spellFrenzyDurationSeconds.round();

      final int overlapStart = math.max(offlineStartSec, frenzyStartSec);
      final int overlapEnd = math.min(offlineEndSec, frenzyEndSec);
      final int frenzyOverlap = math.max(0, overlapEnd - overlapStart);

      final int normalSeconds = math.max(0, seconds - frenzyOverlap);

      final double normalRpsSum = _sumPowerOverSeconds(
        power0: rpsPower0,
        aging: _s._rpsAging,
        seconds: normalSeconds,
      );
      final double frenzyRpsSum = _sumPowerOverSeconds(
        power0: math.max(1.0, rpsPower0 + _s._rpsAging * normalSeconds),
        aging: _s._rpsAging,
        seconds: frenzyOverlap,
      );

      final double normalEarned = baseCombined * effectiveOverall * normalRpsSum;
      final double frenzyEarned =
          baseCombined * effectiveOverall * _s._spellFrenzyMultiplier * frenzyRpsSum;

      earned = normalEarned + frenzyEarned;
    } else {
      earned = baseCombined * effectiveOverall * rpsPowerSum;
    }

    _s.setState(() {
      _s._goldOre += earned;
      _s._totalGoldOre += earned;

      if (gpsPowerSum > 0) {
        _s._gold += gpsPowerSum;
      }

      _s._clickTimePower = finalClickPower;
      _s._rpsTimePower = finalRpsPower;
      _s._gpsTimePower = finalGpsPower;
    });

    // Antimatter offline tick
    if (_s._gameMode == 'antimatter' && seconds > 0) {
      _s.setState(() {
        _s._currentTicNumber += seconds;
      });
      _s._tickAntimatterSecond(seconds: seconds);
    } else if (seconds > 0) {
      _s.setState(() {
        _s._currentTicNumber += seconds;
      });
    }

    TutorialManager.instance.onGoldOreChanged(_s.context, _s._manualClickCount.toDouble());

    await _s._evaluateAndApplyAchievements();
    await _s._saveProgress();

    if (!showNotification) return;

    final durationText = _formatDuration(diff);

    final message = 'While you were away for $durationText,\n'
        'your miners produced ${earned.toStringAsFixed(0)} gold ore!';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      alert_user(
        _s.context,
        message,
        title: 'Offline Progress',
      );
    });
  }

  /// ✅ Economy-only rock click logic (visuals are in RockDisplayMixin in idle_game_screen.dart).
  void _performRockClickEconomy({DateTime? nowOverride}) {
    if (_s._gameMode != 'gold') return;

    final DateTime now = nowOverride ?? DateTime.now();

    if (_s._lastClickTime == null ||
        now.difference(_s._lastClickTime!) > const Duration(seconds: 10)) {
      _s._momentumClicks = 0;
    }
    _s._momentumClicks += 1;
    _s._lastClickTime = now;

    final double transfer = _s._orePerSecondTransfer;
    final double nextOrePerSecond = math.max(0.0, _s._orePerSecond - transfer);
    final double nextBaseOrePerClick = _s._baseOrePerClick + transfer;

    final int clicksAfterThis =
        _s._manualClickCount + 1 * _s._manualClickPower * _s._clickMultiplicity.toInt();

    final double prevOrePerSecond = _s._orePerSecond;
    final double prevBaseOrePerClick = _s._baseOrePerClick;

    _s._orePerSecond = nextOrePerSecond;
    _s._baseOrePerClick = nextBaseOrePerClick;

    final double orePerClick = _computeOrePerClick(
      manualClicksOverride: clicksAfterThis,
      now: now,
      lastRockClickTimeOverride: _s._lastRockClickTime,
      idleBoostOverride: _s._idleBoost,
    );

    _s._orePerSecond = prevOrePerSecond;
    _s._baseOrePerClick = prevBaseOrePerClick;

    _s.setState(() {
      _s._orePerSecond = nextOrePerSecond;
      _s._baseOrePerClick = nextBaseOrePerClick;

      _s._goldOre += orePerClick;
      _s._totalGoldOre += orePerClick;

      _s._lastComputedOrePerClick = orePerClick;
      _s._manualClickCount = clicksAfterThis;

      _s._clicksThisRun += 1;
      _s._totalClicks += 1;

      _s._lastRockClickTime = now;
    });

    // ✅ gold rock taps also increase monster rage by (monster level)^2
    // ignore: unawaited_futures
    _s.bumpMonsterRageFromGoldTap();

    TutorialManager.instance.onGoldOreChanged(_s.context, _s._manualClickCount.toDouble());
    _s._saveProgress();
  }

  void _onNuggetTap(int id) {
    final index = _s._nuggets.indexWhere((n) => n.id == id);
    if (index == -1) return;

    final double whole = _s._randomSpawnChance.floorToDouble();
    final double fractional = _s._randomSpawnChance - whole;
    int bonus = whole.toInt();
    if (fractional > 0 && _s._rng.nextDouble() < fractional) {
      bonus += 1;
    }

    _s.setState(() {
      _s._gold += bonus;
      _s._nuggets.removeAt(index);
    });

    _s._saveProgress();
  }
}
