/// Utility functions for displaying numeric values in compact / word notation.
///
/// Examples:
///   1,000        -> "1.00K"
///   1,234        -> "1.23K"
///   1,000,000    -> "1.00M"
///   1,200,000    -> "1.20M"
///   5,000,000,000-> "5.00B"
///
/// Values below 1,000 are shown as whole numbers (no suffix).
String displayNumber(double value) {
  final double absValue = value.abs();
  String suffix = '';
  double scaled = value;

  // NEW: For very small values, show up to 10 decimal places (trim zeros).
  if (absValue < 1) {
    String s = value.toStringAsFixed(10);

    // Trim trailing zeros
    s = s.replaceFirst(RegExp(r'\.?0+$'), '');

    // Edge case: "-0" → "0"
    if (s == '-0') s = '0';

    return s;
  }

  if (absValue >= 1e12) {
    suffix = 'T';
    scaled = value / 1e12;
  } else if (absValue >= 1e9) {
    suffix = 'B';
    scaled = value / 1e9;
  } else if (absValue >= 1e6) {
    suffix = 'M';
    scaled = value / 1e6;
  } else if (absValue >= 1e3) {
    suffix = 'K';
    scaled = value / 1e3;
  } else {
    // For values between 1 and 999, just show integer.
    return value.toStringAsFixed(0);
  }

  return '${scaled.toStringAsFixed(2)}$suffix';
}


String factorialDisplay(double value) {
  String suffix = '!';
  double scaled = factorialConversion(value);

  return '${scaled.toStringAsFixed(2)}$suffix';
}

double factorialConversion(double value) {
  double num = 0;
  int divisor = 1;
  while(value > divisor){
    value /= divisor;
    divisor++;
    num++;
  }

  num += value / divisor;
  return num;
}
