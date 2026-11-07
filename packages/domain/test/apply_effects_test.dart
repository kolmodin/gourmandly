import 'package:domain/domain.dart';
import 'package:domain/testing.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:glados/glados.dart';

import 'support/builders.dart';

/// Effects on something missing do nothing, like in the repository layer.
void main() {
  final soup = recipe('soup', [ingredient('onion')]);

  test('setting a check replaces the one for the same line', () {
    const line = LineId('onion', BaseMeasure.none);
    final state = kitchen(
      checks: [Check(line: line, at: t0)],
    );
    final after = applyEffects(state, [
      SetCheck(Check(line: line, at: t0, by: 'u')),
    ]);
    expect(after.checks.single.by, 'u');
  });

  test('overrides are set and deleted by their normalized key', () {
    final state = kitchen(overrides: {'Salt ': true, 'onion': true});
    final after = applyEffects(state, [
      const DeleteOverride('salt'),
      const SetOverride('leek', include: false),
    ]);
    expect(after.overrides, {'onion': true, 'leek': false}.lock);
  });

  test('updating a missing entry does nothing', () {
    final state = kitchen(recipes: [soup]);
    expect(applyEffects(state, [UpdatePlanned('gone', shoppedAt: t0)]), state);
  });

  test('refuses what Firestore can\'t do in one write', () {
    final state = kitchen(recipes: [soup]);
    for (final update in [
      UpdatePlanned('gone', addDone: {'a'}.lock, removeDone: {'b'}.lock),
      UpdatePlanned(
        'gone',
        addExcluded: {'a'}.lock,
        removeExcluded: {'b'}.lock,
      ),
    ]) {
      expect(update.isWritable, isFalse);
      expect(() => applyEffects(state, [update]), throwsArgumentError);
    }
    expect(
      UpdatePlanned(
        'e',
        addDone: {'a'}.lock,
        removeExcluded: {'b'}.lock,
      ).isWritable,
      isTrue,
    );
  });

  test('deleting missing things does nothing', () {
    final state = kitchen(recipes: [soup]);
    expect(
      applyEffects(state, [
        const DeletePlanned('gone'),
        const DeleteListItem('gone'),
        const DeleteRecipe('gone'),
        const DeleteOverride('gone'),
        const DeleteCheck(LineId('gone', BaseMeasure.none)),
      ]),
      state,
    );
  });

  test('finishing a missing entry counts nothing', () {
    final state = kitchen(recipes: [soup]);
    expect(
      applyEffects(state, [
        FinishCooking(entryId: 'gone', recipeId: 'soup', at: t0),
      ]),
      state,
    );
  });
}
