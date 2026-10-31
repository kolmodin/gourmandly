import 'package:domain/domain.dart';
import 'package:domain/testing.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:glados/glados.dart';

import 'support/builders.dart';
import 'support/kitchen_generators.dart';

const st = StandardUnit.st;
const dl = StandardUnit.dl;
const onion = LineId('onion', BaseMeasure.count);
const leek = LineId('leek', BaseMeasure.count);

Check checked(LineId line, int quantity, {DateTime? at}) =>
    Check(line: line, quantity: Fraction(quantity), at: at ?? t0);

void main() {
  final soup = recipe('soup', [
    amountOfIngredient('onion', 2, st),
    amountOfIngredient('leek', 1, st),
  ]);

  group('clearChecked', () {
    test('marks recipe ingredients done and removes the check', () {
      final state = kitchen(
        recipes: [soup],
        planned: [planned('e1', 'soup')],
        checks: [checked(onion, 2)],
      );
      expect(clearChecked(state, now: t0, isComplete: true), [
        const DeleteCheck(onion),
        UpdatePlanned('e1', addDone: {'onion'}.lock),
      ]);
    });

    test('deletes manual items', () {
      const line = LineId('item:i1', BaseMeasure.none);
      final state = kitchen(
        items: [item('i1', 'mjölk')],
        checks: [Check(line: line, at: t0)],
      );
      expect(clearChecked(state, now: t0, isComplete: true), [
        const DeleteListItem('i1'),
        const DeleteCheck(line),
      ]);
    });

    test('leaves unchecked and partly checked lines alone', () {
      final state = kitchen(
        recipes: [soup],
        planned: [planned('e1', 'soup')],
        checks: [checked(onion, 1)],
      );
      expect(clearChecked(state, now: t0, isComplete: true), isEmpty);
    });

    test('a recipe with nothing left to buy moves to "to cook"', () {
      final state = kitchen(
        recipes: [soup],
        planned: [planned('e1', 'soup')],
        checks: [checked(onion, 2), checked(leek, 1)],
      );
      final after = applyEffects(
        state,
        clearChecked(state, now: t0, isComplete: true),
      );
      final entry = after.planned.single;
      expect(entry.stage, PlannedStage.toCook);
      expect(entry.shoppedAt, t0);
      expect(entry.done, {'onion', 'leek'}.lock);
    });

    test('excluded ingredients and staples count as nothing left to buy', () {
      final state = kitchen(
        recipes: [
          recipe('r', [
            amountOfIngredient('onion', 2, st),
            amountOfIngredient('cream', 1, dl),
            ingredient('salt'),
          ]),
        ],
        planned: [
          planned('e1', 'r', excluded: ['cream']),
        ],
        staples: {'salt'},
        checks: [checked(onion, 2)],
      );
      final after = applyEffects(
        state,
        clearChecked(state, now: t0, isComplete: true),
      );
      expect(after.planned.single.stage, PlannedStage.toCook);
    });

    test('a brought back staple still has to be bought', () {
      final state = kitchen(
        recipes: [
          recipe('r', [amountOfIngredient('onion', 2, st), ingredient('salt')]),
        ],
        planned: [planned('e1', 'r')],
        staples: {'salt'},
        overrides: {'salt': true},
        checks: [checked(onion, 2)],
      );
      final after = applyEffects(
        state,
        clearChecked(state, now: t0, isComplete: true),
      );
      expect(after.planned.single.stage, PlannedStage.onList);
    });

    test('a recipe of nothing but staples moves on too', () {
      final state = kitchen(
        recipes: [
          recipe('r', [ingredient('salt')]),
        ],
        planned: [planned('e1', 'r')],
        staples: {'salt'},
      );
      expect(clearChecked(state, now: t0, isComplete: true), [
        UpdatePlanned('e1', shoppedAt: t0),
      ]);
    });

    test('a merged line clears every recipe that contributes', () {
      final state = kitchen(
        recipes: [
          recipe('a', [
            amountOfIngredient('onion', 1, st),
            amountOfIngredient('leek', 1, st),
          ]),
          recipe('b', [
            amountOfIngredient('onion', 2, st),
            amountOfIngredient('leek', 1, st),
          ]),
        ],
        planned: [planned('e1', 'a'), planned('e2', 'b')],
        checks: [checked(onion, 3)],
      );
      final after = applyEffects(
        state,
        clearChecked(state, now: t0, isComplete: true),
      );
      expect(after.planned[0].done, {'onion'}.lock);
      expect(after.planned[1].done, {'onion'}.lock);
    });

    test('removes the override of a cleared key', () {
      const salt = LineId('salt', BaseMeasure.none);
      final state = kitchen(
        recipes: [
          recipe('r', [ingredient('salt'), amountOfIngredient('onion', 1, st)]),
        ],
        planned: [planned('e1', 'r')],
        staples: {'salt'},
        overrides: {'salt': true},
        checks: [Check(line: salt, at: t0)],
      );
      expect(
        clearChecked(state, now: t0, isComplete: true),
        contains(const DeleteOverride('salt')),
      );
    });

    test('keeps an override another line of the key still depends on', () {
      const saltPieces = LineId('salt', BaseMeasure.count);
      final state = kitchen(
        recipes: [
          recipe('r', [
            ingredient('salt', id: 's1'),
            ingredient(
              'salt',
              id: 's2',
              quantity: Exact(Fraction(1)),
              unit: st,
            ),
          ]),
        ],
        planned: [planned('e1', 'r')],
        staples: {'salt'},
        overrides: {'salt': true},
        checks: [checked(saltPieces, 1)],
      );
      expect(
        clearChecked(state, now: t0, isComplete: true),
        isNot(contains(const DeleteOverride('salt'))),
      );
    });

    test('keeps an override that hides something', () {
      final state = kitchen(
        recipes: [
          recipe('r', [amountOfIngredient('onion', 1, st)]),
        ],
        items: [item('i1', 'lök', key: 'onion')],
        planned: [planned('e1', 'r')],
        overrides: {'onion': false},
        checks: [Check(line: const LineId('onion', BaseMeasure.none), at: t0)],
      );
      expect(
        clearChecked(state, now: t0, isComplete: true),
        isNot(contains(const DeleteOverride('onion'))),
      );
    });

    test('removes checks whose line no longer exists', () {
      final state = kitchen(checks: [checked(onion, 2)]);
      expect(clearChecked(state, now: t0, isComplete: true), [
        const DeleteCheck(onion),
      ]);
    });

    test('removes a check on a line that is now a hidden staple', () {
      final state = kitchen(
        recipes: [soup],
        planned: [
          planned('e1', 'soup', done: ['leek']),
        ],
        staples: {'onion'},
        checks: [checked(onion, 2)],
      );
      expect(
        clearChecked(state, now: t0, isComplete: true),
        contains(const DeleteCheck(onion)),
      );
    });

    test('keeps leftover checks while the state may be incomplete', () {
      final state = kitchen(checks: [checked(onion, 2)]);
      expect(clearChecked(state, now: t0, isComplete: false), isEmpty);
    });

    test('still clears what it can see while incomplete', () {
      final state = kitchen(
        recipes: [soup],
        planned: [planned('e1', 'soup')],
        checks: [
          checked(onion, 2),
          checked(const LineId('x', BaseMeasure.mass), 1),
        ],
      );
      final effects = clearChecked(state, now: t0, isComplete: false);
      expect(effects, contains(const DeleteCheck(onion)));
      expect(
        effects,
        isNot(contains(const DeleteCheck(LineId('x', BaseMeasure.mass)))),
      );
    });

    test('skips entries whose recipe is gone', () {
      final state = kitchen(planned: [planned('e1', 'missing')]);
      expect(clearChecked(state, now: t0, isComplete: true), isEmpty);
    });
  });

  group('autoClear', () {
    final now = t0.add(const Duration(hours: 24));

    test('clears lines checked more than 24 hours ago', () {
      final state = kitchen(
        recipes: [soup],
        planned: [planned('e1', 'soup')],
        checks: [
          checked(
            onion,
            2,
            at: now.subtract(const Duration(hours: 24, seconds: 1)),
          ),
        ],
      );
      expect(autoClear(state, now: now), contains(const DeleteCheck(onion)));
    });

    test('leaves lines checked exactly 24 hours ago', () {
      final state = kitchen(
        recipes: [soup],
        planned: [planned('e1', 'soup')],
        checks: [
          checked(onion, 2, at: now.subtract(const Duration(hours: 24))),
        ],
      );
      expect(autoClear(state, now: now), isEmpty);
    });

    test('leaves recent lines while clearing old ones', () {
      final state = kitchen(
        recipes: [soup],
        planned: [planned('e1', 'soup')],
        checks: [
          checked(onion, 2, at: now.subtract(const Duration(hours: 25))),
          checked(leek, 1, at: now.subtract(const Duration(hours: 1))),
        ],
      );
      final after = applyEffects(state, autoClear(state, now: now));
      expect(after.checks.single.line, leek);
      expect(after.planned.single.stage, PlannedStage.onList);
    });

    test('keeps a recent orphaned check: the recipes may not have synced', () {
      final state = kitchen(checks: [checked(onion, 2, at: now)]);
      expect(autoClear(state, now: now), isEmpty);
    });

    test('removes an old orphaned check', () {
      final state = kitchen(
        checks: [
          checked(onion, 2, at: now.subtract(const Duration(hours: 25))),
        ],
      );
      expect(autoClear(state, now: now), [const DeleteCheck(onion)]);
    });
  });

  group('laws', () {
    Glados(any.kitchenState, thorough).test(
      'nothing checked remains after clearing',
      (state) {
        final after = applyEffects(
          state,
          clearChecked(state, now: t0, isComplete: true),
        );
        expect(
          shoppingList(after).lines.where((l) => l.status is FullyChecked),
          isEmpty,
        );
      },
    );

    Glados(any.kitchenState, thorough).test(
      'clearing leaves open lines untouched',
      (state) {
        List<Line> open(KitchenState s) =>
            shoppingList(s).lines
                .where((l) => l.status is! FullyChecked)
                .toList();
        final after = applyEffects(
          state,
          clearChecked(state, now: t0, isComplete: true),
        );
        expect(open(after), open(state));
      },
    );

    Glados(any.kitchenState, thorough).test(
      'clearing twice changes nothing more',
      (state) {
        final after = applyEffects(
          state,
          clearChecked(state, now: t0, isComplete: true),
        );
        expect(clearChecked(after, now: t0, isComplete: true), isEmpty);
      },
    );

    Glados(any.kitchenState, thorough).test(
      'no check survives without a visible line',
      (state) {
        final after = applyEffects(
          state,
          clearChecked(state, now: t0, isComplete: true),
        );
        final lines = {for (final l in shoppingList(after).lines) l.id};
        for (final check in after.checks) {
          expect(lines, contains(check.line));
        }
      },
    );

    Glados(
      any.kitchenState,
      thorough,
    ).test('automatic clearing is manual clearing, later', (state) {
      final later = t0.add(const Duration(days: 30));
      expect(
        applyEffects(state, autoClear(state, now: later)),
        applyEffects(state, clearChecked(state, now: later, isComplete: true)),
      );
    });

    Glados(any.kitchenState, thorough).test(
      'automatic clearing keeps recent lines',
      (state) {
        final after = applyEffects(state, autoClear(state, now: t0));
        expect(shoppingList(after).lines, shoppingList(state).lines);
      },
    );

    Glados(any.kitchenState, thorough).test(
      'two clients clearing at once agree',
      (state) {
        final effects = clearChecked(state, now: t0, isComplete: true);
        final once = applyEffects(state, effects);
        final twice = applyEffects(once, effects);
        expect(twice, once);
      },
    );
  });
}
