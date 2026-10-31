import 'package:fast_immutable_collections/fast_immutable_collections.dart';

import 'effects.dart';
import 'model.dart';
import 'shopping_list.dart';

/// How long a checked line stays before it is cleared automatically.
const checkedLifetime = Duration(hours: 24);

/// What the "Clear checked" button does.
///
/// A check whose line can't be found counts as left over and is removed, but
/// only if [isComplete] says that [state] holds all of the kitchen's data.
/// Offline, a partial cache could be missing the recipes behind a check.
IList<Effect> clearChecked(
  KitchenState state, {
  required DateTime now,
  required bool isComplete,
}) => _clear(state, now, isOldEnough: (_) => true, removeLeftovers: isComplete);

/// Clears lines checked more than [checkedLifetime] ago, for the client that
/// opens the list first. Made up of deletes and additions to sets, so two
/// clients doing this at once is harmless.
///
/// Call this only once [state] is known to be complete and in sync.
IList<Effect> autoClear(KitchenState state, {required DateTime now}) {
  final cutoff = now.subtract(checkedLifetime);
  return _clear(
    state,
    now,
    isOldEnough: (at) => at.isBefore(cutoff),
    removeLeftovers: true,
  );
}

IList<Effect> _clear(
  KitchenState state,
  DateTime now, {
  required bool Function(DateTime checkedAt) isOldEnough,
  required bool removeLeftovers,
}) {
  final list = shoppingList(state);
  final pantry = Pantry(state);

  bool isCleared(Line line) => switch (line.status) {
    FullyChecked(:final at) => isOldEnough(at),
    _ => false,
  };

  final cleared = list.lines.where(isCleared);
  final keptKeys = {
    for (final line in list.lines)
      if (!isCleared(line)) line.id.key,
  };
  final lineIds = {for (final line in list.lines) line.id};

  final done = <String, Set<String>>{};
  final effects = <Effect>[];

  for (final line in cleared) {
    for (final source in line.sources) {
      switch (source) {
        case RecipeSource(:final entryId, :final ingredientId):
          (done[entryId] ??= {}).add(ingredientId);
        case ItemSource(:final itemId):
          effects.add(DeleteListItem(itemId));
      }
    }
    effects.add(DeleteCheck(line.id));
    if (pantry.wasBroughtBack(line.id.key) && !keptKeys.contains(line.id.key)) {
      effects.add(DeleteOverride(line.id.key));
    }
  }

  if (removeLeftovers) {
    for (final check in state.checks) {
      if (!lineIds.contains(check.line) && isOldEnough(check.at)) {
        effects.add(DeleteCheck(check.line));
      }
    }
  }

  for (final entry in state.planned) {
    if (entry.stage != PlannedStage.onList) continue;
    final recipe = state.recipes[entry.recipeId];
    if (recipe == null) continue;
    final addDone = done[entry.id] ?? const {};
    final nothingLeft = recipe.ingredients.every(
      (ingredient) =>
          addDone.contains(ingredient.id) ||
          entry.done.contains(ingredient.id) ||
          entry.excluded.contains(ingredient.id) ||
          pantry.hides(lineKey(ingredient)),
    );
    if (addDone.isNotEmpty || nothingLeft) {
      effects.add(
        UpdatePlanned(
          entry.id,
          addDone: addDone.lock,
          shoppedAt: nothingLeft ? now : null,
        ),
      );
    }
  }

  return effects.lock;
}
