// ==================================
// idle_game_monster.dart (UPDATED - FULL FILE)
// ==================================
part of 'idle_game_screen.dart';

const String kMonsterPlayerLevelKey = 'monster_player_level';

/// Stored as "range" historically, used as RAGE now.
const String kMonsterPlayerRangeKey = 'monster_player_range';

const String kMonsterPlayerAttackKey = 'monster_player_attack';
const String kMonsterPlayerExperienceKey = 'monster_player_experience';

const String kMonsterClassKey = 'monster_class';
const String kMonsterRarityKey = 'monster_rarity';
const String kMonsterLevelKey = 'monster_level';
const String kMonsterStatPointsKey = 'monster_stat_points';

const String kMonsterBaseHpKey = 'monster_base_hp';
const String kMonsterBaseDefKey = 'monster_base_def';
const String kMonsterBaseRegenKey = 'monster_base_regen';
const String kMonsterBaseAuraKey = 'monster_base_aura';

const String kMonsterCurrentHpKey = 'monster_current_hp';
const String kMonsterCurrentDefKey = 'monster_current_def';
const String kMonsterCurrentRegenKey = 'monster_current_regen';
const String kMonsterCurrentAuraKey = 'monster_current_aura';

const String kMonsterKillCountKey = 'monster_kill_count';

const String kMonsterNameKey = 'monster_name';
const String kMonsterImagePathKey = 'monster_image_path';

/// Monster combat selection (set via Upgrades tab)
const String kMonsterAttackModeKey = 'monster_attack_mode'; // "head","body","hyde","aura"

mixin IdleGameMonsterMixin on State<IdleGameScreen> {
  _IdleGameScreenState get _s => this as _IdleGameScreenState;

  // -----------------------
  // Tactic sync (prefs -> memory)
  // -----------------------
  String _normalizeMode(String raw) {
    switch (raw) {
      case 'head':
      case 'body':
      case 'hyde':
      case 'aura':
        return raw;
      default:
        return 'head';
    }
  }

  String _readAttackModeFromPrefsSync() {
    final prefs = _s._prefs;
    if (prefs == null) return _normalizeMode(_s._monsterAttackMode);

    // Preferred: non-prefixed key (UpgradesScreen writes this).
    final v1 = prefs.getString(kMonsterAttackModeKey);

    // Back-compat: in case something wrote it as monster_<key>.
    final v2 = prefs.getString(_modeKey(kMonsterAttackModeKey, 'monster'));

    final chosen = (v1 != null && v1.isNotEmpty) ? v1 : v2;
    return _normalizeMode(chosen ?? _s._monsterAttackMode);
  }

  void _syncAttackModeFromPrefs() {
    final synced = _readAttackModeFromPrefsSync();
    if (synced != _s._monsterAttackMode) {
      _s._monsterAttackMode = synced;
    }
  }

  Future<void> _persistAttackMode(String mode) async {
    _s._prefs ??= await SharedPreferences.getInstance();
    final prefs = _s._prefs!;
    final normalized = _normalizeMode(mode);

    // Write both so nothing ever drifts.
    await prefs.setString(kMonsterAttackModeKey, normalized);
    await prefs.setString(_modeKey(kMonsterAttackModeKey, 'monster'), normalized);

    _s._monsterAttackMode = normalized;
  }

  // -----------------------
  // Initialization
  // -----------------------
  void ensureMonsterInitialized() {
    if (_s._gameMode != 'monster') return;

    _syncAttackModeFromPrefs();

    final bool missing = _s._monsterClassRaw.isEmpty || _s._monsterBaseHp <= 0.0;
    if (missing) {
      generateMonster();
    }

    if (_s._monsterAttackMode.isEmpty) {
      _s._monsterAttackMode = 'head';
      _persistAttackMode('head');
    }
  }

  // -----------------------
  // Rage bump from GOLD rock taps (works in any mode)
  // -----------------------
  Future<void> bumpMonsterRageFromGoldTap() async {
    _s._prefs ??= await SharedPreferences.getInstance();

    final String levelKey = kMonsterPlayerLevelKey;
    final String rageKey = kMonsterPlayerRangeKey;

    final int level =
    (_s._prefs!.getInt(levelKey) ?? _s._monsterPlayerLevel).clamp(1, 1 << 30);

    final double delta = (level * level).toDouble();
    if (delta <= 0) return;

    final double currentRage =
        _s._prefs!.getDouble(rageKey) ?? _s._monsterPlayerRage;

    final double newRage = math.max(1.0, currentRage + delta);

    await _s._prefs!.setDouble(rageKey, newRage);

    if (_s.mounted) {
      _s.setState(() {
        _s._monsterPlayerLevel = level;
        _s._monsterPlayerRage = newRage;
      });
    }
  }

  // -----------------------
  // Monster generation
  // -----------------------
  void generateMonster() {
    if (_s._gameMode != 'monster') return;

    final rng = _s._rng;

    final cls = MonsterCatalog.availableClasses[
    rng.nextInt(MonsterCatalog.availableClasses.length)];

    final mean = math.max(1.0, _s._monsterPlayerLevel.toDouble());
    final std = math.max(1.0, mean * 0.10);
    final levelDouble = _nextGaussian(rng, mean: mean, stdDev: std);
    final monsterLevel = math.max(1, levelDouble.round());

    int rarity = 1;
    while (true) {
      final r = rng.nextDouble();
      if (r < 0.66) break;
      rarity += 1;
      if (rarity > 10) {
        rarity = 1;
        break;
      }
    }

    final int statPoints = math.pow(monsterLevel * rarity, 2).toInt();

    int hpPts = 0, defPts = 0, regenPts = 0, auraPts = 0;
    if (statPoints > 0) hpPts += 1;

    final info = MonsterCatalog.infoFor(cls);
    for (int i = 1; i < statPoints; i++) {
      final stat = info.sampleStat(rng);
      switch (stat) {
        case MonsterStat.hp:
          hpPts += 1;
          break;
        case MonsterStat.def:
          defPts += 1;
          break;
        case MonsterStat.regen:
          regenPts += 1;
          break;
        case MonsterStat.aura:
          auraPts += 1;
          break;
      }
    }

    final double baseHp = hpPts * 1000000.0;
    final double baseDef = defPts * 1000.0;
    final double baseRegen = regenPts * 1000.0;
    final double baseAura = auraPts * 1.0;

    final entry = MonsterCatalog.findEntry(cls, rarity, rng);

    _s.setState(() {
      _s._monsterClassRaw = MonsterCatalog.classToString(cls);
      _s._monsterRarity = rarity;
      _s._monsterLevel = monsterLevel;
      _s._monsterStatPoints = statPoints;

      _s._monsterBaseHp = baseHp;
      _s._monsterBaseDef = baseDef;
      _s._monsterBaseRegen = baseRegen;
      _s._monsterBaseAura = baseAura;

      _s._monsterCurrentHp = baseHp;
      _s._monsterCurrentDef = baseDef;
      _s._monsterCurrentRegen = baseRegen;
      _s._monsterCurrentAura = baseAura;

      _s._monsterName = entry?.monsterName ?? '';
      _s._monsterImagePath = entry?.monsterImagePath ?? '';
    });

    _s._saveProgress();
  }

  // -----------------------
  // Combat
  // -----------------------
  bool get isMonsterDefeated => _s._monsterCurrentHp <= 0;

  double get monsterGoldReward {
    return 100.0 *
        _s._monsterStatPoints.toDouble() *
        _s._monsterRarity.toDouble();
  }

  void tickMonsterSecond({required int seconds}) {
    if (_s._gameMode != 'monster') return;
    if (seconds <= 0) return;

    _syncAttackModeFromPrefs();

    if (_s._monsterCurrentHp <= 0) {
      _s._monsterPlayerRage =
          (_s._monsterPlayerRage - seconds.toDouble()).clamp(1.0, double.infinity);
      if (_s.mounted) _s.setState(() {});
      return;
    }

    for (int i = 0; i < seconds; i++) {
      _applyMonsterAttackOneSecond();

      final double heal = math.max(0.0, _s._monsterCurrentRegen);
      if (heal > 0) {
        _s._monsterCurrentHp =
            (_s._monsterCurrentHp + heal).clamp(0.0, _s._monsterBaseHp);
      }

      _s._monsterPlayerRage =
          (_s._monsterPlayerRage - 1.0).clamp(1.0, double.infinity);

      _clampMonsterCurrentStats();

      if (_s._monsterCurrentHp <= 0) {
        _s._monsterCurrentHp = 0.0;
        break;
      }
    }

    if (_s.mounted) _s.setState(() {});
  }

  void _applyMonsterAttackOneSecond() {
    final double atk = math.max(1.0, _s._monsterPlayerAttack.toDouble());
    final double rage = math.max(1.0, _s._monsterPlayerRage);
    final double rarity = math.max(1.0, _s._monsterRarity.toDouble());

    final double curDef = math.max(0.0, _s._monsterCurrentDef);
    final double curRegen = math.max(0.0, _s._monsterCurrentRegen);
    final double curAura = math.max(0.0, _s._monsterCurrentAura);

    final String mode =
    _s._monsterAttackMode.isEmpty ? 'head' : _s._monsterAttackMode;

    if (mode == 'head') {
      final double numerator = (atk * rage) - curDef;
      if (numerator <= 0) return;
      final double denom = rarity * (1.0 + curAura);
      final double dmg = numerator / denom;
      if (dmg <= 0) return;

      _s._monsterCurrentHp =
          (_s._monsterCurrentHp - dmg).clamp(0.0, _s._monsterBaseHp);
      return;
    }

    if (mode == 'body') {
      final double delta = (atk * rage) / (1000.0 * rarity);
      if (delta <= 0) return;
      _s._monsterCurrentRegen =
          (curRegen - delta).clamp(0.0, _s._monsterBaseRegen);
      return;
    }

    if (mode == 'hyde') {
      final double delta = (atk * rage) / (1000.0 * rarity);
      if (delta <= 0) return;
      _s._monsterCurrentDef =
          (curDef - delta).clamp(0.0, _s._monsterBaseDef);
      return;
    }

    if (mode == 'aura') {
      final double delta = (atk * rage) / (1000000.0 * rarity);
      if (delta <= 0) return;
      _s._monsterCurrentAura =
          (curAura - delta).clamp(0.0, _s._monsterBaseAura);
      return;
    }

    _s._monsterAttackMode = 'head';
  }

  void _clampMonsterCurrentStats() {
    _s._monsterCurrentHp = _s._monsterCurrentHp.clamp(0.0, _s._monsterBaseHp);
    _s._monsterCurrentDef =
        _s._monsterCurrentDef.clamp(0.0, _s._monsterBaseDef);
    _s._monsterCurrentRegen =
        _s._monsterCurrentRegen.clamp(0.0, _s._monsterBaseRegen);
    _s._monsterCurrentAura =
        _s._monsterCurrentAura.clamp(0.0, _s._monsterBaseAura);
  }

  // -----------------------
  // Slay
  // -----------------------
  void slayBeastAndCollectReward() {
    if (_s._gameMode != 'monster') return;
    if (_s._monsterCurrentHp > 0) return;

    final double goldReward = monsterGoldReward;
    final int expGained = _s._monsterStatPoints;

    _s.setState(() {
      _s._gold += goldReward;
      _s._totalRefinedGold += goldReward;

      _s._monsterKillCount += 1;
      _s._monsterPlayerExperience += expGained;

      while (true) {
        final int nextLevel = _s._monsterPlayerLevel + 1;
        final int need = nextLevel * nextLevel * nextLevel;
        if (_s._monsterPlayerExperience >= need) {
          _s._monsterPlayerExperience -= need;
          _s._monsterPlayerLevel = nextLevel;
        } else {
          break;
        }
      }

      _s._monsterPlayerRage =
          (_s._monsterPlayerLevel * _s._monsterPlayerLevel).toDouble();

      _s._monsterPlayerAttack = math.max(1, _s._monsterKillCount);

      _s._monsterCurrentHp = 0.0;
      _s._monsterCurrentDef = 0.0;
      _s._monsterCurrentRegen = 0.0;
      _s._monsterCurrentAura = 0.0;
    });

    _s._saveProgress();
    generateMonster();
  }

  // -----------------------
  // UI
  // -----------------------
  Widget buildMonsterTopBar() {
    _syncAttackModeFromPrefs();

    final int lvl = _s._monsterPlayerLevel;
    final int exp = _s._monsterPlayerExperience;
    final int nextNeed = (lvl + 1) * (lvl + 1) * (lvl + 1);

    final String clsRaw =
    _s._monsterClassRaw.isEmpty ? 'Unknown' : _s._monsterClassRaw;
    final String cls = _capitalizeWords(clsRaw);

    final String name = _s._monsterName.isEmpty ? '???' : _s._monsterName;
    final String tactic = _prettyTactic(_s._monsterAttackMode);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        children: [
          Text(
            'Refined Gold: ${displayNumber(_s._gold)}',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.amber,
              shadows: [
                Shadow(
                  blurRadius: 6,
                  color: Colors.black,
                  offset: Offset(2, 2),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Hunter Lv $lvl • EXP $exp / $nextNeed • Kills ${_s._monsterKillCount}',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white,
              shadows: [
                Shadow(
                  blurRadius: 4,
                  color: Colors.black54,
                  offset: Offset(1, 1),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            '$cls • $name • Lv ${_s._monsterLevel} • Rarity ${_s._monsterRarity} • Tactic: $tactic',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white,
              shadows: [
                Shadow(
                  blurRadius: 4,
                  color: Colors.black54,
                  offset: Offset(1, 1),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget buildMonsterMainTab() {
    _syncAttackModeFromPrefs();

    final bool defeated = isMonsterDefeated;

    final String clsRaw =
    _s._monsterClassRaw.isEmpty ? 'Unknown' : _s._monsterClassRaw;
    final String cls = _capitalizeWords(clsRaw);

    final String name = _s._monsterName.isEmpty ? '???' : _s._monsterName;

    final Widget art = (_s._monsterImagePath.isNotEmpty)
        ? Image.asset(
      _s._monsterImagePath,
      fit: BoxFit.contain, // ✅ max size WITHOUT cropping
      alignment: Alignment.topCenter,
    )
        : Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: const Center(
        child: Text(
          'Monster Art Placeholder',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );

    final String tactic = _prettyTactic(_s._monsterAttackMode);
    final String rateNote = _tacticRateNote();

    return Column(
      children: [
        // ✅ Monster name is above; art starts below it.
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            '$cls • $name',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [
                Shadow(
                  blurRadius: 6,
                  color: Colors.black,
                  offset: Offset(2, 2),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 10),

        // ✅ Monster takes maximum space without cropping.
        // ✅ Bottom is allowed to extend slightly under the top of the info box.
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double maxW = constraints.maxWidth;
              final double maxH = constraints.maxHeight;

              // Overlay sizing stays as before.
              final double overlayMaxHeight =
              math.min(180.0, math.max(120.0, maxH * 0.38));

              final double safeBottom = MediaQuery.of(context).padding.bottom;
              const double overlayOuterPaddingBottom = 6;

              // ✅ This is the key: allow art to underlap the info box a bit.
              // "a few lines" ≈ 24–40px. Tune here if you want.
              const double artUnderlap = 34.0;

              final double reservedForOverlay = (!defeated
                  ? (overlayMaxHeight + safeBottom + overlayOuterPaddingBottom - artUnderlap)
                  : 0.0);

              final double clampedReserve = math.max(0.0, reservedForOverlay);

              // ✅ Art height becomes as large as possible within remaining space.
              final double artHeight = math.max(0.0, maxH - clampedReserve);

              return Stack(
                children: [
                  // Monster art fills from the top down to just above (and slightly under)
                  // the top edge of the info box.
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    height: artHeight,
                    child: SizedBox(
                      width: maxW,
                      height: artHeight,
                      child: art,
                    ),
                  ),

                  // Bottom overlay pinned as low as possible.
                  if (!defeated)
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 0,
                      child: SafeArea(
                        top: false,
                        left: false,
                        right: false,
                        bottom: true,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: overlayOuterPaddingBottom),
                          child: _buildOverlayInfoPanel(
                            tactic: tactic,
                            rateNote: rateNote,
                            maxHeight: overlayMaxHeight,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),

        if (defeated)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: slayBeastAndCollectReward,
                child: Text(
                  'Slay the beast and collect ${displayNumber(monsterGoldReward)} gold',
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildOverlayInfoPanel({
    required String tactic,
    required String rateNote,
    required double maxHeight,
  }) {
    final Color playerColor = Colors.lightGreenAccent.shade100;
    final Color monsterColor = Colors.orangeAccent.shade100;

    final String auraCur = _fmtAura(_s._monsterCurrentAura);
    final String auraBase = _fmtAura(_s._monsterBaseAura);

    final String playerLine =
        'ATK ${_s._monsterPlayerAttack} • RAGE ${displayNumber(_s._monsterPlayerRage)} • Hunter Lv ${_s._monsterPlayerLevel}';
    final String monsterLine1 =
        'HP ${displayNumber(_s._monsterCurrentHp)} / ${displayNumber(_s._monsterBaseHp)}';
    final String monsterLine2 =
        'Def ${displayNumber(_s._monsterCurrentDef)} • Regen ${displayNumber(_s._monsterCurrentRegen)} • Aura $auraCur / $auraBase';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              Text(
                'Tactic: $tactic ($rateNote)',
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.white70,
                  shadows: [
                    Shadow(
                      blurRadius: 4,
                      color: Colors.black54,
                      offset: Offset(1, 1),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      playerLine,
                      style: TextStyle(
                        fontSize: 13,
                        color: playerColor,
                        shadows: const [
                          Shadow(
                            blurRadius: 4,
                            color: Colors.black54,
                            offset: Offset(1, 1),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(width: 28, height: 28),
                    tooltip: 'How monster hunting works',
                    icon: const Icon(Icons.info_outline, size: 18, color: Colors.white70),
                    onPressed: _showMonsterInfoDialog,
                  ),
                ],
              ),

              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(color: Colors.white24, height: 1),
              ),

              Text(
                'Monster • $monsterLine1',
                style: TextStyle(
                  fontSize: 13,
                  color: monsterColor,
                  shadows: const [
                    Shadow(
                      blurRadius: 4,
                      color: Colors.black54,
                      offset: Offset(1, 1),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                monsterLine2,
                style: TextStyle(
                  fontSize: 13,
                  color: monsterColor.withOpacity(0.95),
                  shadows: const [
                    Shadow(
                      blurRadius: 4,
                      color: Colors.black54,
                      offset: Offset(1, 1),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMonsterInfoDialog() {
    showDialog<void>(
      context: _s.context,
      builder: (ctx) => AlertDialog(
        title: const Text('Monster Hunting'),
        content: SingleChildScrollView(
          child: Text(
            'You can hunt down and kill monsters in order to gain a multiplier to your gold and antimatter production. '
                'You automatically attack the monster every second. The damage you do is based on the following formula: '
                '(ATK * Rage - Monster Def) / (Monster Rarity * Monster Aura). In addition to that, the monster will recover '
                'health based on their regen stat.\n\n'
                'You have 4 different attack options (selectable from the upgrades menu). Use these to reduce the monster\'s stats '
                'so you can damage them.\n\n'
                'Your Rage is the most importand stat for killing monsters. It increases every time you click on the rock in Gold Mining mode, '
                'so the more you advance there, the faster you will killl the monster. When a creature dies, it gives you gold and experience. '
                'Your Hunter level (viewable in the stats page) is what gives you a boost to your resource production in the other game modes and '
                'it also increases your attack level and your rage gain per click.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _fmtAura(double v) => v.toStringAsFixed(2);

  String _tacticRateNote() {
    final double atk = math.max(1.0, _s._monsterPlayerAttack.toDouble());
    final double rage = math.max(1.0, _s._monsterPlayerRage);
    final double rarity = math.max(1.0, _s._monsterRarity.toDouble());

    final double curDef = math.max(0.0, _s._monsterCurrentDef);
    final double curAura = math.max(0.0, _s._monsterCurrentAura);

    const double secondsPerDay = 86400.0;

    final String mode =
    _s._monsterAttackMode.isEmpty ? 'head' : _s._monsterAttackMode;

    if (mode == 'head') {
      final double numerator = (atk * rage) - curDef;
      if (numerator <= 0) return 'no damage at current stats';
      final double denom = rarity * (1.0 + curAura);
      final double dmgPerSec = denom <= 0 ? 0.0 : (numerator / denom);
      final double dmgPerDay = math.max(0.0, dmgPerSec * secondsPerDay);
      if (dmgPerDay <= 0) return 'no damage at current stats';
      return 'dealing ~${displayNumber(dmgPerDay)} HP per day';
    }

    if (mode == 'body') {
      final double deltaPerSec = (atk * rage) / (1000.0 * rarity);
      final double deltaPerDay = math.max(0.0, deltaPerSec * secondsPerDay);
      return 'reducing Regen by ~${displayNumber(deltaPerDay)} per day';
    }

    if (mode == 'hyde') {
      final double deltaPerSec = (atk * rage) / (1000.0 * rarity);
      final double deltaPerDay = math.max(0.0, deltaPerSec * secondsPerDay);
      return 'reducing Def by ~${displayNumber(deltaPerDay)} per day';
    }

    if (mode == 'aura') {
      final double deltaPerSec = (atk * rage) / (1000000.0 * rarity);
      final double deltaPerDay = math.max(0.0, deltaPerSec * secondsPerDay);
      return 'reducing Aura by ~${displayNumber(deltaPerDay)} per day';
    }

    return 'changing over time';
  }

  String _prettyTactic(String raw) {
    switch (raw) {
      case 'head':
        return 'Attack Head';
      case 'body':
        return 'Attack Body';
      case 'hyde':
        return 'Attack Hyde';
      case 'aura':
        return 'Attack Aura';
      default:
        return 'Attack Head';
    }
  }

  String _capitalizeWords(String input) {
    final s = input.trim();
    if (s.isEmpty) return s;
    final parts = s.split(RegExp(r'\s+'));
    return parts.map((w) {
      if (w.isEmpty) return w;
      final lower = w.toLowerCase();
      return lower[0].toUpperCase() + lower.substring(1);
    }).join(' ');
  }

  double _nextGaussian(math.Random rng,
      {required double mean, required double stdDev}) {
    double u1 = rng.nextDouble();
    double u2 = rng.nextDouble();
    if (u1 < 1e-12) u1 = 1e-12;
    final z0 = math.sqrt(-2.0 * math.log(u1)) * math.cos(2.0 * math.pi * u2);
    return mean + z0 * stdDev;
  }
}
