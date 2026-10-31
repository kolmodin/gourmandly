import 'package:equatable/equatable.dart';

import 'fraction.dart';
import 'quantity.dart';
import 'units.dart';

/// A quantity in the base unit of its measure (grams, millilitres, pieces),
/// which is what makes amounts in different units addable. An exact amount
/// has [min] equal to [max].
final class Amount extends Equatable {
  const Amount(this.measure, this.min, this.max);

  const Amount.exact(this.measure, Fraction value) : min = value, max = value;

  final Measure measure;
  final Fraction min;
  final Fraction max;

  Amount operator +(Amount other) {
    if (measure != other.measure) {
      throw ArgumentError('Cannot add ${other.measure.id} to ${measure.id}');
    }
    return Amount(measure, min + other.min, max + other.max);
  }

  Amount scaled(Fraction factor) => Amount(measure, min * factor, max * factor);

  /// What is left to buy once [checked] has been bought, or null when that
  /// covers the upper end of this amount.
  Amount? remainingAfter(Fraction checked) => checked >= max
      ? null
      : Amount(measure, (min - checked).atLeast(Fraction.zero), max - checked);

  @override
  List<Object> get props => [measure, min, max];
}

/// The base-unit [Amount] of a quantity, or null when it has none. A quantity
/// without a unit counts pieces.
Amount? amountOf(Quantity quantity, Unit? unit) {
  final (min, max) = switch (quantity) {
    Exact(:final value) => (value, value),
    Range(:final min, :final max) => (min, max),
    Unspecified() => (null, null),
  };
  if (min == null || max == null) return null;
  return switch (unit) {
    null => Amount(BaseMeasure.count, min, max),
    StandardUnit() => Amount(
      unit.measure,
      min * unit.toBase,
      max * unit.toBase,
    ),
    NamedUnit() => Amount(unit.measure, min, max),
  };
}

/// Spoon measures read badly beyond this many.
final _maxSpoons = Fraction(20);

/// The largest unit that keeps [amount] readable, given the [units] the
/// contributing recipes used:
///
/// 1. the largest of those units, or of `kg`, `l` and `dl`, that gives a
///    number of at least one;
/// 2. otherwise the smallest of the recipe units, for amounts below one;
/// 3. otherwise the base unit.
///
/// A number is readable if both ends are measurable in a kitchen (halves,
/// thirds, quarters, fifths, sixths, eighths), and it isn't an absurd number
/// of spoons.
StandardUnit displayUnit(Amount amount, Iterable<Unit> units) {
  final recipeUnits = units
      .whereType<StandardUnit>()
      .where((unit) => unit.measure == amount.measure)
      .toSet();

  bool readable(StandardUnit unit) {
    final min = amount.min / unit.toBase;
    final max = amount.max / unit.toBase;
    return _measurable(min) &&
        _measurable(max) &&
        (!unit.isSpoon || max <= _maxSpoons);
  }

  bool atLeastOne(StandardUnit unit) =>
      amount.max / unit.toBase >= Fraction.one;

  int largestFirst(StandardUnit a, StandardUnit b) =>
      b.toBase.compareTo(a.toBase);

  final ladder = {
    ...recipeUnits,
    ...switch (amount.measure) {
      BaseMeasure.mass => const [StandardUnit.kg],
      BaseMeasure.volume => const [StandardUnit.l, StandardUnit.dl],
      _ => const <StandardUnit>[],
    },
  }.toList()..sort(largestFirst);

  for (final unit in ladder) {
    if (atLeastOne(unit) && readable(unit)) return unit;
  }
  final recipeUnitsBySize = recipeUnits.toList()..sort(largestFirst);
  for (final unit in recipeUnitsBySize.reversed) {
    if (readable(unit)) return unit;
  }
  return switch (amount.measure) {
    BaseMeasure.mass => StandardUnit.g,
    BaseMeasure.volume => StandardUnit.ml,
    _ => StandardUnit.st,
  };
}

bool _measurable(Fraction value) =>
    const {1, 2, 3, 4, 5, 6, 8}.contains(value.denominator.toInt());

/// For people: `3 dl`, `2–3 st`, `1 ½ kg`, `2 klyftor`.
String formatAmount(Amount amount, Iterable<Unit> units) {
  final (symbol, factor) = switch (amount.measure) {
    NamedMeasure(:final name) => (name, Fraction.one),
    BaseMeasure() => () {
      final unit = displayUnit(amount, units);
      return (unit.symbol, unit.toBase);
    }(),
  };
  final min = amount.min / factor;
  final max = amount.max / factor;
  final value = min == max ? max.display : '${min.display}–${max.display}';
  return '$value $symbol';
}
