import 'package:domain/domain.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/providers.dart';
import 'panel.dart';
import 'photo.dart';
import 'theme.dart';
import 'tick.dart';

/// Planned recipes still on the shopping list, naming what is missing. A tap
/// shows the missing ingredients over the home screen, to tick off there.
class StillShopping extends StatelessWidget {
  const StillShopping({required this.groups, required this.gutter, super.key});

  final IList<RecipeGroup> groups;
  final double gutter;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(horizontal: gutter),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(child: Text('Still shopping', style: Fonts.serif(22))),
            TextButton(
              style: flushTextButton,
              onPressed: () => context.go('/list'),
              child: const Text('Shopping list'),
            ),
          ],
        ),
        for (final group in groups)
          InkWell(
            onTap: () => showMissing(context, group.entry.id),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox.square(
                    dimension: 56,
                    child: RecipePhoto(recipe: group.recipe),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.recipe.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Fonts.sans(16, weight: 600),
                        ),
                        Text(
                          missingText(group),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Fonts.sans(13, color: Palette.pewter),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

/// What is still to buy for a recipe, by name: "Missing: guanciale, äggulor".
String missingText(RecipeGroup group, {int shown = 4}) {
  final names = [for (final item in group.missing) item.ingredient.name];
  if (names.isEmpty) return 'All ticked';
  if (names.length <= shown) return 'Missing: ${names.join(', ')}';
  final rest = names.length - (shown - 1);
  return 'Missing: ${names.take(shown - 1).join(', ')}, +$rest more';
}

/// How much is left to buy for a recipe still on the shopping list:
/// "3 of 4 ingredients to buy".
String stillToBuy(RecipeGroup group) {
  final all = group.toBuy + group.bought;
  return group.toBuy == 0
      ? 'All ticked'
      : '${group.toBuy} of $all ${all == 1 ? 'ingredient' : 'ingredients'} '
            'to buy';
}

/// Shows what is still to buy for the planned recipe [entryId], with ticks
/// that are the shopping list's own.
Future<void> showMissing(BuildContext context, String entryId) =>
    showPanel<void>(context, (context) => _Missing(entryId: entryId));

class _Missing extends ConsumerWidget {
  const _Missing({required this.entryId});

  final String entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final group = ref
        .watch(byRecipeProvider)
        ?.recipes
        .where((group) => group.entry.id == entryId)
        .firstOrNull;
    final lines = {
      for (final line in ref.watch(shoppingListProvider)?.lines ?? <Line>[])
        line.id: line,
    };
    if (group == null) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'This recipe is off the shopping list now.',
            style: Fonts.sans(17, color: Palette.pewter),
          ),
        ),
      );
    }
    final actions = ref.read(kitchenActionsProvider);
    final items = group.items.where((item) => !item.isHidden);

    void markBought() {
      final messenger = ScaffoldMessenger.of(context);
      actions.apply([markShopped(group.entry, now: actions.now)]);
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Marked as bought'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => actions.apply([unmarkShopped(group.entry)]),
          ),
        ),
      );
    }

    void openRecipe() {
      final router = GoRouter.of(context);
      Navigator.pop(context);
      router.push('/recipes/${group.recipe.id}');
    }

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Row(
                children: [
                  SizedBox.square(
                    dimension: 56,
                    child: RecipePhoto(recipe: group.recipe),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(group.recipe.title, style: Fonts.serif(22)),
                        Text(
                          '${group.entry.servings} servings, '
                          '${stillToBuy(group)}',
                          style: Fonts.sans(13, color: Palette.pewter),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  for (final item in items)
                    _MissingRow(
                      item: item,
                      line: lines[item.line],
                      onTap: switch (lines[item.line]) {
                        final line? => () => actions.apply([
                          if (item.status is FullyChecked)
                            uncheckLine(line)
                          else
                            checkLine(
                              line,
                              at: actions.now,
                              by: actions.userId ?? '',
                            ),
                        ]),
                        null => null,
                      },
                    ),
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
                  OutlinedButton(
                    onPressed: markBought,
                    child: const Text('Already bought'),
                  ),
                  FilledButton(
                    onPressed: openRecipe,
                    child: const Text('Open recipe'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MissingRow extends StatelessWidget {
  const _MissingRow({
    required this.item,
    required this.line,
    required this.onTap,
  });

  final RecipeItem item;
  final Line? line;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final checked = item.status is FullyChecked;
    final merged = line?.text;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RoundTick(ticked: checked),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.text,
                    style:
                        Fonts.sans(
                          18,
                          color: checked ? Palette.pewter : Palette.ink,
                        ).copyWith(
                          decoration: checked
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                  ),
                  if (merged != null && merged != item.text && !checked)
                    Text(
                      'On the list as $merged',
                      style: Fonts.sans(13, color: Palette.pewter),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
