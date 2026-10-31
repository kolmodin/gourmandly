import 'package:domain/domain.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:glados/glados.dart';

import 'support/apply.dart';
import 'support/builders.dart';
import 'support/kitchen_generators.dart';

const st = StandardUnit.st;
const onion = LineId('onion', BaseMeasure.count);

void main() {
  final soup = recipe('soup', [
    amountOfIngredient('onion', 2, st),
    amountOfIngredient('leek', 1, st),
  ]);
  final later = t0.add(const Duration(hours: 1));

  group('stage', () {
    test('follows the timestamps', () {
      expect(planned('e', 'r').stage, PlannedStage.onList);
      expect(planned('e', 'r', shoppedAt: t0).stage, PlannedStage.toCook);
      expect(
        planned('e', 'r', shoppedAt: t0, cookingStartedAt: t0).stage,
        PlannedStage.cooking,
      );
    });
  });

  group('toCook', () {
    test('lists shopped recipes, with cooking ones first', () {
      final state = kitchen(
        planned: [
          planned('a', 'r', shoppedAt: t0),
          planned('b', 'r'),
          planned('c', 'r', shoppedAt: later, cookingStartedAt: later),
          planned('d', 'r', shoppedAt: t0.subtract(const Duration(hours: 1))),
        ],
      );
      expect([for (final e in toCook(state)) e.id], ['c', 'd', 'a']);
    });

    test('breaks ties by ID', () {
      final state = kitchen(
        planned: [
          planned('b', 'r', shoppedAt: t0),
          planned('a', 'r', shoppedAt: t0),
        ],
      );
      expect([for (final e in toCook(state)) e.id], ['a', 'b']);
    });
  });

  group('plannedEntryFor', () {
    test('finds nothing for an unplanned recipe', () {
      expect(plannedEntryFor(kitchen(), 'r'), isNull);
    });

    test('prefers the entry furthest along', () {
      final cooking = planned('c', 'r', shoppedAt: t0, cookingStartedAt: t0);
      final shopped = planned('b', 'r', shoppedAt: t0);
      final onList = planned('a', 'r');
      expect(
        plannedEntryFor(kitchen(planned: [onList, shopped, cooking]), 'r'),
        cooking,
      );
      expect(
        plannedEntryFor(kitchen(planned: [onList, shopped]), 'r'),
        shopped,
      );
      expect(plannedEntryFor(kitchen(planned: [onList]), 'r'), onList);
    });

    test('ignores other recipes', () {
      expect(
        plannedEntryFor(kitchen(planned: [planned('a', 'x')]), 'r'),
        isNull,
      );
    });
  });

  group('markShopped', () {
    test('sets shoppedAt', () {
      expect(
        markShopped(planned('e1', 'soup'), now: t0),
        UpdatePlanned('e1', shoppedAt: t0),
      );
    });
  });

  group('bringStapleBack', () {
    test('sets an include override', () {
      expect(
        bringStapleBack('Salt '),
        const SetOverride('salt', include: true),
      );
    });
  });

  group('doneShopping', () {
    final state = kitchen(
      recipes: [soup],
      planned: [
        planned('e1', 'soup'),
        planned('e2', 'soup', shoppedAt: t0),
      ],
      items: [item('i1', 'mjölk')],
      overrides: {'salt': true},
      checks: [Check(line: onion, quantity: Fraction(2), at: t0)],
    );

    test('everything bought empties the list', () {
      final after = applyEffects(
        state,
        doneShopping(state, DoneShopping.everythingBought, now: later),
      );
      expect(shoppingList(after).lines, isEmpty);
      expect(after.items, isEmpty);
      expect(after.checks, isEmpty);
      expect(after.overrides, isEmpty);
      expect(after.planned.first.shoppedAt, later);
    });

    test('everything bought leaves recipes that were already shopped', () {
      final after = applyEffects(
        state,
        doneShopping(state, DoneShopping.everythingBought, now: later),
      );
      expect(after.planned.last.shoppedAt, t0);
    });

    test('keeping unchecked items clears only what was checked', () {
      final after = applyEffects(
        state,
        doneShopping(state, DoneShopping.keepUnchecked, now: later),
      );
      expect(after.items, hasLength(1));
      expect(after.planned.first.done, {'onion'}.lock);
      expect(after.planned.first.stage, PlannedStage.onList);
    });

    Glados(any.kitchenState, thorough).test(
      'everything bought leaves nothing to buy',
      (state) {
        final after = applyEffects(
          state,
          doneShopping(state, DoneShopping.everythingBought, now: t0),
        );
        expect(shoppingList(after).lines, isEmpty);
        expect(shoppingList(after).atHome, isEmpty);
      },
    );
  });

  group('startCooking', () {
    group('a recipe on the shopping list', () {
      final entry = planned('e1', 'soup', excluded: ['leek']);
      final other = recipe('other', [amountOfIngredient('onion', 3, st)]);
      final state = kitchen(
        recipes: [soup, other],
        planned: [entry, planned('e2', 'other')],
      );
      final started = startCooking(
        recipe: soup,
        entry: entry,
        servings: 6,
        now: later,
        newEntryId: 'unused',
      );
      final after = applyEffects(state, started.effects);

      test('ticks off only its own share of a merged line', () {
        expect(shoppingList(state).lines.single.text, '5 st onion');
        expect(shoppingList(after).lines.single.text, '3 st onion');
      });

      test('marks it shopped and cooking at the chosen servings', () {
        final updated = after.planned.first;
        expect(updated.stage, PlannedStage.cooking);
        expect(updated.shoppedAt, later);
        expect(updated.cookingStartedAt, later);
        expect(updated.servings, 6);
      });

      test('does not tick what was excluded', () {
        expect(after.planned.first.done, {'onion'}.lock);
      });

      test('can be undone', () {
        expect(applyEffects(after, started.undo), state);
      });
    });

    test('keeps what was already done when undoing', () {
      final entry = planned('e1', 'soup', done: ['leek']);
      final state = kitchen(recipes: [soup], planned: [entry]);
      final started = startCooking(
        recipe: soup,
        entry: entry,
        servings: 4,
        now: later,
        newEntryId: 'unused',
      );
      expect(
        applyEffects(applyEffects(state, started.effects), started.undo),
        state,
      );
    });

    group('a recipe that is not planned', () {
      final state = kitchen(recipes: [soup], items: [item('i1', 'mjölk')]);
      final started = startCooking(
        recipe: soup,
        servings: 2,
        now: later,
        newEntryId: 'new',
      );
      final after = applyEffects(state, started.effects);

      test('creates an entry that is already cooking', () {
        final entry = after.planned.single;
        expect(entry.id, 'new');
        expect(entry.recipeId, 'soup');
        expect(entry.servings, 2);
        expect(entry.stage, PlannedStage.cooking);
        expect(entry.shoppedAt, later);
      });

      test('never touches the shopping list', () {
        expect(shoppingList(after), shoppingList(state));
      });

      test('can be undone', () {
        expect(applyEffects(after, started.undo), state);
      });
    });

    group('a shopped recipe', () {
      final entry = planned('e1', 'soup', shoppedAt: t0);
      final state = kitchen(recipes: [soup], planned: [entry]);
      final started = startCooking(
        recipe: soup,
        entry: entry,
        servings: 4,
        now: later,
        newEntryId: 'unused',
      );

      test('keeps its shopped time', () {
        final after = applyEffects(state, started.effects);
        expect(after.planned.single.stage, PlannedStage.cooking);
        expect(after.planned.single.shoppedAt, t0);
      });

      test('can be undone', () {
        expect(
          applyEffects(applyEffects(state, started.effects), started.undo),
          state,
        );
      });
    });

    group('a recipe already cooking', () {
      final entry = planned('e1', 'soup', shoppedAt: t0, cookingStartedAt: t0);
      final state = kitchen(recipes: [soup], planned: [entry]);

      test('reopening only changes the servings', () {
        final started = startCooking(
          recipe: soup,
          entry: entry,
          servings: 6,
          now: later,
          newEntryId: 'unused',
        );
        final after = applyEffects(state, started.effects);
        expect(after.planned.single.cookingStartedAt, t0);
        expect(after.planned.single.servings, 6);
        expect(applyEffects(after, started.undo), state);
      });
    });

    Glados(any.kitchenState, thorough).test('undo restores the state exactly', (
      state,
    ) {
      for (final entry in state.planned) {
        final recipe = state.recipes[entry.recipeId]!;
        final started = startCooking(
          recipe: recipe,
          entry: entry,
          servings: entry.servings + 1,
          now: later,
          newEntryId: 'new',
        );
        final after = applyEffects(state, started.effects);
        expect(applyEffects(after, started.undo), state);
      }
    });

    Glados(any.kitchenState, thorough).test(
      'starting removes exactly the share of that recipe',
      (state) {
        for (final entry in state.planned) {
          if (entry.stage != PlannedStage.onList) continue;
          final recipe = state.recipes[entry.recipeId]!;
          final started = startCooking(
            recipe: recipe,
            entry: entry,
            servings: entry.servings,
            now: later,
            newEntryId: 'new',
          );
          final without = state.copyWith(
            planned: state.planned.where((e) => e.id != entry.id).toIList(),
          );
          expect(
            contributedTotals(applyEffects(state, started.effects)),
            contributedTotals(without),
          );
        }
      },
    );
  });

  group('doneCooking', () {
    test('deletes the entry and records it on the recipe', () {
      final entry = planned('e1', 'soup', shoppedAt: t0, cookingStartedAt: t0);
      expect(doneCooking(entry, now: later), [
        const DeletePlanned('e1'),
        RecordCooked('soup', later),
      ]);
    });
  });

  group('finishForgotten', () {
    final started = t0;
    final entry = planned(
      'e1',
      'soup',
      shoppedAt: t0,
      cookingStartedAt: started,
    );

    test('finishes cooking started more than 24 hours ago', () {
      final now = started.add(const Duration(hours: 24, seconds: 1));
      expect(finishForgotten(kitchen(planned: [entry]), now: now), [
        const DeletePlanned('e1'),
        RecordCooked('soup', started),
      ]);
    });

    test('leaves cooking started exactly 24 hours ago', () {
      final now = started.add(const Duration(hours: 24));
      expect(finishForgotten(kitchen(planned: [entry]), now: now), isEmpty);
    });

    test('ignores recipes that are not cooking', () {
      final now = started.add(const Duration(days: 30));
      expect(
        finishForgotten(
          kitchen(
            planned: [
              planned('e2', 'soup'),
              planned('e3', 'soup', shoppedAt: t0),
            ],
          ),
          now: now,
        ),
        isEmpty,
      );
    });
  });

  group('deleteRecipe', () {
    test('deletes the recipe and every planned entry for it', () {
      final state = kitchen(
        recipes: [soup],
        planned: [
          planned('e1', 'soup'),
          planned('e2', 'other'),
          planned('e3', 'soup', shoppedAt: t0),
        ],
      );
      expect(deleteRecipe(state, 'soup'), [
        const DeleteRecipe('soup'),
        const DeletePlanned('e1'),
        const DeletePlanned('e3'),
      ]);
    });
  });

  group('cookingText', () {
    test('scales an ingredient to the chosen servings', () {
      expect(
        cookingText(
          amountOfIngredient('cream', 2, StandardUnit.dl, name: 'grädde'),
          from: 4,
          to: 6,
        ),
        '3 dl grädde',
      );
    });

    test('an ingredient without a quantity is just its name', () {
      expect(
        cookingText(ingredient('salt', name: 'salt'), from: 4, to: 6),
        'salt',
      );
    });
  });
}
