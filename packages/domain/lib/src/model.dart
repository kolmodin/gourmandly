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
    this.text = '',
    this.note,
    this.group,
    this.boughtAs,
  });

  /// Stable across edits, so exclusions and ticks survive them.
  final String id;

  /// What the recipe uses, shown in it and on the shopping list: `svartpeppar`.
  final String name;

  /// What is bought for it, when the recipe uses only part of that, one for
  /// one: `ägg` for `äggulor`. Shown on the shopping list instead of [name],
  /// so that four yolks and four eggs make "8 st ägg".
  final String? boughtAs;

  /// What you buy, in English, for matching only: `black pepper`.
  final String key;

  final Quantity quantity;
  final Unit? unit;

  /// The line as written in the recipe: `2 krm nymald svartpeppar`.
  final String text;

  /// `gärna ekologisk`
  final String? note;

  /// The section heading of the ingredient: `Sås`.
  final String? group;

  @override
  List<Object?> get props => [
    id,
    name,
    key,
    quantity,
    unit,
    text,
    note,
    group,
    boughtAs,
  ];
}

enum ImageOrigin { page, ai }

/// A recipe's photo, copied into storage at import.
final class RecipeImage extends Equatable {
  const RecipeImage({
    required this.storagePath,
    this.sourceUrl,
    this.origin = ImageOrigin.page,
  });

  final String storagePath;

  /// Where the photo was copied from.
  final String? sourceUrl;

  final ImageOrigin origin;

  @override
  List<Object?> get props => [storagePath, sourceUrl, origin];
}

/// A recipe as imported, kept when it was translated into the kitchen's
/// language. Read-only.
final class RecipeOriginal extends Equatable {
  const RecipeOriginal({
    required this.language,
    required this.title,
    required this.ingredients,
    required this.steps,
  });

  final String language;
  final String title;
  final IList<Ingredient> ingredients;
  final IList<String> steps;

  @override
  List<Object> get props => [language, title, ingredients, steps];
}

final class Recipe extends Equatable {
  const Recipe({
    required this.id,
    required this.title,
    required this.servings,
    required this.ingredients,
    this.tagIds = const IListConst([]),
    this.steps = const IListConst([]),
    this.language,
    this.original,
    this.sourceUrl,
    this.image,
    this.totalTime,
    this.lastCookedAt,
    this.timesCooked = 0,
  });

  final String id;
  final String title;
  final int servings;
  final IList<Ingredient> ingredients;
  final IList<String> tagIds;
  final IList<String> steps;

  /// The kitchen's language at import.
  final String? language;

  /// Set when the source was in another language.
  final RecipeOriginal? original;

  final String? sourceUrl;
  final RecipeImage? image;

  /// In minutes.
  final int? totalTime;

  final DateTime? lastCookedAt;
  final int timesCooked;

  @override
  List<Object?> get props => [
    id,
    title,
    servings,
    ingredients,
    tagIds,
    steps,
    language,
    original,
    sourceUrl,
    image,
    totalTime,
    lastCookedAt,
    timesCooked,
  ];
}

/// A recipe store and a shopping list, shared by the people who cook together.
final class Kitchen extends Equatable {
  const Kitchen({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.memberIds,
    required this.language,
    this.memberNames = const IMapConst({}),
  });

  final String id;
  final String name;
  final String ownerId;
  final IList<String> memberIds;

  /// Display names per member ID. Kept here so that members can see each other
  /// without being able to read each other's accounts.
  final IMap<String, String> memberNames;

  /// The language the kitchen shops in.
  final String language;

  @override
  List<Object> get props => [
    id,
    name,
    ownerId,
    memberIds,
    memberNames,
    language,
  ];
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
    this.addedBy,
    this.shoppedAt,
    this.cookingStartedAt,
  });

  final String id;
  final String recipeId;
  final int servings;
  final DateTime addedAt;
  final String? addedBy;

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
    addedBy,
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
    this.addedBy,
    this.key,
    this.quantity = const Unspecified(),
    this.unit,
  });

  final String id;
  final String name;
  final DateTime addedAt;
  final String? addedBy;

  /// Null until the item has been matched; until then it isn't merged.
  final String? key;

  final Quantity quantity;
  final Unit? unit;

  @override
  List<Object?> get props => [id, name, addedAt, addedBy, key, quantity, unit];
}

/// What makes a line on the shopping list: lines merge per key and measure.
final class LineId extends Equatable {
  const LineId(this.key, this.measure);

  /// A manual item without a key gets a line of its own.
  LineId.forItem(String itemId, this.measure) : key = 'item:$itemId';

  final String key;
  final Measure measure;

  String get documentId => '${keySlug(key)}--${keySlug(measure.id)}';

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
