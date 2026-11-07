import 'package:equatable/equatable.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';

import 'model.dart';

/// A change to a kitchen's data, described rather than performed. The
/// functions in this package decide; the repository layer applies them.
///
/// Effects on a document that has disappeared in the meantime, deleted by
/// another member for example, do nothing, and don't hold back the other
/// effects of the decision.
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

final class CreateListItem extends Effect {
  const CreateListItem(this.item);

  final ListItem item;

  @override
  List<Object> get props => [item];
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

/// Field-level changes to a planned recipe. The `add` and `remove` sets map to
/// `arrayUnion` and `arrayRemove`, and Firestore can't do both to one array in
/// one write: an update with both for one array is refused, see
/// [isWritable].
final class UpdatePlanned extends Effect {
  const UpdatePlanned(
    this.entryId, {
    this.addDone = const ISetConst({}),
    this.removeDone = const ISetConst({}),
    this.addExcluded = const ISetConst({}),
    this.removeExcluded = const ISetConst({}),
    this.servings,
    this.shoppedAt,
    this.clearShoppedAt = false,
    this.cookingStartedAt,
    this.clearCookingStartedAt = false,
  });

  final String entryId;
  final ISet<String> addDone;
  final ISet<String> removeDone;
  final ISet<String> addExcluded;
  final ISet<String> removeExcluded;
  final int? servings;
  final DateTime? shoppedAt;
  final bool clearShoppedAt;
  final DateTime? cookingStartedAt;
  final bool clearCookingStartedAt;

  /// Whether one Firestore write can make this update: it neither adds to and
  /// removes from `done`, nor `excluded`.
  bool get isWritable =>
      (addDone.isEmpty || removeDone.isEmpty) &&
      (addExcluded.isEmpty || removeExcluded.isEmpty);

  @override
  List<Object?> get props => [
    entryId,
    addDone,
    removeDone,
    addExcluded,
    removeExcluded,
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

/// Deletes a planned recipe and records on its recipe that it was cooked, as
/// one atomic step: when two clients finish the same entry, only one of them
/// counts. If the entry or the recipe is gone by then, the entry is simply
/// deleted.
final class FinishCooking extends Effect {
  const FinishCooking({
    required this.entryId,
    required this.recipeId,
    required this.at,
  });

  final String entryId;
  final String recipeId;
  final DateTime at;

  @override
  List<Object> get props => [entryId, recipeId, at];
}

final class DeleteRecipe extends Effect {
  const DeleteRecipe(this.recipeId);

  final String recipeId;

  @override
  List<Object> get props => [recipeId];
}
