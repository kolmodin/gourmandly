import 'dart:math' as math;

import 'package:domain/domain.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/repositories.dart';
import '../state/providers.dart';
import 'panel.dart';
import 'photo.dart';
import 'still_shopping.dart';
import 'theme.dart';

const _categoryNames = {
  TagCategory.cuisine: 'Cuisine',
  TagCategory.diet: 'Diet',
  TagCategory.effort: 'Effort',
  TagCategory.meal: 'Meal',
  TagCategory.meatFish: 'Meat & fish',
  TagCategory.other: 'Other',
};

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _query = '';
  TagFilter _filter = const TagFilter();

  int get _filterCount => _filter.categories.values.fold(
    0,
    (count, filter) => switch (filter) {
      AnyOf(:final tagIds) => count + tagIds.length,
      NoTags() => count + 1,
    },
  );

  Future<void> _openFilters(IList<Tag> tags) async {
    final chosen = await showPanel<TagFilter>(
      context,
      (context) => _Filters(tags: tags, initial: _filter),
    );
    if (chosen != null) setState(() => _filter = chosen);
  }

  @override
  Widget build(BuildContext context) {
    final kitchen = ref.watch(kitchenDataProvider);
    final data = kitchen.value;
    if (data == null) {
      return Center(
        child: kitchen.hasError
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('This kitchen can\'t be opened right now.'),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => ref.invalidate(kitchenDataProvider),
                    child: const Text('Try again'),
                  ),
                ],
              )
            : const CircularProgressIndicator(),
      );
    }
    final recipes = data.state.recipes.values.toList()
      ..sort((a, b) => foldText(a.title).compareTo(foldText(b.title)));
    final found = searchRecipes(
      recipes.lock,
      data.tags,
      query: _query,
      filter: _filter,
    );
    final wide = MediaQuery.sizeOf(context).width >= wideBreakpoint;
    final gutter = wide ? 40.0 : 20.0;
    final searching = _query.isNotEmpty || _filterCount > 0;
    final stillShopping = byRecipe(data.state).recipes;

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(gutter, 20, gutter, 0),
            sliver: SliverToBoxAdapter(child: _KitchenTitle(data: data)),
          ),
          if (!searching && toCook(data.state).isNotEmpty)
            SliverToBoxAdapter(
              child: _ToCook(data: data, gutter: gutter, wide: wide),
            ),
          if (!searching && stillShopping.isNotEmpty)
            SliverToBoxAdapter(
              child: StillShopping(groups: stillShopping, gutter: gutter),
            ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(gutter, 28, gutter, 16),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: (query) => setState(() => _query = query),
                      decoration: const InputDecoration(
                        hintText: 'Search recipes and ingredients',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Badge(
                    isLabelVisible: _filterCount > 0,
                    label: Text('$_filterCount'),
                    backgroundColor: Palette.cobalt,
                    child: IconButton.outlined(
                      tooltip: 'Filter by tag',
                      onPressed: () => _openFilters(data.tags),
                      icon: const Icon(Icons.tune),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (found.isEmpty)
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: gutter, vertical: 24),
              sliver: SliverToBoxAdapter(
                child: Text(
                  recipes.isEmpty
                      ? 'No recipes yet.'
                      : 'Nothing matches. Try fewer words or tags.',
                  style: Fonts.sans(17, color: Palette.pewter),
                ),
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(gutter, 8, gutter, 32),
              sliver: SliverLayoutBuilder(
                builder: (context, constraints) {
                  const spacing = 16.0;
                  final width = constraints.crossAxisExtent;
                  final columns = math.max(
                    2,
                    (width + spacing) ~/ (190 + spacing),
                  );
                  final tile = (width - spacing * (columns - 1)) / columns;
                  return SliverGrid.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisSpacing: 22,
                      crossAxisSpacing: spacing,
                      mainAxisExtent: tile + 72,
                    ),
                    itemCount: found.length,
                    itemBuilder: (context, index) =>
                        _RecipeTile(recipe: found[index]),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _KitchenTitle extends StatelessWidget {
  const _KitchenTitle({required this.data});

  final KitchenData data;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => context.push('/kitchen'),
    borderRadius: BorderRadius.circular(8),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            data.kitchen.name,
            overflow: TextOverflow.ellipsis,
            style: Fonts.serif(34),
          ),
        ),
        const SizedBox(width: 4),
        const Icon(Icons.expand_more, color: Palette.pewter),
      ],
    ),
  );
}

class _ToCook extends StatelessWidget {
  const _ToCook({required this.data, required this.gutter, required this.wide});

  final KitchenData data;
  final double gutter;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final entries = [
      for (final entry in toCook(data.state))
        if (data.state.recipes[entry.recipeId] case final recipe?)
          (entry, recipe),
    ];
    final tile = wide ? 190.0 : 150.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(gutter, 24, gutter, 12),
          child: Text('To cook', style: Fonts.serif(22)),
        ),
        SizedBox(
          height: tile + 50,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: gutter),
            itemCount: entries.length,
            separatorBuilder: (context, index) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final (entry, recipe) = entries[index];
              return SizedBox(
                width: tile,
                child: InkWell(
                  onTap: () => context.push('/recipes/${recipe.id}'),
                  borderRadius: BorderRadius.circular(6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox.square(
                        dimension: tile,
                        child: RecipePhoto(
                          recipe: recipe,
                          label: PhotoLabel.of(entry),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        recipe.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Fonts.sans(15, weight: 600, height: 1.2),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RecipeTile extends StatelessWidget {
  const _RecipeTile({required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final minutes = recipe.totalTime;
    return InkWell(
      onTap: () => context.push('/recipes/${recipe.id}'),
      borderRadius: BorderRadius.circular(6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(aspectRatio: 1, child: RecipePhoto(recipe: recipe)),
          const SizedBox(height: 8),
          Text(
            recipe.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Fonts.serif(16, height: 1.2),
          ),
          if (minutes != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '$minutes min',
                style: Fonts.sans(13, color: Palette.pewter),
              ),
            ),
        ],
      ),
    );
  }
}

class _Filters extends StatefulWidget {
  const _Filters({required this.tags, required this.initial});

  final IList<Tag> tags;
  final TagFilter initial;

  @override
  State<_Filters> createState() => _FiltersState();
}

class _FiltersState extends State<_Filters> {
  late var _categories = widget.initial.categories;

  void _toggle(TagCategory category, String tagId) {
    final current = _categories[category];
    final ids = current is AnyOf ? current.tagIds : const ISetConst<String>({});
    final next = ids.contains(tagId) ? ids.remove(tagId) : ids.add(tagId);
    setState(() {
      _categories = next.isEmpty
          ? _categories.remove(category)
          : _categories.add(category, AnyOf(next));
    });
  }

  void _toggleNone(TagCategory category) => setState(() {
    _categories = _categories[category] is NoTags
        ? _categories.remove(category)
        : _categories.add(category, const NoTags());
  });

  @override
  Widget build(BuildContext context) => SafeArea(
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              children: [
                for (final category in TagCategory.values)
                  if (tagsIn(widget.tags, category).isNotEmpty) ...[
                    Text(_categoryNames[category]!, style: Fonts.serif(18)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final tag in tagsIn(widget.tags, category))
                          FilterChip(
                            label: Text(tag.name),
                            selected: switch (_categories[category]) {
                              AnyOf(:final tagIds) => tagIds.contains(tag.id),
                              _ => false,
                            },
                            onSelected: (_) => _toggle(category, tag.id),
                          ),
                        FilterChip(
                          label: Text(
                            category == TagCategory.meatFish
                                ? 'No meat or fish'
                                : 'None',
                          ),
                          selected: _categories[category] is NoTags,
                          onSelected: (_) => _toggleNone(category),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                  ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: OverflowBar(
              alignment: MainAxisAlignment.spaceBetween,
              overflowAlignment: OverflowBarAlignment.end,
              spacing: 8,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, const TagFilter()),
                  child: const Text('Clear all'),
                ),
                FilledButton(
                  onPressed: () =>
                      Navigator.pop(context, TagFilter(_categories)),
                  child: const Text('Show recipes'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
