import 'package:equatable/equatable.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';

import 'model.dart';

/// A change to a kitchen's data, described rather than performed. The
/// functions in this package decide; the repository layer applies the effects
/// of one decision in one batch.
sealed class Effect extends Equatable {
  const Effect();
}

final class SetCheck extends Effect {
  const SetCheck(this.check);

  final Check check;

  @override
  List<Object> get props => [check];
}

final class DeleteCheck extends Effect {
  const DeleteCheck(this.line);

  final LineId line;

  @override
  List<Object> get props => [line];
}

final class DeleteListItem extends Effect {
  const DeleteListItem(this.itemId);

  final String itemId;

  @override
  List<Object> get props => [itemId];
}

final class SetOverride extends Effect {
  const SetOverride(this.key, {required this.include});

  final String key;
  final bool include;

  @override
  List<Object> get props => [key, include];
}

final class DeleteOverride extends Effect {
  const DeleteOverride(this.key);

  final String key;

  @override
  List<Object> get props => [key];
}

final class CreatePlanned extends Effect {
  const CreatePlanned(this.entry);

  final PlannedRecipe entry;

  @override
  List<Object> get props => [entry];
}

/// Field-level changes to a planned recipe. `addDone` and `removeDone` map to
/// `arrayUnion` and `arrayRemove`.
final class UpdatePlanned extends Effect {
  const UpdatePlanned(
    this.entryId, {
    this.addDone = const ISetConst({}),
    this.removeDone = const ISetConst({}),
    this.servings,
    this.shoppedAt,
    this.clearShoppedAt = false,
    this.cookingStartedAt,
    this.clearCookingStartedAt = false,
  });

  final String entryId;
  final ISet<String> addDone;
  final ISet<String> removeDone;
  final int? servings;
  final DateTime? shoppedAt;
  final bool clearShoppedAt;
  final DateTime? cookingStartedAt;
  final bool clearCookingStartedAt;

  @override
  List<Object?> get props => [
    entryId,
    addDone,
    removeDone,
    servings,
    shoppedAt,
    clearShoppedAt,
    cookingStartedAt,
    clearCookingStartedAt,
  ];
}

final class DeletePlanned extends Effect {
  const DeletePlanned(this.entryId);

  final String entryId;

  @override
  List<Object> get props => [entryId];
}

/// Sets `lastCookedAt` and increments `timesCooked` on a recipe.
final class RecordCooked extends Effect {
  const RecordCooked(this.recipeId, this.at);

  final String recipeId;
  final DateTime at;

  @override
  List<Object> get props => [recipeId, at];
}

final class DeleteRecipe extends Effect {
  const DeleteRecipe(this.recipeId);

  final String recipeId;

  @override
  List<Object> get props => [recipeId];
}
