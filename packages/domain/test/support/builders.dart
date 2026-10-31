import 'package:domain/domain.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';

final t0 = DateTime.utc(2026, 11, 1, 12);

Ingredient ingredient(
  String key, {
  String? id,
  String? name,
  Quantity quantity = const Unspecified(),
  Unit? unit,
}) => Ingredient(
  id: id ?? key,
  name: name ?? key,
  key: key,
  quantity: quantity,
  unit: unit,
);

Ingredient amountOfIngredient(
  String key,
  int value,
  Unit unit, {
  String? name,
}) => ingredient(key, name: name, quantity: Exact(Fraction(value)), unit: unit);

Recipe recipe(
  String id,
  List<Ingredient> ingredients, {
  int servings = 4,
  String? title,
  List<String> tagIds = const [],
}) => Recipe(
  id: id,
  title: title ?? id,
  servings: servings,
  ingredients: ingredients.lock,
  tagIds: tagIds.lock,
);

PlannedRecipe planned(
  String id,
  String recipeId, {
  int servings = 4,
  DateTime? addedAt,
  Iterable<String> excluded = const [],
  Iterable<String> done = const [],
  DateTime? shoppedAt,
  DateTime? cookingStartedAt,
}) => PlannedRecipe(
  id: id,
  recipeId: recipeId,
  servings: servings,
  addedAt: addedAt ?? t0,
  excluded: excluded.toISet(),
  done: done.toISet(),
  shoppedAt: shoppedAt,
  cookingStartedAt: cookingStartedAt,
);

ListItem item(
  String id,
  String name, {
  String? key,
  Quantity quantity = const Unspecified(),
  Unit? unit,
  DateTime? addedAt,
}) => ListItem(
  id: id,
  name: name,
  key: key,
  quantity: quantity,
  unit: unit,
  addedAt: addedAt ?? t0,
);

KitchenState kitchen({
  List<Recipe> recipes = const [],
  List<PlannedRecipe> planned = const [],
  List<ListItem> items = const [],
  Set<String> staples = const {},
  Map<String, bool> overrides = const {},
  List<Check> checks = const [],
}) => KitchenState(
  recipes: {for (final r in recipes) r.id: r}.lock,
  planned: planned.lock,
  items: items.lock,
  staples: staples.lock,
  overrides: overrides.lock,
  checks: checks.lock,
);

LineId lineId(String key, Measure measure) => LineId(key, measure);

extension KitchenStateCopy on KitchenState {
  KitchenState copyWith({
    IMap<String, Recipe>? recipes,
    IList<PlannedRecipe>? planned,
    IList<ListItem>? items,
    IMap<String, bool>? overrides,
    IList<Check>? checks,
  }) => KitchenState(
    recipes: recipes ?? this.recipes,
    planned: planned ?? this.planned,
    items: items ?? this.items,
    staples: staples,
    overrides: overrides ?? this.overrides,
    checks: checks ?? this.checks,
  );
}

extension PlannedRecipeCopy on PlannedRecipe {
  PlannedRecipe withServings(int servings) => PlannedRecipe(
    id: id,
    recipeId: recipeId,
    servings: servings,
    addedAt: addedAt,
    excluded: excluded,
    done: done,
    shoppedAt: shoppedAt,
    cookingStartedAt: cookingStartedAt,
  );
}
