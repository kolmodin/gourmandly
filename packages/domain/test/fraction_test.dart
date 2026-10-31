import 'package:domain/domain.dart';
import 'package:glados/glados.dart';

import 'support/generators.dart';

void main() {
  group('construction', () {
    test('reduces to lowest terms', () {
      expect(Fraction(6, 8), Fraction(3, 4));
      expect(Fraction(6, 8).numerator, BigInt.from(3));
      expect(Fraction(6, 8).denominator, BigInt.from(4));
    });

    test('keeps the sign on the numerator', () {
      expect(Fraction(1, -2).numerator, BigInt.from(-1));
      expect(Fraction(1, -2).denominator, BigInt.two);
      expect(Fraction(-1, -2), Fraction(1, 2));
    });

    test('normalizes zero', () {
      expect(Fraction(0, 5), Fraction.zero);
      expect(Fraction(0, 5).denominator, BigInt.one);
    });

    test('defaults to a whole number', () {
      expect(Fraction(3), Fraction(3, 1));
    });

    test('rejects a zero denominator', () {
      expect(() => Fraction(1, 0), throwsArgumentError);
    });
  });

  group('arithmetic', () {
    test('examples', () {
      expect(Fraction(1, 3) * Fraction(2), Fraction(2, 3));
      expect(Fraction(1, 2) + Fraction(1, 3), Fraction(5, 6));
      expect(Fraction(1, 2) - Fraction(1, 3), Fraction(1, 6));
      expect(Fraction(1, 2) / Fraction(1, 4), Fraction(2));
    });

    test('division by zero is an error', () {
      expect(() => Fraction(1) / Fraction.zero, throwsArgumentError);
    });

    test('stays exact far beyond the range of a double', () {
      final huge = Fraction.big(BigInt.two.pow(200) + BigInt.one, BigInt.one);
      expect(huge - Fraction.big(BigInt.two.pow(200), BigInt.one), Fraction(1));
    });

    Glados2(any.fraction, any.fraction).test('addition commutes', (a, b) {
      expect(a + b, b + a);
    });

    Glados3(any.fraction, any.fraction, any.fraction).test(
      'addition associates',
      (a, b, c) {
        expect((a + b) + c, a + (b + c));
      },
    );

    Glados3(any.fraction, any.fraction, any.fraction).test(
      'multiplication distributes over addition',
      (a, b, c) {
        expect(a * (b + c), a * b + a * c);
      },
    );

    Glados2(any.fraction, any.fraction).test('subtraction undoes addition', (
      a,
      b,
    ) {
      expect(a + b - b, a);
    });

    Glados2(any.fraction, any.positiveFraction).test(
      'division undoes multiplication',
      (a, b) {
        expect(a * b / b, a);
      },
    );
  });

  group('comparison', () {
    test('examples', () {
      expect(Fraction(1, 3) < Fraction(1, 2), isTrue);
      expect(Fraction(1, 2) <= Fraction(2, 4), isTrue);
      expect(Fraction(3, 2) > Fraction(1), isTrue);
      expect(Fraction(3, 2) >= Fraction(2), isFalse);
      expect(Fraction(-1, 2).compareTo(Fraction(1, 2)), lessThan(0));
    });

    test('min and max', () {
      expect(Fraction(1, 2).atLeast(Fraction(2, 3)), Fraction(2, 3));
      expect(Fraction(1, 2).atLeast(Fraction(1, 3)), Fraction(1, 2));
    });

    Glados2(any.fraction, any.fraction).test('agrees with the double values', (
      a,
      b,
    ) {
      expect(a.compareTo(b).sign, a.toDouble().compareTo(b.toDouble()).sign);
    });
  });

  group('equality', () {
    test('equal fractions have equal hash codes', () {
      expect(Fraction(2, 4).hashCode, Fraction(1, 2).hashCode);
    });

    test('is not equal to other types', () {
      expect(Fraction(1) == (1 as Object), isFalse);
    });
  });

  test('toString', () {
    expect(Fraction(3, 4).toString(), '3/4');
    expect(Fraction(2).toString(), '2');
  });

  test('isWhole', () {
    expect(Fraction(4, 2).isWhole, isTrue);
    expect(Fraction(1, 2).isWhole, isFalse);
  });

  group('display', () {
    test('whole numbers', () {
      expect(Fraction(3).display, '3');
      expect(Fraction.zero.display, '0');
    });

    test('common fractions use their single glyph', () {
      expect(Fraction(1, 2).display, '½');
      expect(Fraction(1, 3).display, '⅓');
      expect(Fraction(2, 3).display, '⅔');
      expect(Fraction(1, 4).display, '¼');
      expect(Fraction(3, 4).display, '¾');
      expect(Fraction(1, 8).display, '⅛');
    });

    test('mixed numbers', () {
      expect(Fraction(3, 2).display, '1 ½');
      expect(Fraction(7, 3).display, '2 ⅓');
    });

    test('fractions without a glyph are spelled out', () {
      expect(Fraction(3, 7).display, '3/7');
      expect(Fraction(17, 7).display, '2 3/7');
    });

    test('negative values keep their sign in front', () {
      expect(Fraction(-3, 2).display, '-1 ½');
    });
  });
}
