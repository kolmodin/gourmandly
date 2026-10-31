import 'package:equatable/equatable.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';

import 'fraction.dart';
import 'quantity.dart';
import 'text.dart';
import 'units.dart';

final class Ingredient extends Equatable {
  const Ingredient({
    required this.id,
    required this.name,
    required this.key,
    this.quantity = const Unspecified(),
    this.unit,
  });

  /// Stable across edits, so exclusions and ticks survive them.
  final String id;

  /// Shown on the shopping list and in the export: `svartpeppar`.
  final String name;

  /// What you buy, in English, for matching only: `black pepper`.
  final String key;

  final Quantity quantity;
  final Unit? unit;

  @override
  List<Object?> get props => [id, name, key, quantity, unit];
}

final class Recipe extends Equatable {
  const Recipe({
    required this.id,
    required this.title,
    required this.servings,
    required this.ingredients,
    this.tagIds = const IListConst([]),
  });

  final String id;
  final String title;
  final int servings;
  final IList<Ingredient> ingredients;
  final IList<String> tagIds;

  @override
  List<Object?> get props => [id, title, servings, ingredients, tagIds];
}

enum PlannedStage { onList, toCook, cooking }

/// A recipe the kitchen intends to cook, at a given number of servings.
final class PlannedRecipe extends Equatable {
  const PlannedRecipe({
    required this.id,
    required this.recipeId,
    required this.servings,
    required this.addedAt,
    this.excluded = const ISetConst({}),
    this.done = const ISetConst({}),
    this.shoppedAt,
    this.cookingStartedAt,
  });

  final String id;
  final String recipeId;
  final int servings;
  final DateTime addedAt;

  /// Ingredient IDs the kitchen already has for this recipe.
  final ISet<String> excluded;

  /// Ingredient IDs that were bought and cleared.
  final ISet<String> done;

  final DateTime? shoppedAt;
  final DateTime? cookingStartedAt;

  PlannedStage get stage => cookingStartedAt != null
      ? PlannedStage.cooking
      : shoppedAt != null
      ? PlannedStage.toCook
      : PlannedStage.onList;

  @override
  List<Object?> get props => [
    id,
    recipeId,
    servings,
    addedAt,
    excluded,
    done,
    shoppedAt,
    cookingStartedAt,
  ];
}

/// Something added to the shopping list by hand.
final class ListItem extends Equatable {
  const ListItem({
    required this.id,
    required this.name,
    required this.addedAt,
    this.key,
    this.quantity = const Unspecified(),
    this.unit,
  });

  final String id;
  final String name;
  final DateTime addedAt;

  /// Null until the item has been matched; until then it isn't merged.
  final String? key;

  final Quantity quantity;
  final Unit? unit;

  @override
  List<Object?> get props => [id, name, addedAt, key, quantity, unit];
}

/// What makes a line on the shopping list: lines merge per key and measure.
final class LineId extends Equatable {
  const LineId(this.key, this.measure);

  /// A manual item without a key gets a line of its own.
  LineId.forItem(String itemId, this.measure) : key = 'item:$itemId';

  final String key;
  final Measure measure;

  String get documentId => '${keySlug(key)}--${measure.id}';

  @override
  List<Object> get props => [key, measure];
}

/// A ticked line. Stores how much was covered when ticking, so that a line
/// that grows afterwards can show what is still missing.
final class Check extends Equatable {
  const Check({required this.line, required this.at, this.quantity, this.by});

  final LineId line;
  final DateTime at;

  /// In the base unit of the line's measure; null for a line without one.
  final Fraction? quantity;

  final String? by;

  @override
  List<Object?> get props => [line, at, quantity, by];
}

/// Everything in a kitchen that the shopping list and planning depend on.
final class KitchenState extends Equatable {
  const KitchenState({
    this.recipes = const IMapConst({}),
    this.planned = const IListConst([]),
    this.items = const IListConst([]),
    this.staples = const ISetConst({}),
    this.overrides = const IMapConst({}),
    this.checks = const IListConst([]),
  });

  final IMap<String, Recipe> recipes;
  final IList<PlannedRecipe> planned;
  final IList<ListItem> items;

  /// Ingredient keys the kitchen usually has at home.
  final ISet<String> staples;

  /// Per ingredient key: true brings a staple back on the list, false hides
  /// something that isn't one.
  final IMap<String, bool> overrides;

  final IList<Check> checks;

  @override
  List<Object> get props => [
    recipes,
    planned,
    items,
    staples,
    overrides,
    checks,
  ];
}
