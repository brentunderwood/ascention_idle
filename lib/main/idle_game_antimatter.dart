// ==================================
// idle_game_antimatter.dart (FULL FILE)
// ==================================
part of 'idle_game_screen.dart';

/// ✅ FIXED: no `on _IdleGameScreenState` constraint (prevents self-superinterface cycle).
mixin IdleGameAntimatterMixin on State<IdleGameScreen> {
  _IdleGameScreenState get _s => this as _IdleGameScreenState;

  double _evaluateAntimatterPolynomial({int seconds = 1}) {
    if (_s._antimatterPolynomial.isEmpty) return 0.0;

    for (int i = 0; i < _s._antimatterPolynomial.length - 1; i++) {
      _s._antimatterPolynomial[i] += (_s._antimatterPolynomial[i + 1] *
          _s._antimatterPolynomialScalars[i + 1] *
          seconds)
          .toInt();
    }
    return (_s._antimatterPolynomial[0] * _s._antimatterPolynomialScalars[0]).toDouble();
  }

  void _tickAntimatterSecond({required int seconds}) {
    if (_s._gameMode != 'antimatter') return;
    if (seconds <= 0) return;

    _s.setState(() {
      _s._antimatter += _s._antimatterPerSecond * seconds;

      final double delta = _evaluateAntimatterPolynomial(seconds: seconds);
      _s._antimatterPerSecond = delta;

      // Pending dark matter accumulation.
      _s._pendingDarkMatter += seconds * factorialConversion(_s._antimatter) / math.pow(10, 10);
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
