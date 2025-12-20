// ==================================
// monster_catalog.dart (NEW FILE)
// ==================================
import 'dart:math' as math;

/// Monster stats that receive stat points.
enum MonsterStat { hp, def, regen, aura }

/// Available monster classes.
enum MonsterClass {
  mythic
}

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
  final String monsterName;
  final MonsterClass monsterClass;
  final int monsterRarity; // 1..10
  final String monsterImagePath;

  const MonsterEntry({
    required this.monsterName,
    required this.monsterClass,
    required this.monsterRarity,
    required this.monsterImagePath,
  });
}

class MonsterCatalog {
  /// Class list used for random selection.
  static const List<MonsterClass> availableClasses = [
    MonsterClass.mythic,
  ];

  /// Per-class stat point distribution probabilities.
  ///
  /// You can tune these later; they only need to exist and sum to 1.
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
      monsterName: 'Minotaur',
      monsterClass: MonsterClass.mythic,
      monsterRarity: 1,
      monsterImagePath: 'assets/click_screen_art/monster_hunting/mythic/r1_minotaur.png',
    ),
    MonsterEntry(
      monsterName: '',
      monsterClass: MonsterClass.mythic,
      monsterRarity: 2,
      monsterImagePath: '',
    ),
    MonsterEntry(
      monsterName: '',
      monsterClass: MonsterClass.mythic,
      monsterRarity: 3,
      monsterImagePath: '',
    ),
    MonsterEntry(
      monsterName: '',
      monsterClass: MonsterClass.mythic,
      monsterRarity: 4,
      monsterImagePath: '',
    ),
    MonsterEntry(
      monsterName: '',
      monsterClass: MonsterClass.mythic,
      monsterRarity: 5,
      monsterImagePath: '',
    ),
    MonsterEntry(
      monsterName: 'Cerberus',
      monsterClass: MonsterClass.mythic,
      monsterRarity: 6,
      monsterImagePath: 'assets/click_screen_art/monster_hunting/mythic/r6_cerberus.png',
    ),
    MonsterEntry(
      monsterName: '',
      monsterClass: MonsterClass.mythic,
      monsterRarity: 7,
      monsterImagePath: '',
    ),
    MonsterEntry(
      monsterName: '',
      monsterClass: MonsterClass.mythic,
      monsterRarity: 8,
      monsterImagePath: '',
    ),
    MonsterEntry(
      monsterName: '',
      monsterClass: MonsterClass.mythic,
      monsterRarity: 9,
      monsterImagePath: '',
    ),
    MonsterEntry(
      monsterName: '',
      monsterClass: MonsterClass.mythic,
      monsterRarity: 10,
      monsterImagePath: '',
    ),
  ];

  static MonsterEntry? findEntry(MonsterClass cls, int rarity, math.Random rng) {
    final matches = entries
        .where((e) => e.monsterClass == cls && e.monsterRarity == rarity)
        .toList();
    if (matches.isEmpty) return null;
    return matches[rng.nextInt(matches.length)];
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
