import 'package:domain/domain.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:glados/glados.dart';

import 'builders.dart' as b;

/// Small vocabularies on purpose: collisions are what exercises merging.
const _keys = ['onion', 'red onion', 'salt', 'flour', 'cream'];

final List<Unit?> _units = [
  StandardUnit.g,
  StandardUnit.dl,
  StandardUnit.ml,
  StandardUnit.st,
  const NamedUnit('burk'),
  null,
];

/// Enough runs to meet the rarer combinations, like merges at equal times.
final thorough = ExploreConfig(numRuns: 500);

extension KitchenGenerators on Any {
  /// True three times out of four.
  Generator<bool> get _mostly => choose([0, 1, 2, 3]).map((n) => n != 3);

  Generator<Quantity> get quantity => oneOf([
    combine2(
      intInRange(1, 9),
      intInRange(1, 5),
      (int n, int d) => Exact(Fraction(n, d)) as Quantity,
    ),
    combine2(
      intInRange(1, 5),
      intInRange(1, 5),
      (int low, int extra) =>
          Range(Fraction(low), Fraction(low + extra)) as Quantity,
    ),
    always(const Unspecified() as Quantity),
  ]);

  Generator<(String, Quantity, Unit?)> get _ingredientSpec => combine3(
    choose(_keys),
    quantity,
    choose(_units),
    (String key, Quantity quantity, Unit? unit) => (key, quantity, unit),
  );

  Generator<Recipe> recipeWithId(String id) => combine2(
    listWithLengthInRange(1, 7, _ingredientSpec),
    intInRange(1, 9),
    (List<(String, Quantity, Unit?)> specs, int servings) => Recipe(
      id: id,
      title: id,
      servings: servings,
      ingredients: [
        for (final (index, (key, quantity, unit)) in specs.indexed)
          Ingredient(
            id: '$id-$index',
            name: key,
            key: key,
            quantity: quantity,
            unit: unit,
          ),
      ].lock,
    ),
  );

  Generator<PlannedRecipe> plannedWithId(String id) => combine4(
    choose(['r0', 'r1', 'r2']),
    intInRange(1, 13),
    choose([0, 1, 2]).map((n) => n == 2 ? 30 : 0),
    _mostly,
    (String recipeId, int servings, int minutes, bool onList) => PlannedRecipe(
      id: id,
      recipeId: recipeId,
      servings: servings,
      addedAt: b.t0.add(Duration(minutes: minutes)),
      shoppedAt: onList ? null : b.t0,
    ),
  );

  Generator<ListItem> itemWithId(String id) => combine3(
    choose(_keys),
    _mostly,
    quantity,
    (String key, bool keyed, Quantity quantity) => ListItem(
      id: id,
      name: key,
      key: keyed ? key : null,
      quantity: quantity,
      unit: quantity is Unspecified ? null : StandardUnit.dl,
      addedAt: b.t0,
    ),
  );

  Generator<Check> get check => combine4(
    choose(_keys),
    choose<Measure>([
      BaseMeasure.mass,
      BaseMeasure.volume,
      BaseMeasure.count,
      BaseMeasure.none,
    ]),
    intInRange(0, 300),
    intInRange(0, 3000),
    (String key, Measure measure, int quantity, int minutes) => Check(
      line: LineId(key, measure),
      quantity: Fraction(quantity),
      at: b.t0.add(Duration(minutes: minutes)),
    ),
  );

  Generator<KitchenState> get kitchenState => combine8(
    recipeWithId('r0'),
    recipeWithId('r1'),
    recipeWithId('r2'),
    plannedList,
    itemList,
    list(choose(_keys)),
    list(combine2(choose(_keys), this.bool, MapEntry<String, bool>.new)),
    list(check),
    (
      Recipe r0,
      Recipe r1,
      Recipe r2,
      List<PlannedRecipe> planned,
      List<ListItem> items,
      List<String> staples,
      List<MapEntry<String, bool>> overrides,
      List<Check> checks,
    ) => KitchenState(
      recipes: {'r0': r0, 'r1': r1, 'r2': r2}.lock,
      planned: planned.lock,
      items: items.lock,
      staples: staples.toISet(),
      overrides: Map.fromEntries(overrides).lock,
      checks: {for (final c in checks) c.line: c}.values.toIList(),
    ),
  );

  Generator<List<PlannedRecipe>> get plannedList => combine3(
    plannedWithId('e0'),
    plannedWithId('e1'),
    plannedWithId('e2'),
    (PlannedRecipe a, PlannedRecipe b, PlannedRecipe c) => [a, b, c],
  );

  Generator<List<ListItem>> get itemList => combine2(
    itemWithId('i0'),
    itemWithId('i1'),
    (ListItem a, ListItem b) => [a, b],
  );
}

typedef Totals = Map<Measure, ({Fraction min, Fraction max})>;

Totals _add(Totals totals, Amount amount) {
  final current = totals[amount.measure];
  return {
    ...totals,
    amount.measure: (
      min: (current?.min ?? Fraction.zero) + amount.min,
      max: (current?.max ?? Fraction.zero) + amount.max,
    ),
  };
}

/// Adds up the amounts of [lines] per measure.
Totals totalsByMeasure(Iterable<Line> lines) {
  Totals totals = {};
  for (final line in lines) {
    final amount = line.amount;
    if (amount != null) totals = _add(totals, amount);
  }
  return totals;
}

/// What the planned recipes and manual items add up to, computed straight
/// from the records rather than through the shopping list.
Totals contributedTotals(KitchenState state) {
  Totals totals = {};
  for (final entry in state.planned) {
    final recipe = state.recipes[entry.recipeId];
    if (recipe == null || entry.shoppedAt != null) continue;
    final factor = scaleFactor(from: recipe.servings, to: entry.servings);
    for (final ingredient in recipe.ingredients) {
      if (entry.excluded.contains(ingredient.id) ||
          entry.done.contains(ingredient.id)) {
        continue;
      }
      final amount = amountOf(
        ingredient.quantity.scaled(factor),
        ingredient.unit,
      );
      if (amount != null) totals = _add(totals, amount);
    }
  }
  for (final item in state.items) {
    final amount = amountOf(item.quantity, item.unit);
    if (amount != null) totals = _add(totals, amount);
  }
  return totals;
}
