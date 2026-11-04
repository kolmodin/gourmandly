import 'package:domain/domain.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gourmandly/ui/still_shopping.dart';

import 'support.dart';

void main() {
  RecipeGroup groupOf(List<String> keys) {
    final recipe = Recipe(
      id: 'r',
      title: 'Gryta',
      servings: 4,
      ingredients: [for (final key in keys) ingredient(key, 1, StandardUnit.st)]
          .lock,
    );
    return byRecipe(
      KitchenState(recipes: {'r': recipe}.lock, planned: [entryFor('r')].lock),
    ).recipes.single;
  }

  group('missingText', () {
    test('names everything missing when it is short', () {
      expect(missingText(groupOf(['a', 'b', 'c', 'd'])), 'Missing: a, b, c, d');
    });

    test('counts the rest when it is long', () {
      expect(
        missingText(groupOf(['a', 'b', 'c', 'd', 'e', 'f'])),
        'Missing: a, b, c, +3 more',
      );
    });

    test('says when everything is ticked', () {
      expect(missingText(groupOf([])), 'All ticked');
    });
  });

  group('stillToBuy', () {
    test('uses the singular for one ingredient', () {
      expect(stillToBuy(groupOf(['a'])), '1 of 1 ingredient to buy');
    });
  });
}
