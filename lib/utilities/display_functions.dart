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
    // For small values, just show as integer.
    return value.toStringAsFixed(0);
  }

  return '${scaled.toStringAsFixed(2)}$suffix';
}
