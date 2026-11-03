import 'dart:async';

import 'package:domain/domain.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../platform/screen_awake.dart';
import '../state/providers.dart';
import 'plate.dart';
import 'theme.dart';
import 'tick.dart';

/// A recipe, and the cooking view: the same screen, as you read a recipe the
/// same way before and while cooking. Starting to cook adds ticks, keeps the
/// screen on and turns the rim of the plate saffron.
class RecipeScreen extends ConsumerStatefulWidget {
  const RecipeScreen({required this.recipeId, super.key});

  final String recipeId;

  @override
  ConsumerState<RecipeScreen> createState() => _RecipeScreenState();
}

class _RecipeScreenState extends ConsumerState<RecipeScreen> {
  int? _servings;
  bool _original = false;
  bool _screenKept = false;

  void _keepScreen(bool on) {
    if (on == _screenKept) return;
    _screenKept = on;
    unawaited(on ? _screen.keepOn() : _screen.release());
  }

  @override
  void initState() {
    super.initState();
    _screen = ref.read(screenAwakeProvider);
  }

  late final ScreenAwake _screen;

  @override
  void dispose() {
    if (_screenKept) unawaited(_screen.release());
    super.dispose();
  }

  void _start(Recipe recipe, PlannedRecipe? entry, int servings) {
    final actions = ref.read(kitchenActionsProvider);
    final started = startCooking(
      recipe: recipe,
      servings: servings,
      now: actions.now,
      newEntryId: actions.newId(),
      entry: entry,
      by: actions.userId,
    );
    actions.apply(started.effects);
    if (entry?.stage == PlannedStage.onList) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Taken off the shopping list'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => actions.apply(started.undo),
          ),
        ),
      );
    }
  }

  void _addToList(Recipe recipe, int servings) {
    final actions = ref.read(kitchenActionsProvider);
    actions.apply([
      addToList(
        recipe,
        servings: servings,
        now: actions.now,
        newEntryId: actions.newId(),
        by: actions.userId,
      ),
    ]);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Added to the shopping list')));
  }

  void _markBought(PlannedRecipe entry) {
    final actions = ref.read(kitchenActionsProvider);
    actions.apply([markShopped(entry, now: actions.now)]);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Marked as bought'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => actions.apply([unmarkShopped(entry)]),
        ),
      ),
    );
  }

  void _done(PlannedRecipe entry) {
    final actions = ref.read(kitchenActionsProvider);
    actions.apply([doneCooking(entry, now: actions.now)]);
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(kitchenDataProvider).value?.state;
    final recipe = state?.recipes[widget.recipeId];
    if (state == null || recipe == null) {
      return Scaffold(
        appBar: AppBar(backgroundColor: Palette.enamel),
        body: Center(
          child: state == null
              ? const CircularProgressIndicator()
              : const Text('This recipe isn\'t in the kitchen any more.'),
        ),
      );
    }
    final entry = plannedEntryFor(state, recipe.id);
    final cooking = entry?.stage == PlannedStage.cooking;
    _keepScreen(cooking);
    final rim = rimFor(entry?.stage);
    final toBuy = ref
        .watch(byRecipeProvider)
        ?.recipes
        .where((group) => group.entry.id == entry?.id)
        .firstOrNull
        ?.toBuy;

    final servings = _servings ?? entry?.servings ?? recipe.servings;
    final original = recipe.original;
    final showOriginal = _original && original != null;
    final title = showOriginal ? original.title : recipe.title;
    final ingredients = showOriginal
        ? original.ingredients
        : recipe.ingredients;
    final steps = showOriginal ? original.steps : recipe.steps;
    final ticks = cooking ? ref.watch(cookingTicksProvider(entry!.id)) : null;
    void tick(String id) =>
        ref.read(cookingTicksProvider(entry!.id).notifier).toggle(id);

    final controls = _Controls(
      recipe: recipe,
      entry: entry,
      servings: servings,
      onServings: (value) => setState(() => _servings = value),
      showOriginal: showOriginal,
      onOriginal: (value) => setState(() => _original = value),
      onStart: () => _start(recipe, entry, servings),
      onAdd: () => _addToList(recipe, servings),
      onDone: () => _done(entry!),
      toBuy: toBuy,
      onMissing: () => context.go('/list?entry=${entry!.id}'),
      onBought: () => _markBought(entry!),
    );
    final ingredientList = _Ingredients(
      ingredients: ingredients,
      from: recipe.servings,
      to: servings,
      ticked: ticks,
      onTick: tick,
    );
    final stepList = _Steps(steps: steps, ticked: ticks, onTick: tick);

    final wide = MediaQuery.sizeOf(context).width >= wideBreakpoint;
    return Scaffold(
      body: SafeArea(
        child: wide
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _WideHeader(
                    recipe: recipe,
                    title: title,
                    rim: rim,
                    controls: controls,
                  ),
                  const Divider(),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 5,
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(40, 20, 32, 32),
                            children: [ingredientList],
                          ),
                        ),
                        const VerticalDivider(width: 1),
                        Expanded(
                          flex: 7,
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(32, 20, 40, 32),
                            children: [stepList],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : ListView(
                padding: const EdgeInsets.only(bottom: 40),
                children: [
                  _Header(recipe: recipe, title: title, rim: rim),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        controls,
                        const SizedBox(height: 28),
                        ingredientList,
                        const SizedBox(height: 32),
                        stepList,
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// The plate runs off the corner of the screen, with the title beneath it.
class _Header extends StatelessWidget {
  const _Header({required this.recipe, required this.title, required this.rim});

  final Recipe recipe;
  final String title;
  final Color rim;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final plate = (width * 0.92).clamp(240.0, 520.0);
      final visible = plate * 0.80;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: visible,
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned(
                  right: -plate * 0.14,
                  top: visible - plate,
                  width: plate,
                  height: plate,
                  child: Plate(recipe: recipe, rim: rim),
                ),
                Positioned(
                  left: 8,
                  top: 8,
                  child: IconButton.filledTonal(
                    tooltip: 'Back',
                    style: IconButton.styleFrom(
                      backgroundColor: Palette.plate,
                      foregroundColor: Palette.ink,
                    ),
                    onPressed: () =>
                        context.canPop() ? context.pop() : context.go('/'),
                    icon: const Icon(Icons.arrow_back),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Text(title, style: Fonts.serif(32)),
          ),
        ],
      );
    },
  );
}

/// On a wide screen the header stays low, so that the whole ingredient list
/// fits beside the steps while cooking. The plate still runs off the corner.
class _WideHeader extends StatelessWidget {
  const _WideHeader({
    required this.recipe,
    required this.title,
    required this.rim,
    required this.controls,
  });

  final Recipe recipe;
  final String title;
  final Color rim;
  final Widget controls;

  @override
  Widget build(BuildContext context) {
    const plate = 290.0;
    return ClipRect(
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -116,
            width: plate,
            height: plate,
            child: Plate(recipe: recipe, rim: rim),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 16, 280, 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  tooltip: 'Back',
                  onPressed: () =>
                      context.canPop() ? context.pop() : context.go('/'),
                  icon: const Icon(Icons.arrow_back),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: Fonts.serif(38)),
                      const SizedBox(height: 12),
                      controls,
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.recipe,
    required this.entry,
    required this.servings,
    required this.onServings,
    required this.showOriginal,
    required this.onOriginal,
    required this.onStart,
    required this.onAdd,
    required this.onDone,
    required this.toBuy,
    required this.onMissing,
    required this.onBought,
  });

  final Recipe recipe;
  final PlannedRecipe? entry;
  final int servings;
  final ValueChanged<int> onServings;
  final bool showOriginal;
  final ValueChanged<bool> onOriginal;
  final VoidCallback onStart;
  final VoidCallback onAdd;
  final VoidCallback onDone;

  /// What is left to buy, while the recipe is on the shopping list.
  final int? toBuy;
  final VoidCallback onMissing;
  final VoidCallback onBought;

  @override
  Widget build(BuildContext context) {
    final cooking = entry?.stage == PlannedStage.cooking;
    final onList = entry?.stage == PlannedStage.onList;
    final minutes = recipe.totalTime;
    final original = recipe.original;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            IconButton.outlined(
              tooltip: 'Fewer servings',
              onPressed: servings > 1 ? () => onServings(servings - 1) : null,
              icon: const Icon(Icons.remove),
            ),
            Text('$servings servings', style: Fonts.sans(17, weight: 600)),
            IconButton.outlined(
              tooltip: 'More servings',
              onPressed: () => onServings(servings + 1),
              icon: const Icon(Icons.add),
            ),
            if (minutes != null)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  '$minutes min',
                  style: Fonts.sans(15, color: Palette.pewter),
                ),
              ),
          ],
        ),
        if (original != null) ...[
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: false,
                label: Text(_languageName(recipe.language)),
              ),
              ButtonSegment(
                value: true,
                label: Text(_languageName(original.language)),
              ),
            ],
            selected: {showOriginal},
            onSelectionChanged: (selected) => onOriginal(selected.first),
          ),
        ],
        if (onList) ...[
          const SizedBox(height: 16),
          Text(switch (toBuy) {
            null => 'Still on the shopping list.',
            0 => 'Still on the shopping list. Everything is ticked.',
            1 => 'Still on the shopping list, with 1 ingredient to buy.',
            final n =>
              'Still on the shopping list, with $n ingredients '
                  'to buy.',
          }, style: Fonts.sans(15, color: Palette.pewter)),
          Wrap(
            spacing: 20,
            children: [
              TextButton(
                style: flushTextButton,
                onPressed: onMissing,
                child: const Text('See what\'s missing'),
              ),
              TextButton(
                style: flushTextButton,
                onPressed: onBought,
                child: const Text('Already bought'),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            if (cooking)
              FilledButton(onPressed: onDone, child: const Text('Done cooking'))
            else
              FilledButton(
                onPressed: onStart,
                child: const Text('Start cooking'),
              ),
            if (!cooking && !onList)
              OutlinedButton(
                onPressed: onAdd,
                child: const Text('Add to shopping list'),
              ),
          ],
        ),
      ],
    );
  }
}

String _languageName(String? code) => switch (code) {
  'sv' => 'Svenska',
  'en' => 'English',
  'da' => 'Dansk',
  'no' || 'nb' => 'Norsk',
  'de' => 'Deutsch',
  'fr' => 'Français',
  'it' => 'Italiano',
  'es' => 'Español',
  null => 'Translated',
  final other => other,
};

class _Ingredients extends StatelessWidget {
  const _Ingredients({
    required this.ingredients,
    required this.from,
    required this.to,
    required this.ticked,
    required this.onTick,
  });

  final IList<Ingredient> ingredients;
  final int from;
  final int to;

  /// Null unless cooking.
  final ISet<String>? ticked;
  final ValueChanged<String> onTick;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    String? group;
    for (final ingredient in ingredients) {
      if (ingredient.group != group) {
        group = ingredient.group;
        if (group != null) {
          rows.add(
            Padding(
              padding: const EdgeInsets.only(top: 14, bottom: 4),
              child: Text(group, style: Fonts.sans(15, weight: 600)),
            ),
          );
        }
      }
      rows.add(
        _Tickable(
          ticked: ticked?.contains(ingredient.id),
          onTick: () => onTick(ingredient.id),
          child: Text(
            cookingText(ingredient, from: from, to: to),
            style: Fonts.sans(18),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ingredients', style: Fonts.serif(24)),
        const SizedBox(height: 8),
        ...rows,
      ],
    );
  }
}

class _Steps extends StatelessWidget {
  const _Steps({
    required this.steps,
    required this.ticked,
    required this.onTick,
  });

  final IList<String> steps;
  final ISet<String>? ticked;
  final ValueChanged<String> onTick;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Steps', style: Fonts.serif(24)),
      const SizedBox(height: 8),
      for (final (index, step) in steps.indexed)
        _Tickable(
          ticked: ticked?.contains('step-$index'),
          onTick: () => onTick('step-$index'),
          leading: Text(
            '${index + 1}',
            style: Fonts.serif(22).copyWith(color: Palette.cobalt),
          ),
          child: Text(step, style: Fonts.sans(19, height: 1.45)),
        ),
    ],
  );
}

class _Tickable extends StatelessWidget {
  const _Tickable({
    required this.ticked,
    required this.onTick,
    required this.child,
    this.leading,
  });

  /// Null when ticking isn't available.
  final bool? ticked;
  final VoidCallback onTick;
  final Widget child;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final isTicked = ticked ?? false;
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (ticked != null) ...[
            RoundTick(ticked: isTicked),
            const SizedBox(width: 12),
          ],
          if (leading case final leading?) ...[
            SizedBox(width: 30, child: leading),
          ],
          Expanded(
            child: Opacity(opacity: isTicked ? 0.45 : 1, child: child),
          ),
        ],
      ),
    );
    return ticked == null ? row : InkWell(onTap: onTick, child: row);
  }
}
