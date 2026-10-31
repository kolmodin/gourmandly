import 'package:fast_immutable_collections/fast_immutable_collections.dart';

import 'effects.dart';
import 'model.dart';
import 'text.dart';

/// Applies effects to a state the way the repository layer applies them to
/// Firestore, including that an effect on something missing does nothing. For
/// tests and fakes: the real app goes through Firestore.
KitchenState applyEffects(KitchenState state, Iterable<Effect> effects) =>
    effects.fold(state, _apply);

KitchenState _copy(
  KitchenState state, {
  IMap<String, Recipe>? recipes,
  IList<PlannedRecipe>? planned,
  IList<ListItem>? items,
  IMap<String, bool>? overrides,
  IList<Check>? checks,
}) => KitchenState(
  recipes: recipes ?? state.recipes,
  planned: planned ?? state.planned,
  items: items ?? state.items,
  staples: state.staples,
  overrides: overrides ?? state.overrides,
  checks: checks ?? state.checks,
);

KitchenState _apply(KitchenState state, Effect effect) => switch (effect) {
  SetCheck(:final check) => _copy(
    state,
    checks: [...state.checks.where((c) => c.line != check.line), check].lock,
  ),
  DeleteCheck(:final line) => _copy(
    state,
    checks: state.checks.where((c) => c.line != line).toIList(),
  ),
  CreateListItem(:final item) => _copy(state, items: state.items.add(item)),
  DeleteListItem(:final itemId) => _copy(
    state,
    items: state.items.where((i) => i.id != itemId).toIList(),
  ),
  SetOverride(:final key, :final include) => _copy(
    state,
    overrides: state.overrides.add(key, include),
  ),
  DeleteOverride(:final key) => _copy(
    state,
    overrides: {
      for (final MapEntry(key: k, :value) in state.overrides.entries)
        if (normalizeKey(k) != key) k: value,
    }.lock,
  ),
  CreatePlanned(:final entry) => _copy(
    state,
    planned: state.planned.add(entry),
  ),
  UpdatePlanned() => _copy(
    state,
    planned: [
      for (final entry in state.planned)
        entry.id == effect.entryId ? _update(entry, effect) : entry,
    ].lock,
  ),
  DeletePlanned(:final entryId) => _copy(
    state,
    planned: state.planned.where((e) => e.id != entryId).toIList(),
  ),
  FinishCooking(:final entryId, :final recipeId, :final at) => _finish(
    state,
    entryId,
    recipeId,
    at,
  ),
  DeleteRecipe(:final recipeId) => _copy(
    state,
    recipes: state.recipes.remove(recipeId),
  ),
};

PlannedRecipe _update(PlannedRecipe entry, UpdatePlanned update) =>
    PlannedRecipe(
      id: entry.id,
      recipeId: entry.recipeId,
      servings: update.servings ?? entry.servings,
      addedAt: entry.addedAt,
      addedBy: entry.addedBy,
      excluded: entry.excluded
          .addAll(update.addExcluded)
          .removeAll(update.removeExcluded),
      done: entry.done.addAll(update.addDone).removeAll(update.removeDone),
      shoppedAt: update.clearShoppedAt
          ? null
          : update.shoppedAt ?? entry.shoppedAt,
      cookingStartedAt: update.clearCookingStartedAt
          ? null
          : update.cookingStartedAt ?? entry.cookingStartedAt,
    );

KitchenState _finish(
  KitchenState state,
  String entryId,
  String recipeId,
  DateTime at,
) {
  final recipe = state.recipes[recipeId];
  final known = state.planned.any((entry) => entry.id == entryId);
  return _copy(
    state,
    planned: state.planned.where((e) => e.id != entryId).toIList(),
    recipes: known && recipe != null
        ? state.recipes.add(recipeId, _cooked(recipe, at))
        : state.recipes,
  );
}

Recipe _cooked(Recipe recipe, DateTime at) => Recipe(
  id: recipe.id,
  title: recipe.title,
  servings: recipe.servings,
  ingredients: recipe.ingredients,
  tagIds: recipe.tagIds,
  steps: recipe.steps,
  language: recipe.language,
  original: recipe.original,
  sourceUrl: recipe.sourceUrl,
  image: recipe.image,
  totalTime: recipe.totalTime,
  lastCookedAt: at,
  timesCooked: recipe.timesCooked + 1,
);
