import 'package:domain/domain.dart';
import 'package:glados/glados.dart';

extension DomainGenerators on Any {
  Generator<Fraction> get fraction =>
      combine2(intInRange(-500, 500), intInRange(1, 60), Fraction.new);

  Generator<Fraction> get nonNegativeFraction =>
      combine2(intInRange(0, 500), intInRange(1, 60), Fraction.new);

  Generator<Fraction> get positiveFraction =>
      combine2(intInRange(1, 500), intInRange(1, 60), Fraction.new);

  Generator<StandardUnit> get standardUnit => choose(StandardUnit.values);

  Generator<Unit> get unit => oneOf([
    standardUnit.map((u) => u as Unit),
    choose(['klyfta', 'burk', 'förp']).map((n) => NamedUnit(n) as Unit),
  ]);
}
