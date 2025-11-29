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
  /// Target growth: 100, 1,000, 10,000, ...
  AchievementDefinition(
    id: 'rebirth_count',
    name: 'Born Again Fanatic',
    baseTarget: 1.0,
    progressFn: (IdleGameEffectTarget target) {
      return target.getRebirthCount().toDouble();
    },
    description:
    'Rebirth. Again, and again, and again.',
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
    description:
    'Collect a lot of gold before you rebirth.',
    unique: false,
  ),

  /// Progress: ore per second (effective base, not including multipliers
  /// baked into _overallMultiplier).
  AchievementDefinition(
    id: 'ore_per_second',
    name: 'Big Bad John',
    baseTarget: 1.0,
    progressFn: (IdleGameEffectTarget target) {
      return target.getOrePerSecond();
    },
    description:
    'Get as much ore per second as you can (not counting bonus multipliers).',
    unique: false,
  ),

  /// Progress: current gold (refined currency).
  AchievementDefinition(
    id: 'total_gold',
    name: 'King Midas',
    baseTarget: 1.0,
    progressFn: (IdleGameEffectTarget target) {
      return target.getTotalRefinedGold();
    },
    description:
    'Earn as much gold as possible.',
    unique: false,
  ),

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
    description:
    'Get your first Lux Aurea card.',
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
    description:
    'Add all Lux Aurea cards to your collection.',
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
        if (template != null && template.rank < 0 && template.packId == 'lux_aurea') {
          count++;
        }
      }

      return count.toDouble();
    },
    description:
    'Find the special Lux Aurea card.',
    unique: true,
  ),

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
    description:
    'Get your first Vita Orum card.',
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
    description:
    'Add all Vita Orum cards to your collection.',
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
        if (template != null && template.rank < 0 && template.packId == 'vita_orum') {
          count++;
        }
      }

      return count.toDouble();
    },
    description:
    'Find the special Vita Orum card.',
    unique: true,
  ),

];
