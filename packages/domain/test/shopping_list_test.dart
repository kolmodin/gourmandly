import 'package:domain/domain.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:glados/glados.dart';

import 'support/builders.dart';
import 'support/kitchen_generators.dart';

const dl = StandardUnit.dl;
const ml = StandardUnit.ml;
const st = StandardUnit.st;
const g = StandardUnit.g;

List<String> texts(Iterable<Line> lines) => [for (final l in lines) l.text];

void main() {
  group('scaling', () {
    test('scales ingredients to the planned servings', () {
      final list = shoppingList(
        kitchen(
          recipes: [
            recipe('soup', [amountOfIngredient('cream', 2, dl)], servings: 4),
          ],
          planned: [planned('e1', 'soup', servings: 8)],
        ),
      );
      expect(texts(list.lines), ['4 dl cream']);
    });

    test('a recipe with an unusable servings count is used as written', () {
      final list = shoppingList(
        kitchen(
          recipes: [
            recipe('soup', [amountOfIngredient('cream', 2, dl)], servings: 0),
          ],
          planned: [planned('e1', 'soup', servings: 8)],
        ),
      );
      expect(texts(list.lines), ['2 dl cream']);
    });
  });

  group('which recipes count', () {
    final soup = recipe('soup', [amountOfIngredient('cream', 2, dl)]);

    test('only planned recipes still on the list', () {
      final list = shoppingList(
        kitchen(
          recipes: [soup],
          planned: [planned('e1', 'soup', shoppedAt: t0)],
        ),
      );
      expect(list.lines, isEmpty);
    });

    test('an entry whose recipe is gone is skipped', () {
      final list = shoppingList(kitchen(planned: [planned('e1', 'missing')]));
      expect(list.lines, isEmpty);
    });

    test('excluded and done ingredients are left out', () {
      final list = shoppingList(
        kitchen(
          recipes: [
            recipe('r', [
              amountOfIngredient('cream', 2, dl),
              amountOfIngredient('onion', 1, st),
              amountOfIngredient('leek', 1, st),
            ]),
          ],
          planned: [
            planned('e1', 'r', excluded: ['cream'], done: ['onion']),
          ],
        ),
      );
      expect(texts(list.lines), ['1 st leek']);
    });
  });

  group('merging', () {
    test('identical keys merge', () {
      final list = shoppingList(
        kitchen(
          recipes: [
            recipe('a', [amountOfIngredient('onion', 2, st)]),
            recipe('b', [amountOfIngredient('onion', 3, st)]),
          ],
          planned: [planned('e1', 'a'), planned('e2', 'b')],
        ),
      );
      expect(texts(list.lines), ['5 st onion']);
      expect(list.lines.single.sources, hasLength(2));
    });

    test('different units of one measure merge', () {
      final list = shoppingList(
        kitchen(
          recipes: [
            recipe('a', [amountOfIngredient('cream', 2, dl)]),
            recipe('b', [amountOfIngredient('cream', 100, ml)]),
          ],
          planned: [planned('e1', 'a'), planned('e2', 'b')],
        ),
      );
      expect(texts(list.lines), ['3 dl cream']);
    });

    test('kinds of an ingredient stay separate', () {
      final list = shoppingList(
        kitchen(
          recipes: [
            recipe('a', [
              amountOfIngredient('onion', 2, st),
              amountOfIngredient('red onion', 1, st),
              amountOfIngredient('yellow onion', 1, st),
            ]),
          ],
          planned: [planned('e1', 'a')],
        ),
      );
      expect(list.lines, hasLength(3));
    });

    test('mass and volume of one ingredient are not merged', () {
      final list = shoppingList(
        kitchen(
          recipes: [
            recipe('a', [amountOfIngredient('flour', 2, dl)]),
            recipe('b', [amountOfIngredient('flour', 100, g)]),
          ],
          planned: [planned('e1', 'a'), planned('e2', 'b')],
        ),
      );
      expect(texts(list.lines), unorderedEquals(['2 dl flour', '100 g flour']));
    });

    test('a named unit merges only with itself', () {
      const clove = NamedUnit('klyftor');
      final list = shoppingList(
        kitchen(
          recipes: [
            recipe('a', [
              ingredient(
                'garlic',
                id: 'g1',
                quantity: Exact(Fraction(2)),
                unit: clove,
              ),
              ingredient(
                'garlic',
                id: 'g2',
                quantity: Exact(Fraction(1)),
                unit: st,
              ),
            ]),
            recipe('b', [
              ingredient('garlic', quantity: Exact(Fraction(1)), unit: clove),
            ]),
          ],
          planned: [planned('e1', 'a'), planned('e2', 'b')],
        ),
      );
      expect(
        texts(list.lines),
        unorderedEquals(['3 klyftor garlic', '1 st garlic']),
      );
    });

    test('an ingredient without a quantity is a line of its own', () {
      final list = shoppingList(
        kitchen(
          recipes: [
            recipe('a', [
              ingredient('salt', id: 'i1'),
              ingredient(
                'salt',
                id: 'i2',
                quantity: Exact(Fraction(1)),
                unit: StandardUnit.tsk,
              ),
            ]),
          ],
          planned: [planned('e1', 'a')],
        ),
      );
      expect(texts(list.lines), unorderedEquals(['salt', '1 tsk salt']));
    });

    test('ranges add up to a range', () {
      final list = shoppingList(
        kitchen(
          recipes: [
            recipe('a', [
              ingredient(
                'onion',
                quantity: Range(Fraction(2), Fraction(3)),
                unit: st,
              ),
            ]),
            recipe('b', [amountOfIngredient('onion', 1, st)]),
          ],
          planned: [planned('e1', 'a'), planned('e2', 'b')],
        ),
      );
      expect(texts(list.lines), ['3–4 st onion']);
    });

    test('keys are compared after normalizing', () {
      final list = shoppingList(
        kitchen(
          recipes: [
            recipe('a', [
              ingredient(
                'Red  Onion ',
                id: 'i1',
                quantity: Exact(Fraction(1)),
                unit: st,
              ),
            ]),
            recipe('b', [
              ingredient(
                'red onion',
                id: 'i2',
                quantity: Exact(Fraction(1)),
                unit: st,
              ),
            ]),
          ],
          planned: [planned('e1', 'a'), planned('e2', 'b')],
        ),
      );
      expect(list.lines, hasLength(1));
    });

    test('an ingredient with an empty key falls back to its name', () {
      final list = shoppingList(
        kitchen(
          recipes: [
            recipe('a', [
              ingredient(
                '',
                id: 'i1',
                name: 'Lök',
                quantity: Exact(Fraction(1)),
                unit: st,
              ),
              ingredient(
                '',
                id: 'i2',
                name: 'lök',
                quantity: Exact(Fraction(1)),
                unit: st,
              ),
            ]),
          ],
          planned: [planned('e1', 'a')],
        ),
      );
      expect(texts(list.lines), ['2 st Lök']);
    });
  });

  group('wording', () {
    test('uses the earliest added contribution', () {
      final list = shoppingList(
        kitchen(
          recipes: [
            recipe('late', [
              amountOfIngredient('onion', 1, st, name: 'gul lök'),
            ]),
            recipe('early', [amountOfIngredient('onion', 1, st, name: 'lök')]),
          ],
          planned: [
            planned('e1', 'late', addedAt: t0.add(const Duration(hours: 1))),
            planned('e2', 'early', addedAt: t0),
          ],
        ),
      );
      expect(list.lines.single.name, 'lök');
    });

    test('records added at the same moment are ordered by their ID', () {
      KitchenState state(List<PlannedRecipe> entries) => kitchen(
        recipes: [
          recipe('a', [amountOfIngredient('onion', 1, st, name: 'lök')]),
          recipe('b', [amountOfIngredient('onion', 1, st, name: 'gul lök')]),
        ],
        planned: entries,
      );
      final first = planned('e1', 'a');
      final second = planned('e2', 'b');
      expect(shoppingList(state([first, second])).lines.single.name, 'lök');
      expect(shoppingList(state([second, first])).lines.single.name, 'lök');
    });

    test('a recipe keeps its own order of ingredients', () {
      final list = shoppingList(
        kitchen(
          recipes: [
            recipe('a', [
              ingredient(
                'onion',
                id: 'i1',
                name: 'lök',
                quantity: Exact(Fraction(1)),
                unit: st,
              ),
              ingredient(
                'onion',
                id: 'i2',
                name: 'gul lök',
                quantity: Exact(Fraction(1)),
                unit: st,
              ),
            ]),
          ],
          planned: [planned('e1', 'a')],
        ),
      );
      expect(list.lines.single.name, 'lök');
    });

    test('a long recipe keeps its order too', () {
      final list = shoppingList(
        kitchen(
          recipes: [
            recipe('a', [
              for (var i = 0; i < 100; i++)
                ingredient(
                  'onion',
                  id: 'i$i',
                  name: 'n$i',
                  quantity: Exact(Fraction(1)),
                  unit: st,
                ),
            ]),
          ],
          planned: [planned('e1', 'a')],
        ),
      );
      expect(
        [for (final s in list.lines.single.sources) s.name],
        [for (var i = 0; i < 100; i++) 'n$i'],
      );
    });

    test('sources are listed in the same order', () {
      final list = shoppingList(
        kitchen(
          recipes: [
            recipe('late', [amountOfIngredient('onion', 1, st)]),
            recipe('early', [amountOfIngredient('onion', 1, st)]),
          ],
          planned: [
            planned('e1', 'late', addedAt: t0.add(const Duration(hours: 1))),
            planned('e2', 'early', addedAt: t0),
          ],
        ),
      );
      final sources = list.lines.single.sources;
      expect(
        [for (final s in sources) (s as RecipeSource).recipeTitle],
        ['early', 'late'],
      );
    });
  });

  group('manual items', () {
    test('appear on the list', () {
      final list = shoppingList(kitchen(items: [item('i1', 'mjölk')]));
      expect(texts(list.lines), ['mjölk']);
    });

    test('with a key merge with recipes', () {
      final list = shoppingList(
        kitchen(
          recipes: [
            recipe('a', [amountOfIngredient('milk', 2, dl, name: 'mjölk')]),
          ],
          planned: [planned('e1', 'a')],
          items: [
            item(
              'i1',
              'mjölk',
              key: 'milk',
              quantity: Exact(Fraction(1)),
              unit: dl,
            ),
          ],
        ),
      );
      expect(texts(list.lines), ['3 dl mjölk']);
    });

    test('without a key are never merged', () {
      final list = shoppingList(
        kitchen(items: [item('i1', 'mjölk'), item('i2', 'mjölk')]),
      );
      expect(list.lines, hasLength(2));
    });

    test('are not hidden by the staples filter', () {
      final list = shoppingList(
        kitchen(
          items: [item('i1', 'salt', key: 'salt')],
          staples: {'salt'},
        ),
      );
      expect(texts(list.lines), ['salt']);
      expect(list.atHome, isEmpty);
    });
  });

  group('staples', () {
    final soup = recipe('soup', [
      ingredient('salt', name: 'salt'),
      amountOfIngredient('onion', 2, st),
    ]);

    test('are collapsed under "probably at home"', () {
      final list = shoppingList(
        kitchen(
          recipes: [soup],
          planned: [planned('e1', 'soup')],
          staples: {'salt'},
        ),
      );
      expect(texts(list.lines), ['2 st onion']);
      expect(texts(list.atHome), ['salt']);
    });

    test('an override brings a staple back', () {
      final list = shoppingList(
        kitchen(
          recipes: [soup],
          planned: [planned('e1', 'soup')],
          staples: {'salt'},
          overrides: {'salt': true},
        ),
      );
      expect(texts(list.lines), unorderedEquals(['salt', '2 st onion']));
      expect(list.atHome, isEmpty);
    });

    test('an override can also hide something that is no staple', () {
      final list = shoppingList(
        kitchen(
          recipes: [soup],
          planned: [planned('e1', 'soup')],
          overrides: {'onion': false},
        ),
      );
      expect(texts(list.lines), ['salt']);
      expect(texts(list.atHome), ['2 st onion']);
    });

    test('staples and overrides are compared after normalizing', () {
      final list = shoppingList(
        kitchen(
          recipes: [soup],
          planned: [planned('e1', 'soup')],
          staples: {'Salt '},
          overrides: {' Onion': false},
        ),
      );
      expect(list.lines, isEmpty);
    });
  });

  group('checks', () {
    final soup = recipe('soup', [amountOfIngredient('onion', 3, st)]);
    final extra = recipe('extra', [amountOfIngredient('onion', 2, st)]);
    const onion = LineId('onion', BaseMeasure.count);

    test('a fully checked line moves to the bottom', () {
      final list = shoppingList(
        kitchen(
          recipes: [
            recipe('r', [
              amountOfIngredient('apple', 1, st),
              amountOfIngredient('onion', 1, st),
              amountOfIngredient('zucchini', 1, st),
            ]),
          ],
          planned: [planned('e1', 'r')],
          checks: [
            Check(
              line: const LineId('apple', BaseMeasure.count),
              quantity: Fraction(1),
              at: t0,
            ),
          ],
        ),
      );
      expect(texts(list.lines), ['1 st onion', '1 st zucchini', '1 st apple']);
      expect(list.lines.last.status, isA<FullyChecked>());
    });

    test('checked lines are sorted with the most recent first', () {
      final list = shoppingList(
        kitchen(
          recipes: [
            recipe('r', [
              amountOfIngredient('apple', 1, st),
              amountOfIngredient('onion', 1, st),
            ]),
          ],
          planned: [planned('e1', 'r')],
          checks: [
            Check(
              line: const LineId('apple', BaseMeasure.count),
              quantity: Fraction(1),
              at: t0,
            ),
            Check(
              line: onion,
              quantity: Fraction(1),
              at: t0.add(const Duration(minutes: 1)),
            ),
          ],
        ),
      );
      expect(texts(list.lines), ['1 st onion', '1 st apple']);
    });

    test('more needed after checking shows what is left', () {
      final list = shoppingList(
        kitchen(
          recipes: [soup, extra],
          planned: [planned('e1', 'soup'), planned('e2', 'extra')],
          checks: [Check(line: onion, quantity: Fraction(3), at: t0)],
        ),
      );
      final line = list.lines.single;
      expect(line.status, isA<PartlyChecked>());
      expect(line.text, '2 st onion');
      expect(line.amount, Amount.exact(BaseMeasure.count, Fraction(5)));
    });

    test('a checked line without a quantity is fully checked', () {
      final list = shoppingList(
        kitchen(
          items: [item('i1', 'mjölk', key: 'milk')],
          checks: [Check(line: const LineId('milk', BaseMeasure.none), at: t0)],
        ),
      );
      expect(list.lines.single.status, isA<FullyChecked>());
    });

    test('a check without a quantity covers everything', () {
      final list = shoppingList(
        kitchen(
          recipes: [soup],
          planned: [planned('e1', 'soup')],
          checks: [Check(line: onion, at: t0)],
        ),
      );
      expect(list.lines.single.status, isA<FullyChecked>());
    });

    test('checks apply to manual items without a key', () {
      final list = shoppingList(
        kitchen(
          items: [item('i1', 'mjölk')],
          checks: [
            Check(line: const LineId('item:i1', BaseMeasure.none), at: t0),
          ],
        ),
      );
      expect(list.lines.single.status, isA<FullyChecked>());
    });

    test('hidden staples are never shown as checked', () {
      final list = shoppingList(
        kitchen(
          recipes: [soup],
          planned: [planned('e1', 'soup')],
          staples: {'onion'},
          checks: [Check(line: onion, quantity: Fraction(3), at: t0)],
        ),
      );
      expect(list.atHome.single.status, isA<Unchecked>());
    });

    test('checkLine covers the whole amount', () {
      final state = kitchen(
        recipes: [
          recipe('r', [
            ingredient(
              'onion',
              quantity: Range(Fraction(2), Fraction(3)),
              unit: st,
            ),
          ]),
        ],
        planned: [planned('e1', 'r')],
      );
      final line = shoppingList(state).lines.single;
      expect(
        checkLine(line, at: t0, by: 'u1'),
        SetCheck(Check(line: onion, quantity: Fraction(3), at: t0, by: 'u1')),
      );
    });

    test('checkLine on a line without a quantity stores none', () {
      final line = shoppingList(kitchen(items: [item('i1', 'mjölk')]))
          .lines
          .single;
      expect(
        checkLine(line, at: t0, by: 'u1'),
        SetCheck(Check(line: line.id, at: t0, by: 'u1')),
      );
    });

    test('uncheckLine deletes the check', () {
      final line = shoppingList(kitchen(items: [item('i1', 'mjölk')]))
          .lines
          .single;
      expect(uncheckLine(line), DeleteCheck(line.id));
    });
  });

  group('sorting', () {
    test('open lines are alphabetical, ignoring accents and case', () {
      final list = shoppingList(
        kitchen(
          items: [
            item('1', 'Ägg'),
            item('2', 'banan'),
            item('3', 'Zucchini'),
            item('4', 'lök'),
            item('5', 'lime'),
          ],
        ),
      );
      expect(texts(list.lines), ['Ägg', 'banan', 'lime', 'lök', 'Zucchini']);
    });
  });

  group('export', () {
    test('writes one line per open line', () {
      final list = shoppingList(
        kitchen(
          recipes: [
            recipe('a', [
              amountOfIngredient('onion', 5, st, name: 'gul lök'),
              amountOfIngredient('cream', 3, dl, name: 'grädde'),
            ]),
          ],
          planned: [planned('e1', 'a')],
          items: [item('i1', 'mjölk')],
        ),
      );
      expect(exportList(list), '3 dl grädde\n5 st gul lök\nmjölk');
    });

    test('leaves out checked lines and hidden staples', () {
      final list = shoppingList(
        kitchen(
          recipes: [
            recipe('a', [
              amountOfIngredient('onion', 5, st),
              amountOfIngredient('cream', 3, dl),
              ingredient('salt'),
            ]),
          ],
          planned: [planned('e1', 'a')],
          staples: {'salt'},
          checks: [
            Check(
              line: const LineId('cream', BaseMeasure.volume),
              quantity: Fraction(300),
              at: t0,
            ),
          ],
        ),
      );
      expect(exportList(list), '5 st onion');
    });

    test('a partly checked line exports what is left', () {
      final list = shoppingList(
        kitchen(
          recipes: [
            recipe('a', [amountOfIngredient('onion', 5, st)]),
          ],
          planned: [planned('e1', 'a')],
          checks: [
            Check(
              line: const LineId('onion', BaseMeasure.count),
              quantity: Fraction(3),
              at: t0,
            ),
          ],
        ),
      );
      expect(exportList(list), '2 st onion');
    });

    test('an empty list exports nothing', () {
      expect(exportList(shoppingList(kitchen())), '');
    });
  });

  group('by recipe', () {
    test('groups the list by planned recipe, oldest first', () {
      final state = kitchen(
        recipes: [
          recipe('late', [amountOfIngredient('onion', 1, st)], servings: 2),
          recipe('early', [amountOfIngredient('cream', 1, dl)], servings: 2),
        ],
        planned: [
          planned(
            'e1',
            'late',
            servings: 4,
            addedAt: t0.add(const Duration(hours: 1)),
          ),
          planned('e2', 'early', servings: 2, addedAt: t0),
        ],
        items: [item('i1', 'mjölk')],
      );
      final view = byRecipe(state);
      expect([for (final g in view.recipes) g.recipe.id], ['early', 'late']);
      expect(view.recipes.last.items.single.text, '2 st onion');
      expect(view.items.single.name, 'mjölk');
    });

    test('marks hidden staples and leaves out excluded and done items', () {
      final state = kitchen(
        recipes: [
          recipe('r', [
            ingredient('salt'),
            amountOfIngredient('onion', 1, st),
            amountOfIngredient('cream', 1, dl),
            amountOfIngredient('leek', 1, st),
          ]),
        ],
        planned: [
          planned('e1', 'r', excluded: ['cream'], done: ['leek']),
        ],
        staples: {'salt'},
      );
      final items = byRecipe(state).recipes.single.items;
      expect([for (final i in items) i.ingredient.id], ['salt', 'onion']);
      expect(items.first.isHidden, isTrue);
      expect(items.last.isHidden, isFalse);
    });

    test('an item shows the status of its merged line', () {
      final state = kitchen(
        recipes: [
          recipe('a', [amountOfIngredient('onion', 1, st)]),
          recipe('b', [
            amountOfIngredient('onion', 2, st),
            amountOfIngredient('leek', 2, st),
          ]),
        ],
        planned: [planned('e1', 'a'), planned('e2', 'b')],
        checks: [
          Check(
            line: const LineId('onion', BaseMeasure.count),
            quantity: Fraction(3),
            at: t0,
          ),
        ],
      );
      final groups = byRecipe(state).recipes;
      expect(groups.first.items.single.status, isA<FullyChecked>());
      expect(groups.last.items.last.status, isA<Unchecked>());
      expect(
        groups.first.items.single.line,
        const LineId('onion', BaseMeasure.count),
      );
    });

    test('counts what is still to buy', () {
      final state = kitchen(
        recipes: [
          recipe('r', [
            ingredient('salt'),
            amountOfIngredient('onion', 1, st),
            amountOfIngredient('cream', 1, dl),
            amountOfIngredient('leek', 2, st),
          ]),
        ],
        planned: [planned('e1', 'r')],
        checks: [
          Check(
            line: const LineId('onion', BaseMeasure.count),
            quantity: Fraction(1),
            at: t0,
          ),
          Check(
            line: const LineId('leek', BaseMeasure.count),
            quantity: Fraction(1),
            at: t0,
          ),
        ],
        staples: {'salt'},
      );
      // Salt is a staple and the onion is ticked; half the leeks still count.
      final group = byRecipe(state).recipes.single;
      expect(
        [for (final i in group.missing) i.ingredient.id],
        ['cream', 'leek'],
      );
      expect(group.toBuy, 2);
      expect(group.bought, 1);
    });

    test('counts cleared ingredients as bought', () {
      final state = kitchen(
        recipes: [
          recipe('r', [
            amountOfIngredient('onion', 1, st),
            amountOfIngredient('cream', 1, dl),
            amountOfIngredient('leek', 1, st),
          ]),
        ],
        planned: [
          planned('e1', 'r', done: ['onion'], excluded: ['cream']),
        ],
      );
      final group = byRecipe(state).recipes.single;
      expect(group.toBuy, 1);
      expect(group.bought, 1);
    });

    test('an item without a quantity is just its name', () {
      final state = kitchen(
        recipes: [
          recipe('r', [ingredient('salt', name: 'salt')]),
        ],
        planned: [planned('e1', 'r')],
      );
      expect(byRecipe(state).recipes.single.items.single.text, 'salt');
    });

    test('skips entries off the list and missing recipes', () {
      final state = kitchen(
        recipes: [
          recipe('r', [amountOfIngredient('onion', 1, st)]),
        ],
        planned: [
          planned('e1', 'r', shoppedAt: t0),
          planned('e2', 'gone'),
        ],
      );
      expect(byRecipe(state).recipes, isEmpty);
    });
  });

  group('laws', () {
    Glados(any.kitchenState, thorough).test(
      'the order of records does not matter',
      (state) {
        final shuffled = state.copyWith(
          planned: state.planned.reversed,
          items: state.items.reversed,
          checks: state.checks.reversed,
        );
        expect(shoppingList(shuffled), shoppingList(state));
      },
    );

    Glados(any.kitchenState, thorough).test('no amount is lost or invented', (
      state,
    ) {
      final list = shoppingList(state);
      final fromLines = totalsByMeasure([...list.lines, ...list.atHome]);
      expect(fromLines, contributedTotals(state));
    });

    Glados(any.kitchenState, thorough).test(
      'every line has a distinct identity',
      (state) {
        final ids = [for (final l in shoppingList(state).lines) l.id];
        expect(ids.toSet(), hasLength(ids.length));
      },
    );

    Glados(
      any.kitchenState,
      thorough,
    ).test('doubling every planned recipe doubles every recipe line', (state) {
      final recipesOnly = state.copyWith(items: const IListConst([]));
      final doubled = recipesOnly.copyWith(
        planned: [for (final p in state.planned) p.withServings(p.servings * 2)]
            .lock,
      );
      final before = {
        for (final l in shoppingList(recipesOnly).lines) l.id: l.amount,
      };
      for (final line in shoppingList(doubled).lines) {
        expect(line.amount, before[line.id]?.scaled(Fraction(2)));
      }
    });

    Glados(any.kitchenState, thorough).test(
      'the export has exactly the open lines',
      (state) {
        final list = shoppingList(state);
        final open = list.lines.where((l) => l.status is! FullyChecked);
        expect(exportList(list), open.map((l) => l.text).join('\n'));
      },
    );

    Glados(any.kitchenState, thorough).test(
      'open lines come before checked lines',
      (state) {
        final lines = shoppingList(state).lines;
        final firstChecked = lines.indexWhere((l) => l.status is FullyChecked);
        if (firstChecked == -1) return;
        expect(
          lines.skip(firstChecked).every((l) => l.status is FullyChecked),
          isTrue,
        );
      },
    );
  });
}
