import 'package:domain/domain.dart';
import 'package:glados/glados.dart';

import 'support/generators.dart';

void main() {
  group('standard units', () {
    test('have exact factors to their base unit', () {
      expect(StandardUnit.krm.toBase, Fraction(1));
      expect(StandardUnit.tsk.toBase, Fraction(5));
      expect(StandardUnit.msk.toBase, Fraction(15));
      expect(StandardUnit.ml.toBase, Fraction(1));
      expect(StandardUnit.cl.toBase, Fraction(10));
      expect(StandardUnit.dl.toBase, Fraction(100));
      expect(StandardUnit.l.toBase, Fraction(1000));
      expect(StandardUnit.g.toBase, Fraction(1));
      expect(StandardUnit.kg.toBase, Fraction(1000));
      expect(StandardUnit.st.toBase, Fraction(1));
    });

    test('belong to their measure', () {
      expect(StandardUnit.kg.measure, BaseMeasure.mass);
      expect(StandardUnit.dl.measure, BaseMeasure.volume);
      expect(StandardUnit.msk.measure, BaseMeasure.volume);
      expect(StandardUnit.st.measure, BaseMeasure.count);
    });

    test('are looked up by symbol', () {
      expect(StandardUnit.bySymbol('dl'), StandardUnit.dl);
      expect(StandardUnit.bySymbol('burk'), isNull);
    });
  });

  group('named units', () {
    test('are their own measure', () {
      expect(const NamedUnit('klyfta').measure, const NamedMeasure('klyfta'));
      expect(
        const NamedUnit('klyfta').measure,
        isNot(const NamedUnit('burk').measure),
      );
    });

    test('unitFromSymbol prefers a standard unit', () {
      expect(unitFromSymbol('dl'), StandardUnit.dl);
      expect(unitFromSymbol('burk'), const NamedUnit('burk'));
    });

    test('unitFromSymbol ignores case and spacing', () {
      expect(unitFromSymbol('L'), StandardUnit.l);
      expect(unitFromSymbol(' Dl '), StandardUnit.dl);
    });

    test('are one measure whatever their case', () {
      expect(
        const NamedUnit('Klyftor ').measure,
        const NamedUnit('klyftor').measure,
      );
    });
  });

  group('measure ids', () {
    test('are stable strings', () {
      expect(BaseMeasure.mass.id, 'mass');
      expect(BaseMeasure.volume.id, 'volume');
      expect(BaseMeasure.count.id, 'count');
      expect(BaseMeasure.none.id, 'none');
      expect(const NamedMeasure('burk').id, 'named:burk');
    });

    test('round-trip', () {
      for (final measure in [
        ...BaseMeasure.values,
        const NamedMeasure('burk'),
      ]) {
        expect(measureFromId(measure.id), measure);
      }
    });

    test('an unknown id reads as a named measure', () {
      expect(measureFromId('liters?'), const NamedMeasure('liters?'));
    });
  });

  Glados2(any.standardUnit, any.positiveFraction).test(
    'converting to base and back is lossless',
    (unit, value) {
      expect(value * unit.toBase / unit.toBase, value);
    },
  );

  Glados3(any.standardUnit, any.standardUnit, any.positiveFraction).test(
    'conversion between units of one measure round-trips',
    (a, b, value) {
      if (a.measure != b.measure) return;
      final inB = value * a.toBase / b.toBase;
      expect(inB * b.toBase / a.toBase, value);
    },
  );
}
