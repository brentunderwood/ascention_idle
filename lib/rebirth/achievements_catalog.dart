import 'dart:math' as math;

import '../cards/card_effects.dart';
import '../cards/game_card_models.dart';
import '../cards/card_catalog.dart';

/// Function signature for evaluating the progress of an achievement.
///
/// Uses [IdleGameEffectTarget] so it can read game-state values in the
/// same way that card effects do (getGold, getOrePerSecond, etc.).
typedef AchievementProgressFn = double Function(IdleGameEffectTarget target);

/// Definition of a single achievement type.
///
/// Each achievement has:
/// 1. [id]          - stable ID used for persistence.
/// 2. [name]        - human-readable label.
/// 3. [baseTarget]  - base target; per-level target is:
///                    baseTarget * 10^level.
/// 4. [progressFn]  - computes current progress from the live game state.
/// 5. [description] - text shown in the UI describing what the achievement tracks.
/// 6. [unique]      - if false, once completed it does NOT spawn a new
///                    achievement level. The UI should show it as completed
///                    with a green background and no further progress.
class AchievementDefinition {
  final String id;
  final String name;
  final double baseTarget;
  final AchievementProgressFn progressFn;
  final String description;
  final bool unique;

  const AchievementDefinition({
    required this.id,
    required this.name,
    required this.baseTarget,
    required this.progressFn,
    required this.description,
    required this.unique,
  });
}

/// Shared prefixes for storing per-achievement state in SharedPreferences.
///
/// We store:
/// - current level:   "achievement_level_<id>"   -> int
/// - last progress:   "achievement_progress_<id>" -> double
/// - current target:  "achievement_target_<id>"  -> double
const String kAchievementLevelPrefix = 'achievement_level_';
const String kAchievementProgressPrefix = 'achievement_progress_';
const String kAchievementTargetPrefix = 'achievement_target_';

/// Helper to compute the numerical target for a given [level].
///
/// target(level) = baseTarget * 10^level.
double achievementTargetForLevel(AchievementDefinition def, int level) {
  return def.baseTarget * math.pow(10.0, level).toDouble();
}

/// Count owned cards of a specific rarity rank (1–10).
double _countCardsOfRarity(IdleGameEffectTarget target, int rank) {
  final cards = target.getAllOwnedCards();
  int count = 0;

  for (final owned in cards) {
    final template = CardCatalog.getById(owned.cardId);
    if (template != null && template.rank == rank) {
      count++;
    }
  }

  return count.toDouble();
}

/// Count owned "unique" cards (rank < 0).
double _countUniqueCards(IdleGameEffectTarget target) {
  final cards = target.getAllOwnedCards();
  int count = 0;

  for (final owned in cards) {
    final template = CardCatalog.getById(owned.cardId);
    if (template != null && template.rank < 0) {
      count++;
    }
  }

  return count.toDouble();
}

/// Max "upgrades" for a single card, interpreted as:
///   max(level - baseLevel) across all owned cards (clamped at >= 0).
double _maxUpgradesForAnyCard(IdleGameEffectTarget target) {
  final cards = target.getAllOwnedCards();
  int maxDelta = 0;

  for (final owned in cards) {
    final template = CardCatalog.getById(owned.cardId);
    if (template == null) continue;

    final int delta = math.max(0, owned.level - template.baseLevel);
    if (delta > maxDelta) {
      maxDelta = delta;
    }
  }

  return maxDelta.toDouble();
}

/// Total "upgrades" across all cards, interpreted as:
///   sum(max(0, level - baseLevel)) for every owned card.
double _totalCardUpgrades(IdleGameEffectTarget target) {
  final cards = target.getAllOwnedCards();
  int totalDelta = 0;

  for (final owned in cards) {
    final template = CardCatalog.getById(owned.cardId);
    if (template == null) continue;

    totalDelta += math.max(0, owned.level - template.baseLevel);
  }

  return totalDelta.toDouble();
}

/// Helper: use dynamic to access extended tracking getters that are
/// implemented in [IdleGameEffectTargetMixin] but not declared on the
/// base [IdleGameEffectTarget] interface.
double _getDoubleFromDynamic(
    IdleGameEffectTarget target,
    String methodName,
    ) {
  final dyn = target as dynamic;
  final result = dyn
      .noSuchMethod; // just to satisfy the analyzer; we'll call via switch

  // We'll actually switch in the callers; this helper is not used directly.
  throw UnimplementedError();
}

/// Central achievements catalog.
///
/// Semantics:
/// - Level N has target: baseTarget * 10^N
/// - When progress >= target, the achievement "levels up" (for non-unique
///   achievements), applying its effects in the idle game state.
/// - If [unique] is false, a completed achievement will *not* spawn a new
///   level; it should instead display as completed with no further progress.
final List<AchievementDefinition> kAchievementCatalog = [
  /// Progress: total refined gold (never reset).
  ///
  /// Target growth: 1, 10, 100, 1,000, ...
  AchievementDefinition(
    id: 'rebirth_count',
    name: 'Born Again Fanatic',
    baseTarget: 1.0,
    progressFn: (IdleGameEffectTarget target) {
      return target.getRebirthCount().toDouble();
    },
    description: 'Rebirth. Again, and again, and again.',
    unique: false,
  ),

  /// Progress: current rebirth reward (what you’d get if you rebirthed now).
  ///
  /// Drives "push big rebirth" gameplay.
  AchievementDefinition(
    id: 'current_rebirth_gold',
    name: 'You CAN take it with you when you die.',
    baseTarget: 1.0,
    progressFn: (IdleGameEffectTarget target) {
      return target.getCurrentRebirthGold().toDouble();
    },
    description: 'Collect a lot of gold before you rebirth.',
    unique: false,
  ),

  /// Progress: ore per second (effective base, not including multipliers
  /// baked into _overallMultiplier).
  AchievementDefinition(
    id: 'ore_per_second',
    name: 'Big Bad John',
    baseTarget: 1.0,
    progressFn: (IdleGameEffectTarget target) {
      return target.getBaseOrePerSecond();
    },
    description:
    'Get as much ore per second as you can (not counting bonus multipliers).',
    unique: false,
  ),

  /// Progress: current ore.
  AchievementDefinition(
    id: 'current_ore',
    name: 'Finding the Motherload',
    baseTarget: 100.0,
    progressFn: (IdleGameEffectTarget target) {
      return target.getGoldOre();
    },
    description: 'Get as much gold ore as you can in a single run.',
    unique: false,
  ),

  /// Progress: total refined gold (never reset).
  AchievementDefinition(
    id: 'total_gold',
    name: 'King Midas',
    baseTarget: 1.0,
    progressFn: (IdleGameEffectTarget target) {
      return target.getTotalRefinedGold();
    },
    description: 'Earn as much gold as possible.',
    unique: false,
  ),

  // ===== Lux Aurea collection achievements =====

  AchievementDefinition(
    id: 'lux_aurea_first_card',
    name: 'Shiny Collector',
    baseTarget: 1.0,
    progressFn: (IdleGameEffectTarget target) {
      final cards = target.getAllOwnedCards();
      int count = 0;

      for (final owned in cards) {
        final template = CardCatalog.getById(owned.cardId);
        if (template != null && template.packId == 'lux_aurea') {
          count++;
        }
      }

      return count.toDouble();
    },
    description: 'Get your first Lux Aurea card.',
    unique: true,
  ),

  AchievementDefinition(
    id: 'lux_aurea_third_card',
    name: 'Shiny Owner',
    baseTarget: 3.0,
    progressFn: (IdleGameEffectTarget target) {
      final cards = target.getAllOwnedCards();
      int count = 0;

      for (final owned in cards) {
        final template = CardCatalog.getById(owned.cardId);
        if (template != null && template.packId == 'lux_aurea') {
          count++;
        }
      }

      return count.toDouble();
    },
    description: 'Have 3 Lux Aurea Cards',
    unique: true,
  ),

  AchievementDefinition(
    id: 'lux_aurea_completion',
    name: 'Shiny Completionist',
    baseTarget: 11.0,
    progressFn: (IdleGameEffectTarget target) {
      final cards = target.getAllOwnedCards();
      int count = 0;

      for (final owned in cards) {
        final template = CardCatalog.getById(owned.cardId);
        if (template != null && template.packId == 'lux_aurea') {
          count++;
        }
      }

      return count.toDouble();
    },
    description: 'Add all Lux Aurea cards to your collection.',
    unique: true,
  ),

  AchievementDefinition(
    id: 'lux_aurea_unique',
    name: 'A Rare Shiny',
    baseTarget: 1.0,
    progressFn: (IdleGameEffectTarget target) {
      final cards = target.getAllOwnedCards();
      int count = 0;

      for (final owned in cards) {
        final template = CardCatalog.getById(owned.cardId);
        if (template != null &&
            template.rank < 0 &&
            template.packId == 'lux_aurea') {
          count++;
        }
      }

      return count.toDouble();
    },
    description: 'Find the special Lux Aurea card.',
    unique: true,
  ),

  // ===== Vita Orum collection achievements =====

  AchievementDefinition(
    id: 'vita_orum_first_card',
    name: 'Rock Collector',
    baseTarget: 1.0,
    progressFn: (IdleGameEffectTarget target) {
      final cards = target.getAllOwnedCards();
      int count = 0;

      for (final owned in cards) {
        final template = CardCatalog.getById(owned.cardId);
        if (template != null && template.packId == 'vita_orum') {
          count++;
        }
      }

      return count.toDouble();
    },
    description: 'Get your first Vita Orum card.',
    unique: true,
  ),

  AchievementDefinition(
    id: 'vita_orum_third_card',
    name: 'Rock Specialist',
    baseTarget: 3.0,
    progressFn: (IdleGameEffectTarget target) {
      final cards = target.getAllOwnedCards();
      int count = 0;

      for (final owned in cards) {
        final template = CardCatalog.getById(owned.cardId);
        if (template != null && template.packId == 'vita_orum') {
          count++;
        }
      }

      return count.toDouble();
    },
    description: 'Own 3 Vita Orum cards.',
    unique: true,
  ),

  AchievementDefinition(
    id: 'vita_orum_completion',
    name: 'Rock Completionist',
    baseTarget: 11.0,
    progressFn: (IdleGameEffectTarget target) {
      final cards = target.getAllOwnedCards();
      int count = 0;

      for (final owned in cards) {
        final template = CardCatalog.getById(owned.cardId);
        if (template != null && template.packId == 'vita_orum') {
          count++;
        }
      }

      return count.toDouble();
    },
    description: 'Add all Vita Orum cards to your collection.',
    unique: true,
  ),

  AchievementDefinition(
    id: 'vita_orum_unique',
    name: 'A Rare Pebble',
    baseTarget: 1.0,
    progressFn: (IdleGameEffectTarget target) {
      final cards = target.getAllOwnedCards();
      int count = 0;

      for (final owned in cards) {
        final template = CardCatalog.getById(owned.cardId);
        if (template != null &&
            template.rank < 0 &&
            template.packId == 'vita_orum') {
          count++;
        }
      }

      return count.toDouble();
    },
    description: 'Find the special Vita Orum card.',
    unique: true,
  ),

  // ===== Chrono Epoch collection achievements =====

  AchievementDefinition(
    id: 'chrono_epoch_first_card',
    name: 'Procrastinator',
    baseTarget: 1.0,
    progressFn: (IdleGameEffectTarget target) {
      final cards = target.getAllOwnedCards();
      int count = 0;

      for (final owned in cards) {
        final template = CardCatalog.getById(owned.cardId);
        if (template != null && template.packId == 'chrono_epoch') {
          count++;
        }
      }

      return count.toDouble();
    },
    description: 'Get your first Chrono Epoch card.',
    unique: true,
  ),

  // FIXED: this used to share the same id as the first card achievement.
  AchievementDefinition(
    id: 'chrono_epoch_third_card',
    name: 'Hourglass Maker',
    baseTarget: 3.0,
    progressFn: (IdleGameEffectTarget target) {
      final cards = target.getAllOwnedCards();
      int count = 0;

      for (final owned in cards) {
        final template = CardCatalog.getById(owned.cardId);
        if (template != null && template.packId == 'chrono_epoch') {
          count++;
        }
      }

      return count.toDouble();
    },
    description: 'Own 3 Chrono Epoch cards.',
    unique: true,
  ),

  AchievementDefinition(
    id: 'chrono_epoch_completion',
    name: 'Master of Time',
    baseTarget: 11.0,
    progressFn: (IdleGameEffectTarget target) {
      final cards = target.getAllOwnedCards();
      int count = 0;

      for (final owned in cards) {
        final template = CardCatalog.getById(owned.cardId);
        if (template != null && template.packId == 'chrono_epoch') {
          count++;
        }
      }

      return count.toDouble();
    },
    description: 'Add all Chrono Epoch cards to your collection.',
    unique: true,
  ),

  AchievementDefinition(
    id: 'chrono_epoch_unique',
    name: 'A Special Moment',
    baseTarget: 1.0,
    progressFn: (IdleGameEffectTarget target) {
      final cards = target.getAllOwnedCards();
      int count = 0;

      for (final owned in cards) {
        final template = CardCatalog.getById(owned.cardId);
        if (template != null &&
            template.rank < 0 &&
            template.packId == 'chrono_epoch') {
          count++;
        }
      }

      return count.toDouble();
    },
    description: 'Find the special Chrono Epoch card.',
    unique: true,
  ),

  // ===== NEW: click-cycle / click-count achievements =====

  /// Total click cycles across all time (uses getTotalManualClickCycles()).
  AchievementDefinition(
    id: 'total_click_cycles',
    name: 'Nuggs for Days',
    baseTarget: 1.0,
    progressFn: (IdleGameEffectTarget target) {
      final dyn = target as dynamic;
      final double cycles = dyn.getTotalManualClickCycles() as double;
      return cycles;
    },
    description: 'Get as much gold as possible from manually exposing gold nuggets across all rebirths.',
    unique: false,
  ),

  /// Click cycles within a single run (uses getManualClickCycles()).
  AchievementDefinition(
    id: 'run_click_cycles',
    name: 'Nuggety Goodness',
    baseTarget: 1.0,
    progressFn: (IdleGameEffectTarget target) {
      final dyn = target as dynamic;
      final double cycles = dyn.getManualClickCycles() as double;
      return cycles;
    },
    description: 'Get as much gold as possible from manually exposing gold nuggets in a single run.',
    unique: false,
  ),

  /// Total physical clicks across all time (uses getTotalClicks()).
  AchievementDefinition(
    id: 'total_clicks',
    name: 'Click Machine',
    baseTarget: 10.0,
    progressFn: (IdleGameEffectTarget target) {
      final dyn = target as dynamic;
      final int clicks = dyn.getTotalClicks() as int;
      return clicks.toDouble();
    },
    description: 'Click the rock an absurd number of times.',
    unique: false,
  ),

  /// Physical clicks within a single run (uses getClicksThisRun()).
  AchievementDefinition(
    id: 'run_clicks',
    name: 'Finger Workout',
    baseTarget: 10.0,
    progressFn: (IdleGameEffectTarget target) {
      final dyn = target as dynamic;
      final int clicks = dyn.getClicksThisRun() as int;
      return clicks.toDouble();
    },
    description: 'Click the rock many times in a single run.',
    unique: false,
  ),

  // ===== NEW: card-upgrade achievements =====

  /// Number of upgrades for a single card: max(level - baseLevel).
  AchievementDefinition(
    id: 'single_card_upgrades',
    name: 'Focused Training',
    baseTarget: 1.0,
    progressFn: (IdleGameEffectTarget target) {
      return _maxUpgradesForAnyCard(target);
    },
    description: 'Train a single card through many level-ups.',
    unique: false,
  ),

  /// Total card upgrades across all cards: sum(level - baseLevel).
  AchievementDefinition(
    id: 'total_card_upgrades',
    name: 'Broad Curriculum',
    baseTarget: 1.0,
    progressFn: (IdleGameEffectTarget target) {
      return _totalCardUpgrades(target);
    },
    description: 'Level up your entire collection.',
    unique: false,
  ),

  // ===== NEW: rarity achievements (1, 3, 10 cards of each rarity 1–10 plus unique) =====

  // Rarity 1
  AchievementDefinition(
    id: 'rarity_1_one',
    name: 'First Rank 1 Find',
    baseTarget: 1.0,
    progressFn: (IdleGameEffectTarget target) {
      return _countCardsOfRarity(target, 1);
    },
    description: 'Find a rank 1 card.',
    unique: true,
  ),
  AchievementDefinition(
    id: 'rarity_1_three',
    name: 'Rank 1 Trio',
    baseTarget: 3.0,
    progressFn: (IdleGameEffectTarget target) {
      return _countCardsOfRarity(target, 1);
    },
    description: 'Own 3 rank 1 cards.',
    unique: true,
  ),
  AchievementDefinition(
    id: 'rarity_1_ten',
    name: 'Rank 1 Hoarder',
    baseTarget: 10.0,
    progressFn: (IdleGameEffectTarget target) {
      return _countCardsOfRarity(target, 1);
    },
    description: 'Own 10 rank 1 cards.',
    unique: true,
  ),

  // Rarity 2
  AchievementDefinition(
    id: 'rarity_2_one',
    name: 'First Rank 2 Find',
    baseTarget: 1.0,
    progressFn: (IdleGameEffectTarget target) {
      return _countCardsOfRarity(target, 2);
    },
    description: 'Find a rank 2 card.',
    unique: true,
  ),
  AchievementDefinition(
    id: 'rarity_2_three',
    name: 'Rank 2 Trio',
    baseTarget: 3.0,
    progressFn: (IdleGameEffectTarget target) {
      return _countCardsOfRarity(target, 2);
    },
    description: 'Own 3 rank 2 cards.',
    unique: true,
  ),
  AchievementDefinition(
    id: 'rarity_2_ten',
    name: 'Rank 2 Hoarder',
    baseTarget: 10.0,
    progressFn: (IdleGameEffectTarget target) {
      return _countCardsOfRarity(target, 2);
    },
    description: 'Own 10 rank 2 cards.',
    unique: true,
  ),

  // Rarity 3
  AchievementDefinition(
    id: 'rarity_3_one',
    name: 'First Rank 3 Find',
    baseTarget: 1.0,
    progressFn: (IdleGameEffectTarget target) {
      return _countCardsOfRarity(target, 3);
    },
    description: 'Find a rank 3 card.',
    unique: true,
  ),
  AchievementDefinition(
    id: 'rarity_3_three',
    name: 'Rank 3 Trio',
    baseTarget: 3.0,
    progressFn: (IdleGameEffectTarget target) {
      return _countCardsOfRarity(target, 3);
    },
    description: 'Own 3 rank 3 cards.',
    unique: true,
  ),
  AchievementDefinition(
    id: 'rarity_3_ten',
    name: 'Rank 3 Hoarder',
    baseTarget: 10.0,
    progressFn: (IdleGameEffectTarget target) {
      return _countCardsOfRarity(target, 3);
    },
    description: 'Own 10 rank 3 cards.',
    unique: true,
  ),

  // Rarity 4
  AchievementDefinition(
    id: 'rarity_4_one',
    name: 'First Rank 4 Find',
    baseTarget: 1.0,
    progressFn: (IdleGameEffectTarget target) {
      return _countCardsOfRarity(target, 4);
    },
    description: 'Find a rank 4 card.',
    unique: true,
  ),
  AchievementDefinition(
    id: 'rarity_4_three',
    name: 'Rank 4 Trio',
    baseTarget: 3.0,
    progressFn: (IdleGameEffectTarget target) {
      return _countCardsOfRarity(target, 4);
    },
    description: 'Own 3 rank 4 cards.',
    unique: true,
  ),
  AchievementDefinition(
    id: 'rarity_4_ten',
    name: 'Rank 4 Hoarder',
    baseTarget: 10.0,
    progressFn: (IdleGameEffectTarget target) {
      return _countCardsOfRarity(target, 4);
    },
    description: 'Own 10 rank 4 cards.',
    unique: true,
  ),

  // Rarity 5
  AchievementDefinition(
    id: 'rarity_5_one',
    name: 'First Rank 5 Find',
    baseTarget: 1.0,
    progressFn: (IdleGameEffectTarget target) {
      return _countCardsOfRarity(target, 5);
    },
    description: 'Find a rank 5 card.',
    unique: true,
  ),
  AchievementDefinition(
    id: 'rarity_5_three',
    name: 'Rank 5 Trio',
    baseTarget: 3.0,
    progressFn: (IdleGameEffectTarget target) {
      return _countCardsOfRarity(target, 5);
    },
    description: 'Own 3 rank 5 cards.',
    unique: true,
  ),
  AchievementDefinition(
    id: 'rarity_5_ten',
    name: 'Rank 5 Hoarder',
    baseTarget: 10.0,
    progressFn: (IdleGameEffectTarget target) {
      return _countCardsOfRarity(target, 5);
    },
    description: 'Own 10 rank 5 cards.',
    unique: true,
  ),

  // Rarity 6
  AchievementDefinition(
    id: 'rarity_6_one',
    name: 'First Rank 6 Find',
    baseTarget: 1.0,
    progressFn: (IdleGameEffectTarget target) {
      return _countCardsOfRarity(target, 6);
    },
    description: 'Find a rank 6 card.',
    unique: true,
  ),
  AchievementDefinition(
    id: 'rarity_6_three',
    name: 'Rank 6 Trio',
    baseTarget: 3.0,
    progressFn: (IdleGameEffectTarget target) {
      return _countCardsOfRarity(target, 6);
    },
    description: 'Own 3 rank 6 cards.',
    unique: true,
  ),
  AchievementDefinition(
    id: 'rarity_6_ten',
    name: 'Rank 6 Hoarder',
    baseTarget: 10.0,
    progressFn: (IdleGameEffectTarget target) {
      return _countCardsOfRarity(target, 6);
    },
    description: 'Own 10 rank 6 cards.',
    unique: true,
  ),

  // Rarity 7
  AchievementDefinition(
    id: 'rarity_7_one',
    name: 'First Rank 7 Find',
    baseTarget: 1.0,
    progressFn: (IdleGameEffectTarget target) {
      return _countCardsOfRarity(target, 7);
    },
    description: 'Find a rank 7 card.',
    unique: true,
  ),
  AchievementDefinition(
    id: 'rarity_7_three',
    name: 'Rank 7 Trio',
    baseTarget: 3.0,
    progressFn: (IdleGameEffectTarget target) {
      return _countCardsOfRarity(target, 7);
    },
    description: 'Own 3 rank 7 cards.',
    unique: true,
  ),
  AchievementDefinition(
    id: 'rarity_7_ten',
    name: 'Rank 7 Hoarder',
    baseTarget: 10.0,
    progressFn: (IdleGameEffectTarget target) {
      return _countCardsOfRarity(target, 7);
    },
    description: 'Own 10 rank 7 cards.',
    unique: true,
  ),

  // Rarity 8
  AchievementDefinition(
    id: 'rarity_8_one',
    name: 'First Rank 8 Find',
    baseTarget: 1.0,
    progressFn: (IdleGameEffectTarget target) {
      return _countCardsOfRarity(target, 8);
    },
    description: 'Find a rank 8 card.',
    unique: true,
  ),
  AchievementDefinition(
    id: 'rarity_8_three',
    name: 'Rank 8 Trio',
    baseTarget: 3.0,
    progressFn: (IdleGameEffectTarget target) {
      return _countCardsOfRarity(target, 8);
    },
    description: 'Own 3 rank 8 cards.',
    unique: true,
  ),
  AchievementDefinition(
    id: 'rarity_8_ten',
    name: 'Rank 8 Hoarder',
    baseTarget: 10.0,
    progressFn: (IdleGameEffectTarget target) {
      return _countCardsOfRarity(target, 8);
    },
    description: 'Own 10 rank 8 cards.',
    unique: true,
  ),

  // Rarity 9
  AchievementDefinition(
    id: 'rarity_9_one',
    name: 'First Rank 9 Find',
    baseTarget: 1.0,
    progressFn: (IdleGameEffectTarget target) {
      return _countCardsOfRarity(target, 9);
    },
    description: 'Find a rank 9 card.',
    unique: true,
  ),
  AchievementDefinition(
    id: 'rarity_9_three',
    name: 'Rank 9 Trio',
    baseTarget: 3.0,
    progressFn: (IdleGameEffectTarget target) {
      return _countCardsOfRarity(target, 9);
    },
    description: 'Own 3 rank 9 cards.',
    unique: true,
  ),
  AchievementDefinition(
    id: 'rarity_9_ten',
    name: 'Rank 9 Hoarder',
    baseTarget: 10.0,
    progressFn: (IdleGameEffectTarget target) {
      return _countCardsOfRarity(target, 9);
    },
    description: 'Own 10 rank 9 cards.',
    unique: true,
  ),

  // Rarity 10
  AchievementDefinition(
    id: 'rarity_10_one',
    name: 'First Rank 10 Find',
    baseTarget: 1.0,
    progressFn: (IdleGameEffectTarget target) {
      return _countCardsOfRarity(target, 10);
    },
    description: 'Find a rank 10 card.',
    unique: true,
  ),
  AchievementDefinition(
    id: 'rarity_10_three',
    name: 'Rank 10 Trio',
    baseTarget: 3.0,
    progressFn: (IdleGameEffectTarget target) {
      return _countCardsOfRarity(target, 10);
    },
    description: 'Own 3 rank 10 cards.',
    unique: true,
  ),
  AchievementDefinition(
    id: 'rarity_10_ten',
    name: 'Rank 10 Hoarder',
    baseTarget: 10.0,
    progressFn: (IdleGameEffectTarget target) {
      return _countCardsOfRarity(target, 10);
    },
    description: 'Own 10 rank 10 cards.',
    unique: true,
  ),

  // Unique rarity (rank < 0)
  AchievementDefinition(
    id: 'rarity_unique_one',
    name: 'First Unique Find',
    baseTarget: 1.0,
    progressFn: (IdleGameEffectTarget target) {
      return _countUniqueCards(target);
    },
    description: 'Find a unique card.',
    unique: true,
  ),
  AchievementDefinition(
    id: 'rarity_unique_three',
    name: 'Unique Trio',
    baseTarget: 3.0,
    progressFn: (IdleGameEffectTarget target) {
      return _countUniqueCards(target);
    },
    description: 'Own 3 unique cards.',
    unique: true,
  ),
  AchievementDefinition(
    id: 'rarity_unique_ten',
    name: 'Unique Hoarder',
    baseTarget: 10.0,
    progressFn: (IdleGameEffectTarget target) {
      return _countUniqueCards(target);
    },
    description: 'Own 10 unique cards.',
    unique: true,
  ),
];
