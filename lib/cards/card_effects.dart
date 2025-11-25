import 'dart:math' as math;

/// Central place for all card effect formulas.
///
/// For Lux Aurea cards, the intended behavior is:
///   Resources per tick:     level * 10^(rank - 1)
///   Cost scaling factor:    1 + 9 / level
///   Base cost:              10^(rank * (1 + 0.99^level))
///   Exp to next level:      (level + 1)^3
///
/// Game logic should call these helpers whenever it needs to
/// evaluate what a card does at a given level.
class CardEffects {
  /// Resources per tick for Lux Aurea upgrade cards.
  static double luxAureaResourcesPerTick({
    required int rank,
    required int level,
  }) {
    // level * 10^(rank - 1)
    return level * math.pow(10, rank - 1).toDouble();
  }

  /// Cost scaling factor for Lux Aurea upgrade cards.
  static double luxAureaCostScalingFactor({
    required int level,
  }) {
    // 1 + 9 / level
    if (level <= 0) return double.infinity; // avoid division by zero
    return 1.0 + 9.0 / level;
  }

  /// Base cost for Lux Aurea upgrade cards.
  static double luxAureaBaseCost({
    required int rank,
    required int level,
  }) {
    // 10^(rank * (1 + 0.99^level))
    final inner = rank * (1 + math.pow(0.99, level).toDouble());
    return math.pow(10, inner).toDouble();
  }

  /// Experience required to reach the next level for Lux Aurea cards.
  static int luxAureaExpToNextLevel({
    required int level,
  }) {
    // (level + 1)^3
    final nextLevel = level + 1;
    return math.pow(nextLevel, 3).toInt();
  }
}
