/// An exact rational number in lowest terms, with the sign on the numerator.
///
/// Uses [BigInt] because on the web Dart's `int` is a JavaScript double, which
/// would make arithmetic inexact at large values.
final class Fraction implements Comparable<Fraction> {
  const Fraction._(this.numerator, this.denominator);

  factory Fraction(int numerator, [int denominator = 1]) =>
      Fraction.big(BigInt.from(numerator), BigInt.from(denominator));

  factory Fraction.big(BigInt numerator, BigInt denominator) {
    if (denominator == BigInt.zero) {
      throw ArgumentError.value(denominator, 'denominator', 'must not be zero');
    }
    final gcd = numerator.gcd(denominator);
    final sign = denominator.isNegative ? -BigInt.one : BigInt.one;
    return Fraction._(sign * numerator ~/ gcd, sign * denominator ~/ gcd);
  }

  static final zero = Fraction(0);
  static final one = Fraction(1);

  final BigInt numerator;
  final BigInt denominator;

  Fraction operator +(Fraction other) => Fraction.big(
    numerator * other.denominator + other.numerator * denominator,
    denominator * other.denominator,
  );

  Fraction operator -(Fraction other) => Fraction.big(
    numerator * other.denominator - other.numerator * denominator,
    denominator * other.denominator,
  );

  Fraction operator *(Fraction other) => Fraction.big(
    numerator * other.numerator,
    denominator * other.denominator,
  );

  Fraction operator /(Fraction other) => Fraction.big(
    numerator * other.denominator,
    denominator * other.numerator,
  );

  bool operator <(Fraction other) => compareTo(other) < 0;
  bool operator <=(Fraction other) => compareTo(other) <= 0;
  bool operator >(Fraction other) => compareTo(other) > 0;
  bool operator >=(Fraction other) => compareTo(other) >= 0;

  /// This value, or [floor] if that is larger.
  Fraction atLeast(Fraction floor) => this < floor ? floor : this;

  bool get isWhole => denominator == BigInt.one;

  double toDouble() => numerator / denominator;

  /// For people: a mixed number with a fraction glyph where one exists, like
  /// `1 ½`, or spelled out otherwise, like `2 3/7`.
  String get display {
    final sign = numerator.isNegative ? '-' : '';
    final magnitude = numerator.abs();
    final whole = magnitude ~/ denominator;
    final rest = magnitude % denominator;
    if (rest == BigInt.zero) return '$sign$whole';
    final part = _glyphs['$rest/$denominator'] ?? '$rest/$denominator';
    return whole == BigInt.zero ? '$sign$part' : '$sign$whole $part';
  }

  @override
  int compareTo(Fraction other) =>
      (numerator * other.denominator).compareTo(other.numerator * denominator);

  @override
  bool operator ==(Object other) =>
      other is Fraction &&
      numerator == other.numerator &&
      denominator == other.denominator;

  @override
  int get hashCode => Object.hash(numerator, denominator);

  @override
  String toString() => isWhole ? '$numerator' : '$numerator/$denominator';
}

const _glyphs = {
  '1/2': '½',
  '1/3': '⅓',
  '2/3': '⅔',
  '1/4': '¼',
  '3/4': '¾',
  '1/5': '⅕',
  '2/5': '⅖',
  '3/5': '⅗',
  '4/5': '⅘',
  '1/6': '⅙',
  '5/6': '⅚',
  '1/8': '⅛',
  '3/8': '⅜',
  '5/8': '⅝',
  '7/8': '⅞',
};
