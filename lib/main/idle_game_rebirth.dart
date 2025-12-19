// ==================================
// idle_game_rebirth.dart (FULL FILE)
// ==================================
part of 'idle_game_screen.dart';

/// ✅ FIXED: no `on _IdleGameScreenState` constraint (prevents self-superinterface cycle).
mixin IdleGameRebirthMixin on State<IdleGameScreen> {
  _IdleGameScreenState get _s => this as _IdleGameScreenState;

  String _achievementLevelKey(String id) => 'achievement_${id}_level';
  String _achievementProgressKey(String id) => 'achievement_${id}_progress';

  Future<void> _applyAchievementRewards() async {
    _s._prefs ??= await SharedPreferences.getInstance();

    int maxCards = _s._prefs!.getInt(kDeckMaxCardsKey) ?? 1;
    int maxCapacity = _s._prefs!.getInt(kDeckMaxCapacityKey) ?? 1;

    maxCapacity += 1;

    if (math.pow(maxCards + 1, 2) <= maxCapacity && maxCards < 100) {
      maxCards += 1;
    }

    await _s._prefs!.setInt(kDeckMaxCardsKey, maxCards);
    await _s._prefs!.setInt(kDeckMaxCapacityKey, maxCapacity);

    _s.setState(() {
      _s._achievementMultiplier += 0.01;
    });
    await _s._prefs!.setDouble(kAchievementMultiplierKey, _s._achievementMultiplier);
  }

  Future<void> _evaluateAndApplyAchievements() async {
    _s._prefs ??= await SharedPreferences.getInstance();

    for (final def in kAchievementCatalog) {
      final double progress = def.progressFn(_s);

      final String levelKey = _achievementLevelKey(def.id);
      final String progressKey = _achievementProgressKey(def.id);

      int level = _s._prefs!.getInt(levelKey) ?? 0;

      await _s._prefs!.setDouble(progressKey, progress);

      if (def.unique) {
        final double target = def.baseTarget;

        if (level == 0 && progress >= target) {
          level = 1;
          await _applyAchievementRewards();
          await _s._prefs!.setInt(levelKey, level);
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
        await _s._prefs!.setInt(levelKey, level);
      }
    }
  }

  double _computeManualClickCyclesFromClicks(int manualClicks) {
    const double scalingFactor = 1.1;
    if (manualClicks < 100) return 0.0;

    double manualClickCycles =
        math.log(manualClicks * (scalingFactor - 1) / 100 + 1) / math.log(scalingFactor);
    manualClickCycles = manualClickCycles.floorToDouble();
    manualClickCycles = manualClickCycles * (manualClickCycles + 1) / 2.0;
    return manualClickCycles;
  }

  double _calculateRebirthGold() {
    if (_s._goldOre <= 0) return 0;

    final double levelRaw = math.pow(_s._totalGoldOre, 1 / 3).floorToDouble();
    final double manualClickCycles = _computeManualClickCyclesFromClicks(_s._manualClickCount);

    _s._manualClickCyclesThisRun = manualClickCycles;
    return levelRaw + manualClickCycles;
  }

  Future<void> _clearCardUpgradeCounts() async {
    _s._prefs ??= await SharedPreferences.getInstance();
    String mk(String baseKey) => _modeKey(baseKey, _s._gameMode);
    await _s._prefs!.remove(mk(kCardUpgradeCountsKey));
  }

  Future<void> _clearUpgradeDeckSnapshot() async {
    _s._prefs ??= await SharedPreferences.getInstance();
    String mk(String baseKey) => _modeKey(baseKey, _s._gameMode);
    await _s._prefs!.remove(mk(kUpgradeDeckSnapshotKey));
  }

  Future<void> _attemptRebirth() async {
    final double rebirthGold = _calculateRebirthGold();
    final bool isGoldModeNow = _s._gameMode == 'gold';

    final double previewDarkMatterReward = _s._pendingDarkMatter;

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
      context: _s.context,
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

    _s._prefs ??= await SharedPreferences.getInstance();
    final selectedModeRaw = _s._prefs!.getString(kNextRunSelectedKey) ?? 'gold';

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

    final double manualCyclesThisRun = _computeManualClickCyclesFromClicks(_s._manualClickCount);
    final bool wasGoldMode = _s._gameMode == 'gold';
    final double darkMatterReward = _s._pendingDarkMatter;

    _s.setState(() {
      _s._manualClickCyclesThisRun = manualCyclesThisRun;
      _s._totalManualClickCycles += manualCyclesThisRun;

      _s._clicksThisRun = 0;
      _s._gameMode = selectedMode;

      if (wasGoldMode && rebirthGold > 0) {
        _s._gold += rebirthGold;
        _s._totalRefinedGold += rebirthGold;

        _s._rebirthCount += 1;

        final double rebirthGoldForMax = rebirthGold <= 0 ? 1.0 : rebirthGold;
        if (rebirthGoldForMax > _s._maxGoldMultiplier) {
          _s._maxGoldMultiplier = rebirthGoldForMax;
        }

        final double combined = (1 +
            _s._rebirthMultiplier *
                _s._achievementMultiplier *
                (1 + math.log(_s._maxGoldMultiplier) / math.log(1000)));
        _s._overallMultiplier = math.max(1.0, combined);
      }

      if (!wasGoldMode && darkMatterReward > 0) {
        _s._darkMatter += darkMatterReward;
        _s._pendingDarkMatter = 0.0;
      }

      _s._rebirthMultiplier = 1.0;

      _s._goldOre = 0;
      _s._totalGoldOre = 0;

      _s._orePerSecond = (_s._gameMode == 'antimatter') ? 1.0 : 0.0;
      _s._bonusOrePerSecond = 0.0;

      _s._baseOrePerClick = 0.0;
      _s._bonusOrePerClick = 0.0;
      _s._lastComputedOrePerClick = 1.0;

      _s._orePerSecondTransfer = 0.0;

      _s._idleBoost = 0.0;
      _s._lastRockClickTime = null;

      _s._clickAging = 0.0;
      _s._clickTimePower = 1.0;

      _s._rpsAging = 0.0;
      _s._rpsTimePower = 1.0;

      _s._gpsAging = 0.0;
      _s._gpsTimePower = 0.0;

      _s._ticsPerSecond = 0;

      _s._momentumClicks = 0;
      _s._lastClickTime = null;

      _s._manualClickCount = 0;
      _s._manualClickPower = 1;

      _s._nuggets.clear();
      _s._bonusRebirthGoldFromNuggets = 0;
      _s._randomSpawnChance = 0.0;

      _s._spellFrenzyActive = false;
      _s._spellFrenzyLastTriggerTime = null;
      _s._spellFrenzyDurationSeconds = 0.0;
      _s._spellFrenzyCooldownSeconds = 0.0;
      _s._spellFrenzyMultiplier = 1.0;

      _s._momentumCap = 0.0;
      _s._momentumScale = 0.0;

      _s._gpsClickCoeff = 0.0;
      _s._totalOreClickCoeff = 0.0;
      _s._clickMultiplicity = 1.0;
      _s._baseClickOpsCoeff = 0.0;

      _s._antimatter = 0.0;
      _s._antimatterPerSecond = 0.0;
      _s._antimatterPolynomial = [];
      _s._antimatterPolynomialScalars = [];
      _s._currentTicNumber = 0;

      _s.resetRockVisuals();
    });

    await _clearCardUpgradeCounts();
    await _clearUpgradeDeckSnapshot();

    await _s._saveProgress();
    _s._updatePreviewPerClick();

    final runGoalText = _s._gameMode == 'gold' ? 'Mine gold' : 'Create antimatter';

    String message;
    if (wasGoldMode) {
      message =
      'You rebirthed and gained ${rebirthGold.toStringAsFixed(0)} refined gold!\n'
          'Total rebirths: ${_s._rebirthCount}\n'
          'Total refined gold: ${_s._totalRefinedGold.toStringAsFixed(0)}\n'
          'Game mode: $runGoalText\n'
          'Overall multiplier for this run: x${_s._overallMultiplier.toStringAsFixed(2)}';
    } else {
      message =
      'You rebirthed in antimatter mode and gained '
          '${displayNumber(darkMatterReward)} dark matter.\n'
          'Total dark matter: ${displayNumber(_s._darkMatter)}\n'
          'Game mode: $runGoalText\n'
          'Overall multiplier for this run: x${_s._overallMultiplier.toStringAsFixed(2)}';
    }

    await alert_user(
      _s.context,
      message,
      title: 'Rebirth Complete',
    );
  }
}
