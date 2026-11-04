import 'package:domain/domain.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:glados/glados.dart';

import 'support/builders.dart';

/// Checks that values are equal to an identical copy, and differ from every
/// variation of them. A field missing from `props` makes two different values
/// compare as equal, which would silently break the tests that rely on it.
void hasValueEquality<T>(String name, T Function() make, List<T> variations) {
  test(name, () {
    expect(make(), make());
    expect(make().hashCode, make().hashCode);
    for (final (index, variation) in variations.indexed) {
      expect(variation, isNot(make()), reason: 'variation $index');
    }
  });
}

void main() {
  const onion = LineId('onion', BaseMeasure.count);
  final amount = Amount.exact(BaseMeasure.count, Fraction(2));
  final other = Amount.exact(BaseMeasure.count, Fraction(3));
  final later = t0.add(const Duration(hours: 1));

  group('value equality', () {
    hasValueEquality('Exact', () => Exact(Fraction(1)), [Exact(Fraction(2))]);
    hasValueEquality('Range', () => Range(Fraction(1), Fraction(2)), [
      Range(Fraction(0), Fraction(2)),
      Range(Fraction(1), Fraction(3)),
    ]);
    hasValueEquality<Quantity>('Unspecified', () => const Unspecified(), [
      Exact(Fraction(1)),
    ]);
    hasValueEquality('NamedUnit', () => const NamedUnit('burk'), [
      const NamedUnit('förp'),
    ]);
    hasValueEquality(
      'Amount',
      () => Amount(BaseMeasure.mass, Fraction(1), Fraction(2)),
      [
        Amount(BaseMeasure.volume, Fraction(1), Fraction(2)),
        Amount(BaseMeasure.mass, Fraction(0), Fraction(2)),
        Amount(BaseMeasure.mass, Fraction(1), Fraction(3)),
      ],
    );
    hasValueEquality('Ingredient', () => ingredient('a', id: 'i', name: 'n'), [
      ingredient('a', id: 'x', name: 'n'),
      ingredient('a', id: 'i', name: 'x'),
      ingredient('x', id: 'i', name: 'n'),
      ingredient('a', id: 'i', name: 'n', quantity: Exact(Fraction(1))),
      ingredient('a', id: 'i', name: 'n', unit: StandardUnit.g),
      ingredient('a', id: 'i', name: 'n', text: 't'),
      ingredient('a', id: 'i', name: 'n', note: 'x'),
      ingredient('a', id: 'i', name: 'n', group: 'x'),
      ingredient('a', id: 'i', name: 'n', boughtAs: 'x'),
    ]);
    hasValueEquality('Recipe', () => recipe('r', [], title: 't', servings: 4), [
      recipe('x', [], title: 't', servings: 4),
      recipe('r', [], title: 'x', servings: 4),
      recipe('r', [], title: 't', servings: 2),
      recipe('r', [ingredient('a')], title: 't', servings: 4),
      recipe('r', [], title: 't', servings: 4, tagIds: ['t']),
      recipe('r', [], title: 't', servings: 4, steps: ['s']),
      recipe('r', [], title: 't', servings: 4, language: 'sv'),
      recipe('r', [], title: 't', servings: 4, sourceUrl: 'u'),
      recipe('r', [], title: 't', servings: 4, totalTime: 1),
      recipe('r', [], title: 't', servings: 4, timesCooked: 1),
      recipe('r', [], title: 't', servings: 4, lastCookedAt: t0),
      recipe(
        'r',
        [],
        title: 't',
        servings: 4,
        image: const RecipeImage(storagePath: 'p'),
      ),
      recipe(
        'r',
        [],
        title: 't',
        servings: 4,
        original: const RecipeOriginal(
          language: 'en',
          title: 't',
          ingredients: IListConst([]),
          steps: IListConst([]),
        ),
      ),
    ]);
    hasValueEquality('RecipeImage', () => const RecipeImage(storagePath: 'p'), [
      const RecipeImage(storagePath: 'x'),
      const RecipeImage(storagePath: 'p', sourceUrl: 'u'),
      const RecipeImage(storagePath: 'p', origin: ImageOrigin.ai),
    ]);
    RecipeOriginal original({
      String language = 'en',
      String title = 't',
      List<Ingredient> ingredients = const [],
      List<String> steps = const [],
    }) => RecipeOriginal(
      language: language,
      title: title,
      ingredients: ingredients.lock,
      steps: steps.lock,
    );
    hasValueEquality('RecipeOriginal', original, [
      original(language: 'x'),
      original(title: 'x'),
      original(ingredients: [ingredient('a')]),
      original(steps: ['s']),
    ]);
    Kitchen kitchenValue({
      String id = 'k',
      String name = 'n',
      String ownerId = 'o',
      List<String> memberIds = const ['o'],
      Map<String, String> memberNames = const {},
      String language = 'sv',
    }) => Kitchen(
      id: id,
      name: name,
      ownerId: ownerId,
      memberIds: memberIds.lock,
      memberNames: memberNames.lock,
      language: language,
    );
    hasValueEquality('Kitchen', kitchenValue, [
      kitchenValue(id: 'x'),
      kitchenValue(name: 'x'),
      kitchenValue(ownerId: 'x'),
      kitchenValue(memberIds: ['x']),
      kitchenValue(memberNames: {'o': 'Olle'}),
      kitchenValue(language: 'en'),
    ]);
    hasValueEquality('PlannedRecipe', () => planned('e', 'r'), [
      planned('x', 'r'),
      planned('e', 'x'),
      planned('e', 'r', servings: 9),
      planned('e', 'r', addedAt: later),
      planned('e', 'r', addedBy: 'u'),
      planned('e', 'r', excluded: ['i']),
      planned('e', 'r', done: ['i']),
      planned('e', 'r', shoppedAt: t0),
      planned('e', 'r', cookingStartedAt: t0),
    ]);
    hasValueEquality('ListItem', () => item('i', 'n'), [
      item('x', 'n'),
      item('i', 'x'),
      item('i', 'n', addedAt: later),
      item('i', 'n', addedBy: 'u'),
      item('i', 'n', key: 'k'),
      item('i', 'n', quantity: Exact(Fraction(1))),
      item('i', 'n', unit: StandardUnit.g),
    ]);
    hasValueEquality('LineId', () => onion, [
      const LineId('leek', BaseMeasure.count),
      const LineId('onion', BaseMeasure.mass),
    ]);
    hasValueEquality(
      'Check',
      () => Check(line: onion, at: t0, quantity: Fraction(1), by: 'u'),
      [
        Check(
          line: const LineId('x', BaseMeasure.count),
          at: t0,
          quantity: Fraction(1),
          by: 'u',
        ),
        Check(line: onion, at: later, quantity: Fraction(1), by: 'u'),
        Check(line: onion, at: t0, quantity: Fraction(2), by: 'u'),
        Check(line: onion, at: t0, quantity: Fraction(1), by: 'x'),
      ],
    );
    hasValueEquality('KitchenState', kitchen, [
      kitchen(recipes: [recipe('r', [])]),
      kitchen(planned: [planned('e', 'r')]),
      kitchen(items: [item('i', 'n')]),
      kitchen(staples: {'salt'}),
      kitchen(overrides: {'salt': true}),
      kitchen(
        checks: [Check(line: onion, at: t0)],
      ),
    ]);
    hasValueEquality(
      'Tag',
      () => const Tag(id: 'i', name: 'n', category: TagCategory.diet),
      [
        const Tag(id: 'x', name: 'n', category: TagCategory.diet),
        const Tag(id: 'i', name: 'x', category: TagCategory.diet),
        const Tag(id: 'i', name: 'n', category: TagCategory.meal),
        const Tag(id: 'i', name: 'n', category: TagCategory.diet, key: 'k'),
      ],
    );
    hasValueEquality<CategoryFilter>('AnyOf', () => AnyOf({'a'}.lock), [
      AnyOf({'b'}.lock),
      const NoTags(),
    ]);
    hasValueEquality<CategoryFilter>('NoTags', () => const NoTags(), [
      AnyOf(ISet()),
    ]);
    hasValueEquality('TagFilter', () => const TagFilter(), [
      TagFilter({TagCategory.diet: const NoTags()}.lock),
    ]);
  });

  group('shopping list values', () {
    Line line({
      LineId id = onion,
      String name = 'n',
      Amount? amount,
      IList<Unit> units = const IListConst([]),
      IList<Source> sources = const IListConst([]),
      LineStatus status = const Unchecked(),
    }) => Line(
      id: id,
      name: name,
      amount: amount,
      units: units,
      sources: sources,
      status: status,
    );

    const recipeSource = RecipeSource(
      entryId: 'e',
      recipeId: 'r',
      recipeTitle: 't',
      ingredientId: 'i',
      name: 'n',
      amount: null,
    );

    hasValueEquality<LineStatus>('LineStatus', () => const Unchecked(), [
      PartlyChecked(amount),
      FullyChecked(t0),
    ]);
    hasValueEquality<LineStatus>('PartlyChecked', () => PartlyChecked(amount), [
      PartlyChecked(other),
    ]);
    hasValueEquality<LineStatus>('FullyChecked', () => FullyChecked(t0), [
      FullyChecked(later),
    ]);
    hasValueEquality<Source>('RecipeSource', () => recipeSource, [
      const RecipeSource(
        entryId: 'x',
        recipeId: 'r',
        recipeTitle: 't',
        ingredientId: 'i',
        name: 'n',
        amount: null,
      ),
      const RecipeSource(
        entryId: 'e',
        recipeId: 'x',
        recipeTitle: 't',
        ingredientId: 'i',
        name: 'n',
        amount: null,
      ),
      const RecipeSource(
        entryId: 'e',
        recipeId: 'r',
        recipeTitle: 'x',
        ingredientId: 'i',
        name: 'n',
        amount: null,
      ),
      const RecipeSource(
        entryId: 'e',
        recipeId: 'r',
        recipeTitle: 't',
        ingredientId: 'x',
        name: 'n',
        amount: null,
      ),
      const RecipeSource(
        entryId: 'e',
        recipeId: 'r',
        recipeTitle: 't',
        ingredientId: 'i',
        name: 'x',
        amount: null,
      ),
      RecipeSource(
        entryId: 'e',
        recipeId: 'r',
        recipeTitle: 't',
        ingredientId: 'i',
        name: 'n',
        amount: amount,
      ),
    ]);
    hasValueEquality<Source>(
      'ItemSource',
      () => const ItemSource(itemId: 'i', name: 'n', amount: null),
      [
        const ItemSource(itemId: 'x', name: 'n', amount: null),
        const ItemSource(itemId: 'i', name: 'x', amount: null),
        ItemSource(itemId: 'i', name: 'n', amount: amount),
      ],
    );
    hasValueEquality('Line', line, [
      line(id: const LineId('x', BaseMeasure.count)),
      line(name: 'x'),
      line(amount: amount),
      line(units: [StandardUnit.g as Unit].lock),
      line(sources: [recipeSource as Source].lock),
      line(status: FullyChecked(t0)),
    ]);
    hasValueEquality(
      'ShoppingList',
      () => const ShoppingList(lines: IListConst([]), atHome: IListConst([])),
      [
        ShoppingList(lines: [line()].lock, atHome: const IListConst([])),
        ShoppingList(lines: const IListConst([]), atHome: [line()].lock),
      ],
    );

    RecipeItem recipeItem({
      Ingredient? of,
      Amount? amount,
      bool isHidden = false,
      LineStatus status = const Unchecked(),
      LineId line = const LineId('a', BaseMeasure.none),
    }) => RecipeItem(
      ingredient: of ?? ingredient('a'),
      amount: amount,
      line: line,
      isHidden: isHidden,
      status: status,
    );

    hasValueEquality('RecipeItem', recipeItem, [
      recipeItem(of: ingredient('x')),
      recipeItem(amount: amount),
      recipeItem(line: const LineId('b', BaseMeasure.none)),
      recipeItem(isHidden: true),
      recipeItem(status: FullyChecked(t0)),
    ]);
    hasValueEquality(
      'RecipeGroup',
      () => RecipeGroup(
        entry: planned('e', 'r'),
        recipe: recipe('r', []),
        items: const IListConst([]),
      ),
      [
        RecipeGroup(
          entry: planned('x', 'r'),
          recipe: recipe('r', []),
          items: const IListConst([]),
        ),
        RecipeGroup(
          entry: planned('e', 'r'),
          recipe: recipe('x', []),
          items: const IListConst([]),
        ),
        RecipeGroup(
          entry: planned('e', 'r'),
          recipe: recipe('r', []),
          items: [recipeItem()].lock,
        ),
      ],
    );
    hasValueEquality(
      'ByRecipeView',
      () => const ByRecipeView(recipes: IListConst([]), items: IListConst([])),
      [
        ByRecipeView(
          recipes: [
            RecipeGroup(
              entry: planned('e', 'r'),
              recipe: recipe('r', []),
              items: const IListConst([]),
            ),
          ].lock,
          items: const IListConst([]),
        ),
        ByRecipeView(recipes: const IListConst([]), items: [line()].lock),
      ],
    );
  });

  group('effects', () {
    hasValueEquality<Effect>(
      'SetCheck',
      () => SetCheck(Check(line: onion, at: t0)),
      [SetCheck(Check(line: onion, at: later))],
    );
    hasValueEquality<Effect>('DeleteCheck', () => const DeleteCheck(onion), [
      const DeleteCheck(LineId('x', BaseMeasure.count)),
    ]);
    hasValueEquality<Effect>(
      'CreateListItem',
      () => CreateListItem(item('i', 'n')),
      [CreateListItem(item('x', 'n'))],
    );
    hasValueEquality<Effect>(
      'DeleteListItem',
      () => const DeleteListItem('i'),
      [const DeleteListItem('x')],
    );
    hasValueEquality<Effect>(
      'SetOverride',
      () => const SetOverride('k', include: true),
      [
        const SetOverride('x', include: true),
        const SetOverride('k', include: false),
      ],
    );
    hasValueEquality<Effect>(
      'DeleteOverride',
      () => const DeleteOverride('k'),
      [const DeleteOverride('x')],
    );
    hasValueEquality<Effect>(
      'CreatePlanned',
      () => CreatePlanned(planned('e', 'r')),
      [CreatePlanned(planned('x', 'r'))],
    );
    hasValueEquality<Effect>('UpdatePlanned', () => const UpdatePlanned('e'), [
      const UpdatePlanned('x'),
      UpdatePlanned('e', addDone: {'i'}.lock),
      UpdatePlanned('e', removeDone: {'i'}.lock),
      UpdatePlanned('e', addExcluded: {'i'}.lock),
      UpdatePlanned('e', removeExcluded: {'i'}.lock),
      const UpdatePlanned('e', servings: 2),
      UpdatePlanned('e', shoppedAt: t0),
      const UpdatePlanned('e', clearShoppedAt: true),
      UpdatePlanned('e', cookingStartedAt: t0),
      const UpdatePlanned('e', clearCookingStartedAt: true),
    ]);
    hasValueEquality<Effect>('DeletePlanned', () => const DeletePlanned('e'), [
      const DeletePlanned('x'),
    ]);
    hasValueEquality<Effect>(
      'FinishCooking',
      () => FinishCooking(entryId: 'e', recipeId: 'r', at: t0),
      [
        FinishCooking(entryId: 'x', recipeId: 'r', at: t0),
        FinishCooking(entryId: 'e', recipeId: 'x', at: t0),
        FinishCooking(entryId: 'e', recipeId: 'r', at: later),
      ],
    );
    hasValueEquality<Effect>('DeleteRecipe', () => const DeleteRecipe('r'), [
      const DeleteRecipe('x'),
    ]);
  });
}
