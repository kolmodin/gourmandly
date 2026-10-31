import 'package:domain/domain.dart';
import 'package:glados/glados.dart';

import 'support/generators.dart';

Amount volume(int ml) => Amount.exact(BaseMeasure.volume, Fraction(ml));
Amount mass(int g) => Amount.exact(BaseMeasure.mass, Fraction(g));

void main() {
  group('Quantity.scaled', () {
    test('scales exact values', () {
      expect(Exact(Fraction(2)).scaled(Fraction(3, 2)), Exact(Fraction(3)));
    });

    test('scales both ends of a range', () {
      expect(
        Range(Fraction(1), Fraction(2)).scaled(Fraction(2)),
        Range(Fraction(2), Fraction(4)),
      );
    });

    test('leaves an unspecified quantity alone', () {
      expect(const Unspecified().scaled(Fraction(2)), const Unspecified());
    });
  });

  group('scaleFactor', () {
    test('is the ratio of target to base servings', () {
      expect(scaleFactor(from: 4, to: 8), Fraction(2));
      expect(scaleFactor(from: 4, to: 3), Fraction(3, 4));
    });

    test('an entry without a usable servings count is not scaled', () {
      expect(scaleFactor(from: 4, to: 0), Fraction.one);
    });

    test('a recipe without a usable servings count is not scaled', () {
      expect(scaleFactor(from: 0, to: 8), Fraction.one);
      expect(scaleFactor(from: -1, to: 8), Fraction.one);
    });
  });

  group('amountOf', () {
    test('converts to the base unit', () {
      expect(
        amountOf(Exact(Fraction(2)), StandardUnit.dl),
        Amount.exact(BaseMeasure.volume, Fraction(200)),
      );
      expect(
        amountOf(Exact(Fraction(1, 2)), StandardUnit.kg),
        Amount.exact(BaseMeasure.mass, Fraction(500)),
      );
    });

    test('converts both ends of a range', () {
      expect(
        amountOf(Range(Fraction(1), Fraction(2)), StandardUnit.msk),
        Amount(BaseMeasure.volume, Fraction(15), Fraction(30)),
      );
    });

    test('a quantity without a unit counts pieces', () {
      expect(
        amountOf(Exact(Fraction(2)), null),
        Amount.exact(BaseMeasure.count, Fraction(2)),
      );
    });

    test('named units are their own measure', () {
      expect(
        amountOf(Exact(Fraction(2)), const NamedUnit('klyftor')),
        Amount.exact(const NamedMeasure('klyftor'), Fraction(2)),
      );
    });

    test('an unspecified quantity has no amount, whatever the unit', () {
      expect(amountOf(const Unspecified(), null), isNull);
      expect(amountOf(const Unspecified(), StandardUnit.dl), isNull);
    });

    Glados3(any.standardUnit, any.standardUnit, any.positiveFraction).test(
      'the same physical amount gives the same result in any unit of the '
      'measure',
      (a, b, value) {
        if (a.measure != b.measure) return;
        final inB = value * a.toBase / b.toBase;
        expect(amountOf(Exact(value), a), amountOf(Exact(inB), b));
      },
    );
  });

  group('adding amounts', () {
    test('adds both ends', () {
      expect(
        Amount(BaseMeasure.volume, Fraction(100), Fraction(200)) + volume(50),
        Amount(BaseMeasure.volume, Fraction(150), Fraction(250)),
      );
    });

    test('different measures cannot be added', () {
      expect(() => volume(1) + mass(1), throwsArgumentError);
    });

    Glados2(any.nonNegativeFraction, any.nonNegativeFraction).test('commutes', (
      a,
      b,
    ) {
      final x = Amount.exact(BaseMeasure.mass, a);
      final y = Amount.exact(BaseMeasure.mass, b);
      expect(x + y, y + x);
    });
  });

  group('scaling amounts', () {
    Glados3(
      any.positiveFraction,
      any.positiveFraction,
      any.positiveFraction,
    ).test('scaling by a then b is scaling by a·b', (value, a, b) {
      final amount = Amount.exact(BaseMeasure.volume, value);
      expect(amount.scaled(a).scaled(b), amount.scaled(a * b));
    });

    Glados3(
      any.positiveFraction,
      any.positiveFraction,
      any.positiveFraction,
    ).test('scaling distributes over addition', (x, y, factor) {
      final a = Amount.exact(BaseMeasure.mass, x);
      final b = Amount.exact(BaseMeasure.mass, y);
      expect((a + b).scaled(factor), a.scaled(factor) + b.scaled(factor));
    });

    Glados2(any.positiveFraction, any.positiveFraction).test(
      'merging then scaling equals scaling a whole recipe',
      (x, f) {
        final amount = Amount(BaseMeasure.mass, x, x + Fraction(1));
        expect(amount.scaled(f).min, x * f);
        expect(amount.scaled(f).max, (x + Fraction(1)) * f);
      },
    );
  });

  group('remainingAfter', () {
    test('subtracts what has been checked', () {
      expect(mass(500).remainingAfter(Fraction(300)), mass(200));
    });

    test('nothing remains once everything is covered', () {
      expect(mass(500).remainingAfter(Fraction(500)), isNull);
      expect(mass(500).remainingAfter(Fraction(600)), isNull);
    });

    test('a range is covered only at its upper end', () {
      final range = Amount(BaseMeasure.mass, Fraction(200), Fraction(300));
      expect(range.remainingAfter(Fraction(300)), isNull);
      expect(
        range.remainingAfter(Fraction(100)),
        Amount(BaseMeasure.mass, Fraction(100), Fraction(200)),
      );
    });

    test('the lower end of a range never goes below zero', () {
      final range = Amount(BaseMeasure.mass, Fraction(200), Fraction(300));
      expect(
        range.remainingAfter(Fraction(250)),
        Amount(BaseMeasure.mass, Fraction.zero, Fraction(50)),
      );
    });

    Glados2(any.positiveFraction, any.positiveFraction).test(
      'what remains plus what was checked is the total',
      (total, c) {
        final amount = Amount.exact(BaseMeasure.mass, total);
        final remaining = amount.remainingAfter(c);
        if (c >= total) {
          expect(remaining, isNull);
        } else {
          expect(remaining!.max + c, total);
        }
      },
    );
  });

  group('formatAmount', () {
    const dl = StandardUnit.dl;
    const ml = StandardUnit.ml;
    const msk = StandardUnit.msk;
    const tsk = StandardUnit.tsk;
    const krm = StandardUnit.krm;
    const cl = StandardUnit.cl;
    const l = StandardUnit.l;
    const g = StandardUnit.g;
    const kg = StandardUnit.kg;

    test('the example from the data model', () {
      expect(formatAmount(volume(300), [dl, ml]), '3 dl');
    });

    test('keeps a spoon measure that reads well', () {
      expect(formatAmount(volume(45), [msk]), '3 msk');
      expect(formatAmount(volume(90), [msk]), '6 msk');
      expect(formatAmount(volume(5), [tsk]), '1 tsk');
      expect(formatAmount(volume(2), [krm]), '2 krm');
    });

    test('moves up to dl or kg when the result is a readable number', () {
      expect(formatAmount(volume(150), [msk]), '1 ½ dl');
      expect(formatAmount(volume(100), [ml]), '1 dl');
      expect(formatAmount(mass(1500), [g]), '1 ½ kg');
      expect(formatAmount(volume(1000), [ml]), '1 l');
    });

    test('stays in the recipe unit when moving up reads badly', () {
      expect(formatAmount(mass(1100), [g]), '1100 g');
      expect(formatAmount(mass(500), [g]), '500 g');
      expect(formatAmount(volume(330), [cl]), '33 cl');
    });

    test('keeps amounts below one in the recipe unit', () {
      expect(formatAmount(volume(50), [dl]), '½ dl');
      expect(formatAmount(mass(500), [kg]), '½ kg');
      expect(
        formatAmount(Amount.exact(BaseMeasure.volume, Fraction(5, 2)), [tsk]),
        '½ tsk',
      );
    });

    test('mixed spoons use the largest that reads well', () {
      expect(formatAmount(volume(20), [msk, tsk]), '1 ⅓ msk');
    });

    test('never gives an absurd number of spoons', () {
      expect(formatAmount(volume(1005), [l, tsk]), '1005 ml');
      expect(formatAmount(volume(101), [dl, krm]), '101 ml');
    });

    test('falls back to the base unit for unreadable fractions', () {
      expect(
        formatAmount(Amount.exact(BaseMeasure.volume, Fraction(100, 7)), [dl]),
        '14 2/7 ml',
      );
      expect(
        formatAmount(Amount.exact(BaseMeasure.mass, Fraction(1000, 7)), [kg]),
        '142 6/7 g',
      );
    });

    test('ranges use one unit for both ends', () {
      expect(
        formatAmount(Amount(BaseMeasure.volume, Fraction(200), Fraction(300)), [
          dl,
        ]),
        '2–3 dl',
      );
      expect(
        formatAmount(Amount(BaseMeasure.volume, Fraction(50), Fraction(100)), [
          dl,
        ]),
        '½–1 dl',
      );
    });

    test('counts', () {
      expect(
        formatAmount(Amount.exact(BaseMeasure.count, Fraction(5)), [
          StandardUnit.st,
        ]),
        '5 st',
      );
      expect(
        formatAmount(Amount.exact(BaseMeasure.count, Fraction(3, 2)), []),
        '1 ½ st',
      );
    });

    test('named units keep their own name', () {
      expect(
        formatAmount(Amount.exact(const NamedMeasure('klyftor'), Fraction(2)), [
          const NamedUnit('klyftor'),
        ]),
        '2 klyftor',
      );
    });

    Glados2(any.positiveFraction, any.standardUnit).test(
      'the chosen unit always belongs to the measure of the amount',
      (value, unit) {
        final amount = Amount.exact(unit.measure, value * unit.toBase);
        expect(displayUnit(amount, [unit]).measure, unit.measure);
      },
    );

    test('a denominator too large for BigInt.toInt is simply unreadable', () {
      final tiny = Fraction.big(BigInt.one, BigInt.two.pow(200));
      expect(displayUnit(Amount.exact(BaseMeasure.mass, tiny), [g]), g);
    });
  });
}
