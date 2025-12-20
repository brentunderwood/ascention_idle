// ==================================
// monster_catalog.dart (UPDATED FILE)
// ==================================
import 'dart:math' as math;

/// Monster stats that receive stat points.
enum MonsterStat { hp, def, regen, aura }

/// Available monster classes.
enum MonsterClass { mythic }

/// Per-class stat distribution probabilities (must sum to ~1.0).
class MonsterClassInfo {
  final MonsterClass monsterClass;
  final double hpProb;
  final double defProb;
  final double regenProb;
  final double auraProb;

  const MonsterClassInfo({
    required this.monsterClass,
    required this.hpProb,
    required this.defProb,
    required this.regenProb,
    required this.auraProb,
  }) : assert(hpProb >= 0 && defProb >= 0 && regenProb >= 0 && auraProb >= 0);

  MonsterStat sampleStat(math.Random rng) {
    final r = rng.nextDouble();
    final a = hpProb;
    final b = a + defProb;
    final c = b + regenProb;
    // remainder -> aura
    if (r < a) return MonsterStat.hp;
    if (r < b) return MonsterStat.def;
    if (r < c) return MonsterStat.regen;
    return MonsterStat.aura;
  }
}

/// A monster art/name entry.
class MonsterEntry {
  /// Stable id used for persistence (kills, unlocks, etc).
  final String id;

  final String monsterName;
  final MonsterClass monsterClass;
  final int monsterRarity; // 1..10
  final String monsterImagePath;

  const MonsterEntry({
    required this.id,
    required this.monsterName,
    required this.monsterClass,
    required this.monsterRarity,
    required this.monsterImagePath,
  });
}

class MonsterCatalog {
  /// Prefix for per-monster kill counts in SharedPreferences.
  static const String killCountPrefix = 'monster_kills_';

  /// Class list used for random selection.
  static const List<MonsterClass> availableClasses = [
    MonsterClass.mythic,
  ];

  /// Per-class stat point distribution probabilities.
  static const Map<MonsterClass, MonsterClassInfo> classInfo = {
    MonsterClass.mythic: MonsterClassInfo(
      monsterClass: MonsterClass.mythic,
      hpProb: 0.25,
      defProb: 0.25,
      regenProb: 0.25,
      auraProb: 0.25,
    ),
  };

  /// Monster art/name catalog.
  ///
  /// REQUIRED by your spec:
  /// - create placeholder entries for rarities 1..10 in class 'Mythic'
  /// - "most attributes blank" (we keep name/image path blank; rarity/class set)
  static const List<MonsterEntry> entries = [
    MonsterEntry(
      id: 'mythic_r1_minotaur',
      monsterName: 'Minotaur',
      monsterClass: MonsterClass.mythic,
      monsterRarity: 1,
      monsterImagePath:
      'assets/click_screen_art/monster_hunting/mythic/r1_minotaur.png',
    ),
    MonsterEntry(
      id: 'mythic_r2_harpy',
      monsterName: 'Harpy',
      monsterClass: MonsterClass.mythic,
      monsterRarity: 2,
      monsterImagePath: 'assets/click_screen_art/monster_hunting/mythic/r2_harpy.png',
    ),
    MonsterEntry(
      id: 'mythic_r3_medusa',
      monsterName: 'Medusa',
      monsterClass: MonsterClass.mythic,
      monsterRarity: 3,
      monsterImagePath: 'assets/click_screen_art/monster_hunting/mythic/r3_medusa.png',
    ),
    MonsterEntry(
      id: 'mythic_r4_placeholder',
      monsterName: '',
      monsterClass: MonsterClass.mythic,
      monsterRarity: 4,
      monsterImagePath: '',
    ),
    MonsterEntry(
      id: 'mythic_r5_placeholder',
      monsterName: '',
      monsterClass: MonsterClass.mythic,
      monsterRarity: 5,
      monsterImagePath: '',
    ),
    MonsterEntry(
      id: 'mythic_r6_cerberus',
      monsterName: 'Cerberus',
      monsterClass: MonsterClass.mythic,
      monsterRarity: 6,
      monsterImagePath:
      'assets/click_screen_art/monster_hunting/mythic/r6_cerberus.png',
    ),
    MonsterEntry(
      id: 'mythic_r7_placeholder',
      monsterName: '',
      monsterClass: MonsterClass.mythic,
      monsterRarity: 7,
      monsterImagePath: '',
    ),
    MonsterEntry(
      id: 'mythic_r8_placeholder',
      monsterName: '',
      monsterClass: MonsterClass.mythic,
      monsterRarity: 8,
      monsterImagePath: '',
    ),
    MonsterEntry(
      id: 'mythic_r9_placeholder',
      monsterName: '',
      monsterClass: MonsterClass.mythic,
      monsterRarity: 9,
      monsterImagePath: '',
    ),
    MonsterEntry(
      id: 'mythic_r10_placeholder',
      monsterName: '',
      monsterClass: MonsterClass.mythic,
      monsterRarity: 10,
      monsterImagePath: '',
    ),
  ];

  /// SharedPreferences key used for a monster's kill count.
  static String killCountKey(String monsterId) => '$killCountPrefix$monsterId';

  static String killCountKeyForEntry(MonsterEntry e) => killCountKey(e.id);

  static MonsterEntry? findEntry(MonsterClass cls, int rarity, math.Random rng) {
    final matches = entries
        .where((e) => e.monsterClass == cls && e.monsterRarity == rarity)
        .toList();
    if (matches.isEmpty) return null;
    return matches[rng.nextInt(matches.length)];
  }

  /// Find by class+rarity + either imagePath or name.
  /// Useful when you only have what's stored on the state.
  static MonsterEntry? findBySnapshot({
    required MonsterClass cls,
    required int rarity,
    required String name,
    required String imagePath,
  }) {
    if (imagePath.isNotEmpty) {
      final hit = entries.where((e) => e.monsterImagePath == imagePath).toList();
      if (hit.isNotEmpty) return hit.first;
    }

    final hits = entries
        .where((e) =>
    e.monsterClass == cls &&
        e.monsterRarity == rarity &&
        (name.isNotEmpty ? e.monsterName == name : true))
        .toList();

    if (hits.isEmpty) return null;
    return hits.first;
  }

  static MonsterClassInfo infoFor(MonsterClass cls) {
    return classInfo[cls] ?? classInfo[MonsterClass.mythic]!;
  }

  static String classToString(MonsterClass cls) => cls.name;

  static MonsterClass classFromString(String raw) {
    for (final c in MonsterClass.values) {
      if (c.name == raw) return c;
    }
    return MonsterClass.mythic;
  }
}
