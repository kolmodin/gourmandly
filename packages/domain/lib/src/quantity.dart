import 'package:equatable/equatable.dart';

import 'fraction.dart';

/// How much of an ingredient a recipe asks for, in the recipe's own unit.
sealed class Quantity extends Equatable {
  const Quantity();

  Quantity scaled(Fraction factor) => switch (this) {
    Exact(:final value) => Exact(value * factor),
    Range(:final min, :final max) => Range(min * factor, max * factor),
    Unspecified() => this,
  };
}

final class Exact extends Quantity {
  const Exact(this.value);

  final Fraction value;

  @override
  List<Object> get props => [value];
}

/// A span like "2–3 st".
final class Range extends Quantity {
  const Range(this.min, this.max);

  final Fraction min;
  final Fraction max;

  @override
  List<Object> get props => [min, max];
}

/// No quantity, like "salt efter smak".
final class Unspecified extends Quantity {
  const Unspecified();

  @override
  List<Object> get props => [];
}

/// The factor that takes a recipe for [from] servings to [to] servings. Without
/// usable servings counts the recipe isn't scaled at all.
Fraction scaleFactor({required int from, required int to}) =>
    from > 0 && to > 0 ? Fraction(to, from) : Fraction.one;
