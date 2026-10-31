import 'package:equatable/equatable.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';

import 'amount.dart';
import 'effects.dart';
import 'model.dart';
import 'quantity.dart';
import 'text.dart';
import 'units.dart';

sealed class LineStatus extends Equatable {
  const LineStatus();
}

final class Unchecked extends LineStatus {
  const Unchecked();

  @override
  List<Object> get props => [];
}

/// Ticked, but the line has grown since: [remaining] is still to be bought.
final class PartlyChecked extends LineStatus {
  const PartlyChecked(this.remaining);

  final Amount remaining;

  @override
  List<Object> get props => [remaining];
}

final class FullyChecked extends LineStatus {
  const FullyChecked(this.at);

  final DateTime at;

  @override
  List<Object> get props => [at];
}

/// Where a part of a line comes from.
sealed class Source extends Equatable {
  const Source({required this.name, required this.amount});

  final String name;
  final Amount? amount;
}

final class RecipeSource extends Source {
  const RecipeSource({
    required this.entryId,
    required this.recipeId,
    required this.recipeTitle,
    required this.ingredientId,
    required super.name,
    required super.amount,
  });

  final String entryId;
  final String recipeId;
  final String recipeTitle;
  final String ingredientId;

  @override
  List<Object?> get props => [
    entryId,
    recipeId,
    recipeTitle,
    ingredientId,
    name,
    amount,
  ];
}

final class ItemSource extends Source {
  const ItemSource({
    required this.itemId,
    required super.name,
    required super.amount,
  });

  final String itemId;

  @override
  List<Object?> get props => [itemId, name, amount];
}

/// One line of the ingredients view.
final class Line extends Equatable {
  const Line({
    required this.id,
    required this.name,
    required this.amount,
    required this.units,
    required this.sources,
    required this.status,
  });

  final LineId id;

  /// The wording of the earliest added contribution.
  final String name;

  /// The whole amount, or null for a line without a quantity.
  final Amount? amount;

  /// The units of the contributions, which decide how the amount is shown.
  final IList<Unit> units;

  final IList<Source> sources;
  final LineStatus status;

  /// What is left to buy: less than [amount] when partly checked.
  Amount? get toBuy => switch (status) {
    PartlyChecked(:final remaining) => remaining,
    _ => amount,
  };

  /// For people, and for the export: `3 dl grädde`.
  String get text {
    final shown = toBuy;
    return shown == null ? name : '${formatAmount(shown, units)} $name';
  }

  @override
  List<Object?> get props => [id, name, amount, units, sources, status];
}

final class ShoppingList extends Equatable {
  const ShoppingList({required this.lines, required this.atHome});

  /// Open lines alphabetically, then fully checked lines, latest first.
  final IList<Line> lines;

  /// Staples hidden from [lines], shown collapsed as "probably at home".
  final IList<Line> atHome;

  @override
  List<Object> get props => [lines, atHome];
}

/// Decides which ingredient keys are hidden from the shopping list.
final class Pantry {
  Pantry(KitchenState state)
    : _staples = state.staples.map(normalizeKey).toSet(),
      _overrides = {
        for (final MapEntry(:key, :value) in state.overrides.entries)
          normalizeKey(key): value,
      };

  final Set<String> _staples;
  final Map<String, bool> _overrides;

  /// An override wins over the staples list.
  bool hides(String key) => !(_overrides[key] ?? !_staples.contains(key));

  bool wasBroughtBack(String key) => _overrides[key] ?? false;
}

/// The key an ingredient merges under.
String lineKey(Ingredient ingredient) {
  final key = normalizeKey(ingredient.key);
  return key.isEmpty ? normalizeKey(ingredient.name) : key;
}

final class _Contribution {
  const _Contribution({
    required this.id,
    required this.name,
    required this.amount,
    required this.unit,
    required this.source,
    required this.addedAt,
    required this.owner,
    required this.position,
    required this.hidden,
  });

  final LineId id;
  final String name;
  final Amount? amount;
  final Unit? unit;
  final Source source;
  final DateTime addedAt;
  final String owner;
  final int position;
  final bool hidden;
}

/// Earliest first; the owner and position make it a total order, so the result
/// doesn't depend on the order of the records.
int _byAge(_Contribution a, _Contribution b) {
  final age = a.addedAt.compareTo(b.addedAt);
  if (age != 0) return age;
  final owner = a.owner.compareTo(b.owner);
  return owner != 0 ? owner : a.position.compareTo(b.position);
}

List<_Contribution> _contributions(KitchenState state) {
  final pantry = Pantry(state);
  return [
    for (final entry in state.planned)
      if (entry.stage == PlannedStage.onList)
        if (state.recipes[entry.recipeId] case final recipe?)
          for (final (position, ingredient) in recipe.ingredients.indexed)
            if (!entry.excluded.contains(ingredient.id) &&
                !entry.done.contains(ingredient.id))
              _fromIngredient(entry, recipe, ingredient, position, pantry),
    for (final item in state.items) _fromItem(item),
  ]..sort(_byAge);
}

_Contribution _fromIngredient(
  PlannedRecipe entry,
  Recipe recipe,
  Ingredient ingredient,
  int position,
  Pantry pantry,
) {
  final key = lineKey(ingredient);
  final factor = scaleFactor(from: recipe.servings, to: entry.servings);
  final amount = amountOf(ingredient.quantity.scaled(factor), ingredient.unit);
  return _Contribution(
    id: LineId(key, amount?.measure ?? BaseMeasure.none),
    name: ingredient.name,
    amount: amount,
    unit: ingredient.unit,
    source: RecipeSource(
      entryId: entry.id,
      recipeId: recipe.id,
      recipeTitle: recipe.title,
      ingredientId: ingredient.id,
      name: ingredient.name,
      amount: amount,
    ),
    addedAt: entry.addedAt,
    owner: entry.id,
    position: position,
    hidden: pantry.hides(key),
  );
}

_Contribution _fromItem(ListItem item) {
  final amount = amountOf(item.quantity, item.unit);
  final measure = amount?.measure ?? BaseMeasure.none;
  final key = normalizeKey(item.key ?? '');
  return _Contribution(
    id: key.isEmpty ? LineId.forItem(item.id, measure) : LineId(key, measure),
    name: item.name,
    amount: amount,
    unit: item.unit,
    source: ItemSource(itemId: item.id, name: item.name, amount: amount),
    addedAt: item.addedAt,
    owner: item.id,
    position: 0,
    hidden: false,
  );
}

LineStatus _status(Amount? amount, Check? check) {
  if (check == null) return const Unchecked();
  final covered = check.quantity;
  if (amount == null || covered == null) return FullyChecked(check.at);
  final remaining = amount.remainingAfter(covered);
  return remaining == null ? FullyChecked(check.at) : PartlyChecked(remaining);
}

List<Line> _merge(
  Iterable<_Contribution> contributions,
  Map<LineId, Check> checks,
) {
  final groups = <LineId, List<_Contribution>>{};
  for (final contribution in contributions) {
    (groups[contribution.id] ??= []).add(contribution);
  }
  return [
    for (final MapEntry(key: id, value: group) in groups.entries)
      _line(id, group, checks[id]),
  ];
}

Line _line(LineId id, List<_Contribution> group, Check? check) {
  final amounts = group.map((c) => c.amount).nonNulls;
  final amount = amounts.isEmpty ? null : amounts.reduce((a, b) => a + b);
  return Line(
    id: id,
    name: group.first.name,
    amount: amount,
    units: group.map((c) => c.unit).nonNulls.toSet().toIList(),
    sources: [for (final c in group) c.source].lock,
    status: _status(amount, check),
  );
}

int _alphabetically(Line a, Line b) =>
    foldText(a.name).compareTo(foldText(b.name));

int _latestFirst(Line a, Line b) {
  final (FullyChecked first, FullyChecked second) = (
    a.status as FullyChecked,
    b.status as FullyChecked,
  );
  final time = second.at.compareTo(first.at);
  return time != 0 ? time : _alphabetically(a, b);
}

/// The ingredients view of the shopping list.
ShoppingList shoppingList(KitchenState state) {
  final checks = {for (final check in state.checks) check.line: check};
  final contributions = _contributions(state);
  final lines = _merge(contributions.where((c) => !c.hidden), checks);
  final open = lines.where((l) => l.status is! FullyChecked).toList()
    ..sort(_alphabetically);
  final checked = lines.where((l) => l.status is FullyChecked).toList()
    ..sort(_latestFirst);
  final atHome = _merge(contributions.where((c) => c.hidden), const {})
    ..sort(_alphabetically);
  return ShoppingList(lines: [...open, ...checked].lock, atHome: atHome.lock);
}

/// The open lines, one per line of text, for pasting into a store's importer.
/// Partly checked lines give what is left to buy.
String exportList(ShoppingList list) => list.lines
    .where((line) => line.status is! FullyChecked)
    .map((line) => line.text)
    .join('\n');

/// Ticks [line], covering all of its current amount.
Effect checkLine(Line line, {required DateTime at, String? by}) =>
    SetCheck(Check(line: line.id, quantity: line.amount?.max, at: at, by: by));

Effect uncheckLine(Line line) => DeleteCheck(line.id);

/// One ingredient of a planned recipe in the by-recipe view.
final class RecipeItem extends Equatable {
  const RecipeItem({
    required this.ingredient,
    required this.amount,
    required this.isHidden,
    required this.status,
  });

  final Ingredient ingredient;

  /// Scaled to the planned servings.
  final Amount? amount;

  /// Hidden from the ingredients view as a staple.
  final bool isHidden;

  /// The status of the merged line this ingredient is part of.
  final LineStatus status;

  String get text {
    final unit = ingredient.unit;
    final shown = amount;
    return shown == null
        ? ingredient.name
        : '${formatAmount(shown, [?unit])} ${ingredient.name}';
  }

  @override
  List<Object?> get props => [ingredient, amount, isHidden, status];
}

final class RecipeGroup extends Equatable {
  const RecipeGroup({
    required this.entry,
    required this.recipe,
    required this.items,
  });

  final PlannedRecipe entry;
  final Recipe recipe;
  final IList<RecipeItem> items;

  @override
  List<Object> get props => [entry, recipe, items];
}

final class ByRecipeView extends Equatable {
  const ByRecipeView({required this.recipes, required this.items});

  /// Planned recipes on the list, oldest first.
  final IList<RecipeGroup> recipes;

  /// Lines with a manual item in them.
  final IList<Line> items;

  @override
  List<Object> get props => [recipes, items];
}

/// The shopping list grouped per planned recipe, so that a whole recipe can
/// be removed.
ByRecipeView byRecipe(KitchenState state) {
  final list = shoppingList(state);
  final lines = {for (final line in list.lines) line.id: line};
  final pantry = Pantry(state);

  RecipeItem item(PlannedRecipe entry, Recipe recipe, Ingredient ingredient) {
    final key = lineKey(ingredient);
    final factor = scaleFactor(from: recipe.servings, to: entry.servings);
    final amount = amountOf(
      ingredient.quantity.scaled(factor),
      ingredient.unit,
    );
    final id = LineId(key, amount?.measure ?? BaseMeasure.none);
    return RecipeItem(
      ingredient: ingredient,
      amount: amount,
      isHidden: pantry.hides(key),
      status: pantry.hides(key)
          ? const Unchecked()
          : lines[id]?.status ?? const Unchecked(),
    );
  }

  final entries =
      state.planned
          .where((entry) => entry.stage == PlannedStage.onList)
          .toList()
        ..sort((a, b) {
          final age = a.addedAt.compareTo(b.addedAt);
          return age != 0 ? age : a.id.compareTo(b.id);
        });

  return ByRecipeView(
    recipes: [
      for (final entry in entries)
        if (state.recipes[entry.recipeId] case final recipe?)
          RecipeGroup(
            entry: entry,
            recipe: recipe,
            items: [
              for (final ingredient in recipe.ingredients)
                if (!entry.excluded.contains(ingredient.id) &&
                    !entry.done.contains(ingredient.id))
                  item(entry, recipe, ingredient),
            ].lock,
          ),
    ].lock,
    items: list.lines
        .where((line) => line.sources.any((source) => source is ItemSource))
        .toIList(),
  );
}
