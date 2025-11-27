import 'dart:math' as math;

/// Central place for all card effect formulas.
///
/// These helpers implement a generic "upgrade card" behavior:
///
///   Resources per tick:     level * 10^(rank - 1)
///   Cost scaling factor:    1 + 9 / level
///   Base cost:              10^(rank * (1 + 0.99^level))
///   Exp to next level:      (level + 1)^3
///
/// Any card (Lux Aurea or otherwise) that follows this pattern
/// can use these functions directly.
class CardEffects {
  /// Resources per tick for an upgrade-style card.
  static double resourcesPerTick({
    required int rank,
    required int level,
  }) {
    // level * 10^(rank - 1)
    return level * math.pow(10, rank - 1).toDouble();
  }

  /// Cost scaling factor for upgrade-style cards.
  static double costScalingFactor({
    required int level,
  }) {
    // 1 + 9 / level
    if (level <= 0) return double.infinity; // avoid division by zero
    return 1.0 + 9.0 / level;
  }

  /// Base cost for upgrade-style cards.
  static double baseCost({
    required int rank,
    required int level,
  }) {
    // 10^(rank * (1 + 0.99^level))
    final inner = rank * (1 + math.pow(0.99, level).toDouble());
    return math.pow(10, inner).toDouble();
  }

  /// Experience required to reach the next level.
  static int expToNextLevel({
    required int level,
  }) {
    // (level + 1)^3
    final nextLevel = level + 1;
    return math.pow(nextLevel, 3).toInt();
  }
}
