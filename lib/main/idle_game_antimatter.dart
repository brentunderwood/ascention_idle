// ==================================
// idle_game_antimatter.dart (FULL FILE)
// ==================================
part of 'idle_game_screen.dart';

/// ✅ FIXED: no `on _IdleGameScreenState` constraint (prevents self-superinterface cycle).
mixin IdleGameAntimatterMixin on State<IdleGameScreen> {
  _IdleGameScreenState get _s => this as _IdleGameScreenState;

  /// Evaluate the antimatter polynomial for `seconds`, applying `stepMultiplier`
  /// to *every step* of the polynomial propagation (i+1 -> i) AND to the final
  /// degree-0 output conversion.
  ///
  /// This makes multipliers affect not just the displayed APS, but also the
  /// internal polynomial state, so growth compounds as expected.
  double _evaluateAntimatterPolynomial({
    int seconds = 1,
    required double stepMultiplier,
  }) {
    if (_s._antimatterPolynomial.isEmpty) return 0.0;
    if (seconds <= 0) return 0.0;

    final double mult =
    (stepMultiplier.isFinite && stepMultiplier > 0) ? stepMultiplier : 1.0;

    // Apply the multiplier to EACH "integration step" from higher degree -> lower degree.
    // Note: we keep the underlying polynomial integers as ints, so we quantize via toInt().
    for (int i = 0; i < _s._antimatterPolynomial.length - 1; i++) {
      final int nextCoeff = _s._antimatterPolynomial[i + 1];
      final double nextScalar = _s._antimatterPolynomialScalars[i + 1];

      final double delta =
          nextCoeff.toDouble() * nextScalar * seconds.toDouble() * mult;

      _s._antimatterPolynomial[i] += delta.toInt();
    }

    // Final "output" conversion (degree 0 -> antimatter/sec) also gets multiplied.
    final double baseOut =
    (_s._antimatterPolynomial[0] * _s._antimatterPolynomialScalars[0])
        .toDouble();

    return baseOut * mult;
  }

  void _tickAntimatterSecond({required int seconds}) {
    if (_s._gameMode != 'antimatter') return;
    if (seconds <= 0) return;

    _s.setState(() {
      // Earn antimatter based on the LAST computed effective APS.
      // (Matches your current approach; APS updates for subsequent ticks.)
      _s._antimatter += _s._antimatterPerSecond * seconds;

      // Use the game's current overall multiplier stack (includes achievement/hunter/etc).
      final double overall =
      (_s._overallMultiplier.isFinite && _s._overallMultiplier > 0)
          ? _s._overallMultiplier
          : 1.0;

      // Compute the NEW effective APS, with multipliers applied per-step to the polynomial.
      final double effectiveAps = _evaluateAntimatterPolynomial(
        seconds: seconds,
        stepMultiplier: overall,
      );

      // Store effective APS so the top bar displays the true earned/sec amount.
      _s._antimatterPerSecond = effectiveAps;

      // Pending dark matter accumulation.
      _s._pendingDarkMatter +=
          seconds * factorialConversion(_s._antimatter) / math.pow(10, 10);
    });
  }

  @override
  void updateAntimatterPolynomialScalars(int degree, int coefficient) {
    if (degree < 0) return;

    if (degree >= _s._antimatterPolynomialScalars.length) {
      final int toAdd = degree + 1 - _s._antimatterPolynomialScalars.length;
      _s._antimatterPolynomialScalars.addAll(List<double>.filled(toAdd, 1.0));
    }
    _s._antimatterPolynomialScalars[degree] = coefficient.toDouble();

    if (degree >= _s._antimatterPolynomial.length) {
      _s._antimatterPolynomial.addAll(
        List<int>.filled(degree + 1 - _s._antimatterPolynomial.length, 1),
      );
    }

    _s._saveProgress();
  }
}
