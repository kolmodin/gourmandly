import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import 'plate.dart';
import 'theme.dart';
import 'tick.dart';

class ShoppingScreen extends ConsumerStatefulWidget {
  const ShoppingScreen({super.key});

  @override
  ConsumerState<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends ConsumerState<ShoppingScreen> {
  final _newItem = TextEditingController();
  bool _byRecipe = false;

  @override
  void dispose() {
    _newItem.dispose();
    super.dispose();
  }

  KitchenActions get _actions => ref.read(kitchenActionsProvider);

  void _add() {
    final name = _newItem.text.trim();
    if (name.isEmpty) return;
    _actions.apply([
      addItem(
        name,
        now: _actions.now,
        newItemId: _actions.newId(),
        by: _actions.userId,
      ),
    ]);
    _newItem.clear();
  }

  Future<void> _copy(ShoppingList list) async {
    await Clipboard.setData(ClipboardData(text: exportList(list)));
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('List copied')));
    }
  }

  void _clearChecked() {
    final data = ref.read(kitchenDataProvider).value;
    if (data == null) return;
    _actions.apply(
      clearChecked(data.state, now: _actions.now, isComplete: data.isSynced),
    );
  }

  Future<void> _doneShopping() async {
    final data = ref.read(kitchenDataProvider).value;
    if (data == null) return;
    final open = shoppingList(data.state).lines
        .where((line) => line.status is! FullyChecked);
    final choice = open.isEmpty
        ? DoneShopping.keepUnchecked
        : await showDialog<DoneShopping>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Was everything bought?', style: Fonts.serif(22)),
              content: Text(
                '${open.length} items aren\'t ticked. If you ordered online, '
                'they were probably bought anyway.',
              ),
              actions: [
                TextButton(
                  onPressed: () =>
                      Navigator.pop(context, DoneShopping.keepUnchecked),
                  child: const Text('Keep unticked items'),
                ),
                FilledButton(
                  onPressed: () =>
                      Navigator.pop(context, DoneShopping.everythingBought),
                  child: const Text('Everything is bought'),
                ),
              ],
            ),
          );
    if (choice == null) return;
    _actions.apply(
      doneShopping(
        data.state,
        choice,
        now: _actions.now,
        isComplete: data.isSynced,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(shoppingListProvider);
    final view = ref.watch(byRecipeProvider);
    if (list == null || view == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final open = list.lines.where((l) => l.status is! FullyChecked).toList();
    final checked = list.lines.whereType<Line>().where(
      (l) => l.status is FullyChecked,
    );
    final wide = MediaQuery.sizeOf(context).width >= wideBreakpoint;
    final gutter = wide ? 40.0 : 20.0;

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: EdgeInsets.fromLTRB(gutter, 20, gutter, 32),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Shopping list', style: Fonts.serif(34)),
                  ),
                  MenuAnchor(
                    builder: (context, menu, child) => IconButton(
                      tooltip: 'More',
                      onPressed: () => menu.isOpen ? menu.close() : menu.open(),
                      icon: const Icon(Icons.more_horiz),
                    ),
                    menuChildren: [
                      MenuItemButton(
                        onPressed: open.isEmpty ? null : () => _copy(list),
                        child: const Text('Copy list'),
                      ),
                      MenuItemButton(
                        onPressed: checked.isEmpty ? null : _clearChecked,
                        child: const Text('Clear checked'),
                      ),
                      MenuItemButton(
                        onPressed: list.lines.isEmpty ? null : _doneShopping,
                        child: const Text('Done shopping'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _newItem,
                onSubmitted: (_) => _add(),
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  hintText: 'Add an item',
                  suffixIcon: IconButton(
                    tooltip: 'Add',
                    onPressed: _add,
                    icon: const Icon(Icons.add),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: false, label: Text('Ingredients')),
                  ButtonSegment(value: true, label: Text('By recipe')),
                ],
                selected: {_byRecipe},
                onSelectionChanged: (selected) =>
                    setState(() => _byRecipe = selected.first),
              ),
              const SizedBox(height: 10),
              if (list.lines.isEmpty && list.atHome.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: Text(
                    'The list is empty. Add a recipe from its page, or type '
                    'an item above.',
                    style: Fonts.sans(17, color: Palette.pewter),
                  ),
                )
              else if (_byRecipe)
                _ByRecipe(view: view)
              else ...[
                for (final line in open) _LineRow(line: line),
                if (checked.isNotEmpty)
                  _Folded(
                    title: 'Checked (${checked.length})',
                    children: [
                      for (final line in checked) _LineRow(line: line),
                    ],
                  ),
                if (list.atHome.isNotEmpty)
                  _Folded(
                    title: 'Probably at home (${list.atHome.length})',
                    children: [
                      for (final line in list.atHome) _AtHomeRow(line: line),
                    ],
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Folded extends StatelessWidget {
  const _Folded({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
    child: ExpansionTile(
      title: Text(
        title,
        style: Fonts.sans(15, weight: 600, color: Palette.pewter),
      ),
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      children: children,
    ),
  );
}

class _LineRow extends ConsumerWidget {
  const _LineRow({required this.line});

  final Line line;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checked = line.status is FullyChecked;
    final recipes = line.sources
        .whereType<RecipeSource>()
        .map((source) => source.recipeTitle)
        .toSet();
    return InkWell(
      onTap: () {
        final actions = ref.read(kitchenActionsProvider);
        actions.apply([
          if (checked)
            uncheckLine(line)
          else
            checkLine(line, at: actions.now, by: actions.userId ?? ''),
        ]);
      },
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
                    line.text,
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
                  if (recipes.isNotEmpty && !checked)
                    Text(
                      recipes.join(', '),
                      style: Fonts.sans(13, color: Palette.pewter),
                    ),
                  if (line.status is PartlyChecked)
                    Text(
                      'More needed since it was ticked',
                      style: Fonts.sans(13, color: Palette.saffronInk),
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

class _AtHomeRow extends ConsumerWidget {
  const _AtHomeRow({required this.line});

  final Line line;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Row(
    children: [
      Expanded(
        child: Text(line.text, style: Fonts.sans(16, color: Palette.pewter)),
      ),
      TextButton(
        onPressed: () => ref.read(kitchenActionsProvider).apply([
          bringStapleBack(line.id.key),
        ]),
        child: const Text('Add to list'),
      ),
    ],
  );
}

class _ByRecipe extends ConsumerWidget {
  const _ByRecipe({required this.view});

  final ByRecipeView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = ref.read(kitchenActionsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final group in view.recipes) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              SizedBox(width: 52, child: Plate(recipe: group.recipe)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(group.recipe.title, style: Fonts.serif(18)),
                    Text(
                      '${group.entry.servings} servings',
                      style: Fonts.sans(13, color: Palette.pewter),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => actions.apply([DeletePlanned(group.entry.id)]),
                child: const Text('Remove'),
              ),
            ],
          ),
          for (final item in group.items)
            Padding(
              padding: const EdgeInsets.only(left: 64, top: 3, bottom: 3),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.text,
                      style:
                          Fonts.sans(
                            16,
                            color: item.isHidden || item.status is FullyChecked
                                ? Palette.pewter
                                : Palette.ink,
                          ).copyWith(
                            decoration: item.status is FullyChecked
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Already have this',
                    visualDensity: VisualDensity.compact,
                    iconSize: 18,
                    onPressed: () => actions.apply([
                      excludeIngredient(group.entry, item.ingredient.id),
                    ]),
                    icon: const Icon(Icons.close, color: Palette.pewter),
                  ),
                ],
              ),
            ),
        ],
        if (view.items.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text('Added by hand', style: Fonts.serif(18)),
          for (final line in view.items) _LineRow(line: line),
        ],
      ],
    );
  }
}
