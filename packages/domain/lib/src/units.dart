import 'package:equatable/equatable.dart';

import 'fraction.dart';

/// What a quantity measures. Lines on the shopping list merge only within one
/// measure: mass and volume are never converted into each other.
sealed class Measure {
  /// A stable identifier, stored in check records.
  String get id;
}

enum BaseMeasure implements Measure {
  mass,
  volume,
  count,

  /// No quantity at all, like "salt efter smak".
  none;

  @override
  String get id => name;
}

/// The measure of a [NamedUnit]. Two cloves and one jar have nothing to add
/// up to, so every named unit is a measure of its own.
final class NamedMeasure extends Equatable implements Measure {
  const NamedMeasure(this.name);

  final String name;

  @override
  String get id => 'named:$name';

  @override
  List<Object> get props => [name];
}

Measure measureFromId(String id) {
  for (final measure in BaseMeasure.values) {
    if (measure.id == id) return measure;
  }
  return NamedMeasure(id.startsWith('named:') ? id.substring(6) : id);
}

sealed class Unit {
  /// The unit as it appears in text: `dl`, `klyftor`.
  String get symbol;

  Measure get measure;
}

/// A unit with an exact factor to the base unit of its measure: grams,
/// millilitres or pieces.
enum StandardUnit implements Unit {
  g('g', BaseMeasure.mass, 1),
  kg('kg', BaseMeasure.mass, 1000),
  krm('krm', BaseMeasure.volume, 1),
  ml('ml', BaseMeasure.volume, 1),
  tsk('tsk', BaseMeasure.volume, 5),
  cl('cl', BaseMeasure.volume, 10),
  msk('msk', BaseMeasure.volume, 15),
  dl('dl', BaseMeasure.volume, 100),
  l('l', BaseMeasure.volume, 1000),
  st('st', BaseMeasure.count, 1);

  const StandardUnit(this.symbol, this.measure, this._toBase);

  @override
  final String symbol;

  @override
  final BaseMeasure measure;

  final int _toBase;

  Fraction get toBase => Fraction(_toBase);

  bool get isSpoon => this == krm || this == tsk || this == msk;

  static StandardUnit? bySymbol(String symbol) {
    for (final unit in values) {
      if (unit.symbol == symbol) return unit;
    }
    return null;
  }
}

/// Any other unit a recipe uses: `klyftor`, `burk`, `förp`.
final class NamedUnit extends Equatable implements Unit {
  const NamedUnit(this.symbol);

  @override
  final String symbol;

  @override
  Measure get measure => NamedMeasure(symbol);

  @override
  List<Object> get props => [symbol];
}

Unit unitFromSymbol(String symbol) =>
    StandardUnit.bySymbol(symbol) ?? NamedUnit(symbol);
