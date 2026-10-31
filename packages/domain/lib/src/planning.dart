import 'package:fast_immutable_collections/fast_immutable_collections.dart';

import 'amount.dart';
import 'clearing.dart';
import 'effects.dart';
import 'model.dart';
import 'quantity.dart';
import 'text.dart';

/// How long cooking can go on before it counts as finished.
const cookingLifetime = Duration(hours: 24);

/// The "To cook" list: recipes being cooked first, then shopped ones, oldest
/// first.
IList<PlannedRecipe> toCook(KitchenState state) {
  int rank(PlannedRecipe entry) => entry.stage == PlannedStage.cooking ? 0 : 1;

  return (state.planned
          .where((entry) => entry.stage != PlannedStage.onList)
          .toList()
        ..sort((a, b) {
          final byRank = rank(a).compareTo(rank(b));
          if (byRank != 0) return byRank;
          final byTime = a.shoppedAt!.compareTo(b.shoppedAt!);
          return byTime != 0 ? byTime : a.id.compareTo(b.id);
        }))
      .lock;
}

/// The entry to continue from when cooking [recipeId]: the one furthest along,
/// as a recipe can be planned twice.
PlannedRecipe? plannedEntryFor(KitchenState state, String recipeId) {
  for (final stage in PlannedStage.values.reversed) {
    for (final entry in state.planned) {
      if (entry.recipeId == recipeId && entry.stage == stage) return entry;
    }
  }
  return null;
}

Effect markShopped(PlannedRecipe entry, {required DateTime now}) =>
    UpdatePlanned(entry.id, shoppedAt: now);

/// Puts a staple back on the shopping list, this time around.
Effect bringStapleBack(String key) =>
    SetOverride(normalizeKey(key), include: true);

enum DoneShopping { everythingBought, keepUnchecked }

/// What the "Done shopping" button does. After ordering online nothing is
/// ticked, so the user says whether unticked items were bought too.
IList<Effect> doneShopping(
  KitchenState state,
  DoneShopping choice, {
  required DateTime now,
}) => switch (choice) {
  DoneShopping.keepUnchecked => clearChecked(state, now: now),
  DoneShopping.everythingBought => <Effect>[
    for (final entry in state.planned)
      if (entry.stage == PlannedStage.onList) markShopped(entry, now: now),
    for (final item in state.items) DeleteListItem(item.id),
    for (final check in state.checks) DeleteCheck(check.line),
    for (final key in state.overrides.keys) DeleteOverride(normalizeKey(key)),
  ].lock,
};

/// A decision to start cooking, with how to take it back.
final class StartCooking {
  const StartCooking({required this.effects, required this.undo});

  final IList<Effect> effects;
  final IList<Effect> undo;
}

/// What the "Start cooking" button does.
///
/// A recipe still on the shopping list has its remaining ingredients ticked
/// off, which removes only its own share of merged lines. A recipe that isn't
/// planned gets an entry that is already cooking, and leaves the shopping list
/// alone.
StartCooking startCooking({
  required Recipe recipe,
  required int servings,
  required DateTime now,
  required String newEntryId,
  PlannedRecipe? entry,
}) {
  if (entry == null) {
    return StartCooking(
      effects: [
        CreatePlanned(
          PlannedRecipe(
            id: newEntryId,
            recipeId: recipe.id,
            servings: servings,
            addedAt: now,
            shoppedAt: now,
            cookingStartedAt: now,
          ),
        ),
      ].lock,
      undo: [DeletePlanned(newEntryId)].lock,
    );
  }

  final (effect, undo) = switch (entry.stage) {
    PlannedStage.onList => () {
      final remaining = recipe.ingredients
          .map((ingredient) => ingredient.id)
          .where(
            (id) => !entry.done.contains(id) && !entry.excluded.contains(id),
          )
          .toISet();
      return (
        UpdatePlanned(
          entry.id,
          addDone: remaining,
          servings: servings,
          shoppedAt: now,
          cookingStartedAt: now,
        ),
        UpdatePlanned(
          entry.id,
          removeDone: remaining,
          servings: entry.servings,
          clearShoppedAt: true,
          clearCookingStartedAt: true,
        ),
      );
    }(),
    PlannedStage.toCook => (
      UpdatePlanned(entry.id, servings: servings, cookingStartedAt: now),
      UpdatePlanned(
        entry.id,
        servings: entry.servings,
        clearCookingStartedAt: true,
      ),
    ),
    PlannedStage.cooking => (
      UpdatePlanned(entry.id, servings: servings),
      UpdatePlanned(entry.id, servings: entry.servings),
    ),
  };
  return StartCooking(effects: [effect].lock, undo: [undo].lock);
}

IList<Effect> _finish(PlannedRecipe entry, DateTime at) =>
    [DeletePlanned(entry.id), RecordCooked(entry.recipeId, at)].lock;

/// What the "Done cooking" button does.
IList<Effect> doneCooking(PlannedRecipe entry, {required DateTime now}) =>
    _finish(entry, now);

/// Finishes cooking that was started more than [cookingLifetime] ago and never
/// marked as done, so forgotten sessions don't pile up.
IList<Effect> finishForgotten(KitchenState state, {required DateTime now}) {
  final cutoff = now.subtract(cookingLifetime);
  return [
    for (final entry in state.planned)
      if (entry.cookingStartedAt case final started?)
        if (started.isBefore(cutoff)) ..._finish(entry, started),
  ].lock;
}

/// Deletes a recipe along with every planned entry for it.
IList<Effect> deleteRecipe(KitchenState state, String recipeId) => <Effect>[
  DeleteRecipe(recipeId),
  for (final entry in state.planned)
    if (entry.recipeId == recipeId) DeletePlanned(entry.id),
].lock;

/// An ingredient as the cooking view shows it, scaled from a recipe for
/// [from] servings to [to] servings.
String cookingText(
  Ingredient ingredient, {
  required int from,
  required int to,
}) {
  final factor = scaleFactor(from: from, to: to);
  final amount = amountOf(ingredient.quantity.scaled(factor), ingredient.unit);
  final unit = ingredient.unit;
  return amount == null
      ? ingredient.name
      : '${formatAmount(amount, [?unit])} ${ingredient.name}';
}
