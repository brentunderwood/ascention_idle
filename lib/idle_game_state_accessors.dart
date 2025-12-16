part of 'idle_game_screen.dart';

/// Mixin that provides the concrete implementation of [IdleGameEffectTarget]
/// plus other small getter/setter helpers, so the main state file stays cleaner.
mixin IdleGameEffectTargetMixin on State<IdleGameScreen>
implements IdleGameEffectTarget {
  // We assume we are mixed into _IdleGameScreenState and have access to its
  // private fields and helper methods. All names below refer to members
  // declared in _IdleGameScreenState in idle_game_state.dart.

  @override
  List<OwnedCard> getAllOwnedCards() {
    return PlayerCollectionRepository.instance.allOwnedCards;
  }

  @override
  double getGold() {
    return (_this._gold);
  }

  @override
  double getGoldOre() {
    return (_this._goldOre);
  }

  @override
  double getTotalRefinedGold() {
    return (_this._totalRefinedGold);
  }

  /// Returns the *effective* ore per second using the centralized formula.
  @override
  double getOrePerSecond() {
    return _this._computeOrePerSecond();
  }

  @override
  double getBaseOrePerSecond() {
    return (_this._orePerSecond);
  }

  @override
  double getCurrentRebirthGold() {
    return _this._calculateRebirthGold();
  }

  @override
  int getRebirthCount() {
    return (_this._rebirthCount);
  }

  @override
  double getBaseOrePerClick() {
    return 1.0 + _this._baseOrePerClick;
  }

  @override
  double getBonusOrePerSecond() => _this._bonusOrePerSecond;

  @override
  double getBonusOrePerClick() => _this._bonusOrePerClick;

  @override
  double getFrenzyMultiplier() => _this._spellFrenzyMultiplier;

  @override
  double getFrenzyDuration() => _this._spellFrenzyDurationSeconds;

  @override
  double getMomentumScale() => _this._momentumScale;

  @override
  int getManualClickPower() => _this._manualClickPower;

  @override
  void addGold(double value) {
    _this._gold += value;
    _this._totalRefinedGold += value;
  }

  @override
  void setGold(double value) {
    _this._gold = value;
  }

  @override
  void setTotalRefinedGold(double value) {
    _this._totalRefinedGold = value;
  }

  @override
  void setManualClickPower(int value) {
    _this._manualClickPower = value;
  }

  /// Applies a *base* ore/s value; effective OPS is computed via _computeOrePerSecond.
  @override
  void setOrePerSecond(double value) {
    _this._orePerSecond = value;
  }

  /// Set bonus ore per second (applied before multipliers).
  @override
  void setBonusOrePerSecond(double value) {
    _this._bonusOrePerSecond = value;
  }

  /// Applies an instant ore gain.
  @override
  void addOre(double amount) {
    _this._goldOre += amount;
    _this._totalGoldOre += amount;

    TutorialManager.instance
        .onGoldOreChanged(context, _this._manualClickCount.toDouble());
  }

  /// Sets base ore per click (before phase & multipliers).
  @override
  void setBaseOrePerClick(double value) {
    _this._baseOrePerClick = value - 1.0;
    _this._updatePreviewPerClick();
  }

  /// Sets bonus ore per click (applied before multipliers).
  @override
  void setBonusOrePerClick(double value) {
    _this._bonusOrePerClick = value;
    _this._updatePreviewPerClick();
  }

  @override
  void turnOnFrenzy() {
    _this._spellFrenzyActive = true;
  }

  @override
  void setFrenzyMultiplier(double value) {
    _this._spellFrenzyMultiplier = value;
  }

  @override
  void setFrenzyDuration(double value) {
    _this._spellFrenzyDurationSeconds = value;
  }

  @override
  void setFrenzyCooldownFraction(double amount) {
    _this._spellFrenzyCooldownSeconds =
        _this._spellFrenzyDurationSeconds * amount;
  }

  /// Set the momentum cap (overwrites existing value).
  @override
  void setMomentumCap(double amount) {
    _this._momentumCap = amount;
  }

  /// Set the momentum scale.
  @override
  void setMomentumScale(double value) {
    _this._momentumScale = value;
  }

  // ===== Multipliers API (getters / setters) =====

  @override
  double getRebirthMultiplier() => _this._rebirthMultiplier;

  @override
  void setRebirthMultiplier(double value) {
    _this.setState(() {
      _this._rebirthMultiplier = value;
    });
    _this._saveProgress();
  }

  double getOverallMultiplier() => _this._overallMultiplier;

  void setOverallMultiplier(double value) {
    _this.setState(() {
      _this._overallMultiplier = math.max(1.0, value);
    });
    _this._updatePreviewPerClick();
    _this._saveProgress();
  }

  double getAchievementMultiplier() => _this._achievementMultiplier;

  void addAchievementMultiplier(double delta) {
    _this.setState(() {
      _this._achievementMultiplier += delta;
    });
    _this._saveProgress();
  }

  double getMaxGoldMultiplier() => _this._maxGoldMultiplier;

  // ===== Ore-per-click coefficient API =====

  double getGpsClickCoeff() => _this._gpsClickCoeff;

  void setGpsClickCoeff(double value) {
    _this.setState(() {
      _this._gpsClickCoeff = value;
    });
    _this._updatePreviewPerClick();
    _this._saveProgress();
  }

  double getTotalOreClickCoeff() => _this._totalOreClickCoeff;

  void setTotalOreClickCoeff(double value) {
    _this.setState(() {
      _this._totalOreClickCoeff = value;
    });
    _this._updatePreviewPerClick();
    _this._saveProgress();
  }

  double getClickMultiplicity() => _this._clickMultiplicity;

  void setClickMultiplicity(double value) {
    _this.setState(() {
      _this._clickMultiplicity = value;
    });
    _this._updatePreviewPerClick();
    _this._saveProgress();
  }

  // ===== Ore-per-second coefficient API =====

  double getBaseClickOpsCoeff() => _this._baseClickOpsCoeff;

  void setBaseClickOpsCoeff(double value) {
    _this.setState(() {
      _this._baseClickOpsCoeff = value;
    });
    _this._saveProgress();
  }

  // ===== NEW: Ore/sec -> Ore/click transfer API =====

  double getOrePerSecondTransfer() => _this._orePerSecondTransfer;

  void setOrePerSecondTransfer(double value) {
    _this.setState(() {
      _this._orePerSecondTransfer = value;
    });
    _this._saveProgress();
  }

  // ===== Random spawn chance API =====

  double getRandomSpawnChance() => _this._randomSpawnChance;

  @override
  void setRandomSpawnChance(double value) {
    _this.setState(() {
      _this._randomSpawnChance = value;
    });
    _this._saveProgress();
  }

  // ===== Tracked click / cycle / card-count stats API =====

  double getManualClickCycles() => _this._manualClickCyclesThisRun;

  double getTotalManualClickCycles() => _this._totalManualClickCycles;

  int getClicksThisRun() => _this._clicksThisRun;

  int getTotalClicks() => _this._totalClicks;

  int getMaxCardCount() => _this._maxCardCount;

  // Optional helpers you might want later:
  String getGameMode() => _this._gameMode;

  double getAntimatter() => _this._antimatter;

  double getAntimatterPerSecond() => _this._antimatterPerSecond;

  int getCurrentTicNumber() => _this._currentTicNumber;

  /// Expose polynomial update if you want to call it from card effects later.
  void setAntimatterPolynomialCoeff(int degree, int coeff) {
    _this.updateAntimatterPolynomialScalars(degree, coeff);
  }

  @override
  void simulateOfflineSeconds(int seconds) {
    _this._applyOfflineProgress(secondsOverride: seconds);
  }

  // ===== Internal helper to access the concrete state instance =====

  _IdleGameScreenState get _this => this as _IdleGameScreenState;
}
