import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:domain/domain.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gourmandly/data/codec.dart';
import 'package:gourmandly/data/firestore_kitchen_repository.dart';

final t0 = DateTime.utc(2026, 11, 1, 12);

void main() {
  group('quantities', () {
    test('round-trip', () {
      for (final quantity in [
        Exact(Fraction(3, 4)),
        Range(Fraction(1), Fraction(5, 2)),
        const Unspecified(),
      ]) {
        expect(decodeQuantity(encodeQuantity(quantity)), quantity);
      }
    });

    test('are stored as in the data model', () {
      expect(encodeQuantity(Exact(Fraction(1, 3))), {'num': 1, 'den': 3});
      expect(encodeQuantity(Range(Fraction(1), Fraction(2))), {
        'min': {'num': 1, 'den': 1},
        'max': {'num': 2, 'den': 1},
      });
      expect(encodeQuantity(const Unspecified()), isNull);
    });

    test('a missing denominator means a whole number', () {
      expect(decodeQuantity({'num': 2}), Exact(Fraction(2)));
    });

    test('a number that is no number counts as missing', () {
      expect(decodeQuantity({'num': double.nan}), const Unspecified());
      expect(decodeQuantity({'num': double.infinity}), const Unspecified());
    });

    test('numbers may arrive as doubles', () {
      expect(decodeQuantity({'num': 2.0, 'den': 1.0}), Exact(Fraction(2)));
    });

    test('anything unusable is no quantity, not a crash', () {
      for (final value in [
        null,
        'two',
        3,
        {'num': 'a'},
        {'num': 1, 'den': 0},
        {
          'min': {'num': 1},
        },
      ]) {
        expect(decodeQuantity(value), const Unspecified());
      }
    });
  });

  group('units', () {
    test('standard and named units', () {
      expect(decodeUnit('dl'), StandardUnit.dl);
      expect(decodeUnit('klyftor'), const NamedUnit('klyftor'));
    });

    test('no unit', () {
      expect(decodeUnit(null), isNull);
      expect(decodeUnit(''), isNull);
      expect(decodeUnit(3), isNull);
    });
  });

  group('recipes', () {
    test('decode every field', () {
      final recipe = decodeRecipe('r1', {
        'title': 'Soppa',
        'servings': 4,
        'language': 'sv',
        'sourceUrl': 'https://example.com',
        'totalTime': 30,
        'steps': ['Koka'],
        'tagIds': ['t1'],
        'timesCooked': 2,
        'lastCookedAt': Timestamp.fromDate(t0),
        'image': {
          'storagePath': 'kitchens/k/r.jpg',
          'sourceUrl': 'https://example.com/r.jpg',
          'origin': 'ai',
        },
        'original': {
          'language': 'en',
          'title': 'Soup',
          'steps': ['Boil'],
          'ingredients': [
            {'id': 'i1', 'name': 'onion', 'key': 'onion'},
          ],
        },
        'ingredients': [
          {
            'id': 'i1',
            'text': '2 dl grädde, gärna ekologisk',
            'name': 'grädde',
            'key': 'cream',
            'quantity': {'num': 2, 'den': 1},
            'unit': 'dl',
            'note': 'gärna ekologisk',
            'group': 'Sås',
          },
        ],
      });
      expect(recipe.title, 'Soppa');
      expect(recipe.servings, 4);
      expect(recipe.language, 'sv');
      expect(recipe.sourceUrl, 'https://example.com');
      expect(recipe.totalTime, 30);
      expect(recipe.steps, ['Koka']);
      expect(recipe.tagIds, ['t1']);
      expect(recipe.timesCooked, 2);
      expect(recipe.lastCookedAt, t0);
      expect(recipe.image?.storagePath, 'kitchens/k/r.jpg');
      expect(recipe.image?.origin, ImageOrigin.ai);
      expect(recipe.original?.title, 'Soup');
      expect(recipe.original?.ingredients.single.key, 'onion');
      expect(recipe.original?.steps, ['Boil']);
      final ingredient = recipe.ingredients.single;
      expect(ingredient.text, '2 dl grädde, gärna ekologisk');
      expect(ingredient.name, 'grädde');
      expect(ingredient.key, 'cream');
      expect(ingredient.quantity, Exact(Fraction(2)));
      expect(ingredient.unit, StandardUnit.dl);
      expect(ingredient.note, 'gärna ekologisk');
      expect(ingredient.group, 'Sås');
    });

    test('an empty document is still a recipe', () {
      final recipe = decodeRecipe('r1', {});
      expect(recipe.id, 'r1');
      expect(recipe.title, '');
      expect(recipe.servings, 0);
      expect(recipe.ingredients, isEmpty);
      expect(recipe.image, isNull);
      expect(recipe.original, isNull);
    });

    test('unknown fields are ignored', () {
      expect(
        decodeRecipe('r1', {'title': 'A', 'fromTheFuture': 1}),
        decodeRecipe('r1', {'title': 'A'}),
      );
    });

    test('fields of the wrong type count as missing', () {
      final recipe = decodeRecipe('r1', {
        'title': 5,
        'servings': 'many',
        'ingredients': 'none',
        'steps': [1, 'Koka'],
        'image': {'origin': 'page'},
        'original': 'none',
      });
      expect(recipe.title, '');
      expect(recipe.servings, 0);
      expect(recipe.ingredients, isEmpty);
      expect(recipe.steps, ['Koka']);
      expect(recipe.image, isNull);
      expect(recipe.original, isNull);
    });

    test('an ingredient without an ID gets a stable one from its place', () {
      final recipe = decodeRecipe('r1', {
        'ingredients': [
          {'name': 'a'},
          {'text': 'b'},
          'not a map',
        ],
      });
      expect(
        [for (final i in recipe.ingredients) i.id],
        ['position-0', 'position-1'],
      );
      expect(recipe.ingredients.last.name, 'b');
    });
  });

  group('planned recipes', () {
    final full = PlannedRecipe(
      id: 'e',
      recipeId: 'r',
      servings: 6,
      addedAt: t0,
      addedBy: 'u1',
      excluded: {'a'}.lock,
      done: {'b'}.lock,
      shoppedAt: t0.add(const Duration(hours: 1)),
      cookingStartedAt: t0.add(const Duration(hours: 2)),
    );

    test('round-trip', () {
      expect(decodePlanned('e', encodePlanned(full)), full);
      final bare = PlannedRecipe(
        id: 'e',
        recipeId: 'r',
        servings: 6,
        addedAt: t0,
      );
      expect(decodePlanned('e', encodePlanned(bare)), bare);
    });

    test('a missing time reads as long ago', () {
      expect(decodePlanned('e', {}).addedAt.year, 1970);
    });
  });

  group('plannedUpdate', () {
    test('writes only what changed', () {
      expect(plannedUpdate(const UpdatePlanned('e', servings: 2)), {
        'servings': 2,
      });
    });

    test('sets membership with array operations', () {
      final added = plannedUpdate(UpdatePlanned('e', addDone: {'a'}.lock));
      expect(added['done'], FieldValue.arrayUnion(['a']));
      final removed = plannedUpdate(UpdatePlanned('e', removeDone: {'a'}.lock));
      expect(removed['done'], FieldValue.arrayRemove(['a']));
      final excluded = plannedUpdate(
        UpdatePlanned('e', addExcluded: {'a'}.lock),
      );
      expect(excluded['excluded'], FieldValue.arrayUnion(['a']));
      final included = plannedUpdate(
        UpdatePlanned('e', removeExcluded: {'a'}.lock),
      );
      expect(included['excluded'], FieldValue.arrayRemove(['a']));
    });

    test('sets and clears times', () {
      final set = plannedUpdate(
        UpdatePlanned('e', shoppedAt: t0, cookingStartedAt: t0),
      );
      expect(set['shoppedAt'], Timestamp.fromDate(t0));
      expect(set['cookingStartedAt'], Timestamp.fromDate(t0));
      final cleared = plannedUpdate(
        const UpdatePlanned(
          'e',
          clearShoppedAt: true,
          clearCookingStartedAt: true,
        ),
      );
      expect(cleared['shoppedAt'], FieldValue.delete());
      expect(cleared['cookingStartedAt'], FieldValue.delete());
    });
  });

  group('list items', () {
    test('round-trip', () {
      final item = ListItem(
        id: 'i',
        name: 'mjölk',
        addedAt: t0,
        addedBy: 'u1',
        key: 'milk',
        quantity: Exact(Fraction(1)),
        unit: StandardUnit.l,
      );
      expect(decodeListItem('i', encodeListItem(item)), item);
      final bare = ListItem(id: 'i', name: 'mjölk', addedAt: t0);
      expect(decodeListItem('i', encodeListItem(bare)), bare);
    });

    test('the text stands in for a missing name', () {
      expect(decodeListItem('i', {'text': 'mjölk'}).name, 'mjölk');
    });
  });

  group('checks', () {
    test('round-trip', () {
      for (final check in [
        Check(
          line: const LineId('onion', BaseMeasure.count),
          at: t0,
          quantity: Fraction(3),
          by: 'u1',
        ),
        Check(line: const LineId('salt', NamedMeasure('nypa')), at: t0),
      ]) {
        expect(decodeCheck(encodeCheck(check)), check);
      }
    });

    test('a check without a key is dropped', () {
      expect(decodeCheck({}), isNull);
    });

    test('a check without a dimension belongs to an unmeasured line', () {
      expect(decodeCheck({'key': 'salt'})?.line.measure, BaseMeasure.none);
    });
  });

  group('tags', () {
    test('decode', () {
      expect(
        decodeTag('t', {
          'name': 'quick',
          'category': 'effort',
          'key': 'effort.quick',
        }),
        const Tag(
          id: 't',
          name: 'quick',
          category: TagCategory.effort,
          key: 'effort.quick',
        ),
      );
    });

    test('a category from a newer client shows under Other', () {
      expect(
        decodeTag('t', {'category': 'fromTheFuture'}).category,
        TagCategory.other,
      );
    });
  });

  test('kitchens decode', () {
    final kitchen = decodeKitchen('k', {
      'name': 'Hemma',
      'ownerId': 'a',
      'memberIds': ['a', 'b'],
      'memberNames': {'a': 'Anna', 'b': 3},
      'language': 'sv',
    });
    expect(kitchen.name, 'Hemma');
    expect(kitchen.ownerId, 'a');
    expect(kitchen.memberIds, ['a', 'b']);
    expect(kitchen.memberNames, {'a': 'Anna'}.lock);
    expect(kitchen.language, 'sv');
    expect(decodeKitchen('k', {}).language, 'en');
  });
}
