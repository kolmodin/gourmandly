import 'package:equatable/equatable.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';

import 'model.dart';
import 'text.dart';

/// Every tag belongs to one of these fixed categories.
enum TagCategory { cuisine, diet, effort, meal, meatFish, other }

final class Tag extends Equatable {
  const Tag({
    required this.id,
    required this.name,
    required this.category,
    this.key,
  });

  final String id;
  final String name;
  final TagCategory category;

  /// Identifies a seeded tag even after it has been renamed: `effort.quick`.
  final String? key;

  @override
  List<Object?> get props => [id, name, category, key];
}

sealed class CategoryFilter extends Equatable {
  const CategoryFilter();
}

/// Matches recipes with at least one of [tagIds]. Empty filters nothing.
final class AnyOf extends CategoryFilter {
  const AnyOf(this.tagIds);

  final ISet<String> tagIds;

  @override
  List<Object> get props => [tagIds];
}

/// Matches recipes without any tag in the category: "no meat or fish".
final class NoTags extends CategoryFilter {
  const NoTags();

  @override
  List<Object> get props => [];
}

/// Per category, which recipes to keep. A recipe has to pass every category.
final class TagFilter extends Equatable {
  const TagFilter([this.categories = const IMapConst({})]);

  final IMap<TagCategory, CategoryFilter> categories;

  @override
  List<Object> get props => [categories];
}

/// The tags of [category], in their original order.
IList<Tag> tagsIn(IList<Tag> tags, TagCategory category) =>
    tags.where((tag) => tag.category == category).toIList();

/// The recipes matching [query] and [filter], in their original order. Every
/// word of the query has to appear in the title, an ingredient or a tag.
IList<Recipe> searchRecipes(
  IList<Recipe> recipes,
  IList<Tag> tags, {
  String query = '',
  TagFilter filter = const TagFilter(),
}) {
  final byId = {for (final tag in tags) tag.id: tag};
  final words = foldText(query)
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty);

  bool matchesText(Recipe recipe) {
    final fields = [
      recipe.title,
      for (final ingredient in recipe.ingredients) ...[
        ingredient.name,
        ingredient.key,
        ?ingredient.boughtAs,
      ],
      for (final id in recipe.tagIds) ?byId[id]?.name,
    ].map(foldText).toList();
    return words.every((word) => fields.any((f) => f.contains(word)));
  }

  bool matchesTags(Recipe recipe) {
    final categoriesOf = {for (final id in recipe.tagIds) ?byId[id]?.category};
    return filter.categories.entries.every(
      (entry) => switch (entry.value) {
        AnyOf(:final tagIds) =>
          tagIds.isEmpty || recipe.tagIds.any(tagIds.contains),
        NoTags() => !categoriesOf.contains(entry.key),
      },
    );
  }

  return recipes.where((r) => matchesText(r) && matchesTags(r)).toIList();
}
