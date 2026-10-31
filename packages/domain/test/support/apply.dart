import 'package:domain/domain.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';

import 'builders.dart';

/// Applies effects to a state the way the repository layer applies them to
/// Firestore, so that tests can state what decisions lead to.
KitchenState applyEffects(KitchenState state, Iterable<Effect> effects) =>
    effects.fold(state, _apply);

KitchenState _apply(KitchenState state, Effect effect) => switch (effect) {
  SetCheck(:final check) => state.copyWith(
    checks: [...state.checks.where((c) => c.line != check.line), check].lock,
  ),
  DeleteCheck(:final line) => state.copyWith(
    checks: state.checks.where((c) => c.line != line).toIList(),
  ),
  DeleteListItem(:final itemId) => state.copyWith(
    items: state.items.where((i) => i.id != itemId).toIList(),
  ),
  SetOverride(:final key, :final include) => state.copyWith(
    overrides: state.overrides.add(key, include),
  ),
  DeleteOverride(:final key) => state.copyWith(
    overrides: state.overrides
        .where((k, _) => normalizeKey(k) != key)
        .unlock
        .lock,
  ),
  CreatePlanned(:final entry) => state.copyWith(
    planned: state.planned.add(entry),
  ),
  UpdatePlanned() => state.copyWith(
    planned: [
      for (final entry in state.planned)
        entry.id == effect.entryId ? _update(entry, effect) : entry,
    ].lock,
  ),
  DeletePlanned(:final entryId) => state.copyWith(
    planned: state.planned.where((e) => e.id != entryId).toIList(),
  ),
  RecordCooked() => state,
  DeleteRecipe(:final recipeId) => state.copyWith(
    recipes: state.recipes.remove(recipeId),
  ),
};

PlannedRecipe _update(PlannedRecipe entry, UpdatePlanned update) =>
    PlannedRecipe(
      id: entry.id,
      recipeId: entry.recipeId,
      servings: update.servings ?? entry.servings,
      addedAt: entry.addedAt,
      excluded: entry.excluded,
      done: entry.done.addAll(update.addDone).removeAll(update.removeDone),
      shoppedAt: update.clearShoppedAt
          ? null
          : update.shoppedAt ?? entry.shoppedAt,
      cookingStartedAt: update.clearCookingStartedAt
          ? null
          : update.cookingStartedAt ?? entry.cookingStartedAt,
    );
