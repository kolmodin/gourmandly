import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gourmandly/data/repositories.dart';
import 'package:gourmandly/ui/recipe_screen.dart';

import 'support.dart';

void main() {
  group('home', () {
    testWidgets('shows what is to be cooked', (tester) async {
      await pumpApp(
        tester,
        kitchens: FakeKitchens(
          kitchenWith(
            planned: [entryFor('soup', shoppedAt: now, cookingStartedAt: now)],
          ),
        ),
      );
      expect(find.text('Hemma'), findsOneWidget);
      expect(find.text('To cook'), findsOneWidget);
      expect(find.text('Cooking now'), findsOneWidget);
    });

    testWidgets('shows what is still to buy for a recipe on the list', (
      tester,
    ) async {
      await pumpApp(
        tester,
        kitchens: FakeKitchens(kitchenWith(planned: [entryFor('soup')])),
      );
      expect(find.text('To cook'), findsNothing);
      expect(find.text('Still shopping'), findsOneWidget);
      expect(find.text('Missing: onion, cream'), findsOneWidget);
    });

    testWidgets('shows what is missing without leaving home', (tester) async {
      final kitchens = FakeKitchens(kitchenWith(planned: [entryFor('soup')]));
      await pumpApp(tester, kitchens: kitchens);
      await tester.tap(find.text('Missing: onion, cream'));
      await tester.pumpAndSettle();
      expect(
        find.text('4 servings, 2 of 2 ingredients to buy'),
        findsOneWidget,
      );
      await tester.tap(find.text('4 st onion'));
      await settle(tester);
      expect(kitchens.state.checks.single.line.key, 'onion');
      expect(
        find.text('4 servings, 1 of 2 ingredients to buy'),
        findsOneWidget,
      );
      await tester.tap(find.text('4 st onion'));
      await settle(tester);
      expect(kitchens.state.checks, isEmpty);
    });

    testWidgets('shows what is missing in a sheet on a phone', (tester) async {
      await pumpApp(
        tester,
        kitchens: FakeKitchens(kitchenWith(planned: [entryFor('soup')])),
      );
      await tester.tap(find.text('Löksoppa').first);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('shows what is missing in the middle of a wide screen', (
      tester,
    ) async {
      const size = Size(1280, 800);
      await pumpApp(
        tester,
        kitchens: FakeKitchens(kitchenWith(planned: [entryFor('soup')])),
        size: size,
      );
      await tester.tap(find.text('Löksoppa').first);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      final dialog = tester.getRect(find.byType(Dialog));
      expect(dialog.center.dx, closeTo(size.width / 2, 1));
      expect(dialog.center.dy, closeTo(size.height / 2, 1));
      await tester.tap(find.text('4 st onion'));
      await tester.pumpAndSettle();
      expect(
        find.text('4 servings, 1 of 2 ingredients to buy'),
        findsOneWidget,
      );
    });

    testWidgets('the missing sheet says when a line is shared', (tester) async {
      await pumpApp(
        tester,
        kitchens: FakeKitchens(
          kitchenWith(
            planned: [
              entryFor('soup'),
              entryFor('stew', id: 'e2'),
            ],
          ),
        ),
      );
      await tester.tap(find.text('Löksoppa').first);
      await tester.pumpAndSettle();
      expect(find.text('On the list as 5 st onion'), findsOneWidget);
    });

    testWidgets('the missing sheet can mark a recipe as bought', (
      tester,
    ) async {
      final kitchens = FakeKitchens(kitchenWith(planned: [entryFor('soup')]));
      final before = kitchens.state;
      await pumpApp(tester, kitchens: kitchens);
      await tester.tap(find.text('Löksoppa').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Already bought'));
      await tester.pumpAndSettle();
      expect(kitchens.state.planned.single.stage, PlannedStage.toCook);
      expect(find.text('Still shopping'), findsNothing);
      await tester.tap(find.text('Undo'));
      await settle(tester);
      expect(kitchens.state, before);
    });

    testWidgets('the missing sheet opens the recipe', (tester) async {
      await pumpApp(
        tester,
        kitchens: FakeKitchens(kitchenWith(planned: [entryFor('soup')])),
      );
      await tester.tap(find.text('Löksoppa').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open recipe'));
      await settle(tester);
      expect(find.byType(RecipeScreen), findsOneWidget);
    });

    testWidgets('counts ticked ingredients as bought', (tester) async {
      await pumpApp(
        tester,
        kitchens: FakeKitchens(
          kitchenWith(
            planned: [entryFor('soup')],
            checks: [
              Check(
                line: const LineId('onion', BaseMeasure.count),
                quantity: Fraction(4),
                at: now,
              ),
            ],
          ),
        ),
      );
      expect(find.text('Missing: cream'), findsOneWidget);
    });

    testWidgets('says when everything for a recipe is ticked', (tester) async {
      await pumpApp(
        tester,
        kitchens: FakeKitchens(
          kitchenWith(
            planned: [entryFor('stew')],
            checks: [
              Check(
                line: const LineId('onion', BaseMeasure.count),
                quantity: Fraction(1),
                at: now,
              ),
            ],
          ),
        ),
      );
      expect(find.text('All ticked'), findsOneWidget);
    });

    testWidgets('leaves out "To cook" when nothing is planned', (tester) async {
      await pumpApp(tester, kitchens: FakeKitchens(kitchenWith()));
      expect(find.text('To cook'), findsNothing);
      expect(find.text('Still shopping'), findsNothing);
      expect(find.text('Löksoppa'), findsOneWidget);
      expect(find.text('Gryta'), findsOneWidget);
    });

    testWidgets('searches recipes', (tester) async {
      await pumpApp(tester, kitchens: FakeKitchens(kitchenWith()));
      await tester.enterText(find.byType(TextField), 'lok');
      await settle(tester);
      expect(find.text('Löksoppa'), findsOneWidget);
      expect(find.text('Gryta'), findsNothing);
    });

    testWidgets('says so when nothing matches', (tester) async {
      await pumpApp(tester, kitchens: FakeKitchens(kitchenWith()));
      await tester.enterText(find.byType(TextField), 'pizza');
      await settle(tester);
      expect(find.textContaining('Nothing matches'), findsOneWidget);
    });

    testWidgets('filters by tag', (tester) async {
      await pumpApp(tester, kitchens: FakeKitchens(kitchenWith()));
      await tester.tap(find.byTooltip('Filter by tag'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('quick'));
      await tester.pump();
      await tester.tap(find.text('Show recipes'));
      await tester.pumpAndSettle();
      expect(find.text('Löksoppa'), findsNothing);
      expect(find.textContaining('Nothing matches'), findsOneWidget);
    });

    testWidgets('shows tag filters in the middle of a wide screen', (
      tester,
    ) async {
      const size = Size(1280, 800);
      await pumpApp(tester, kitchens: FakeKitchens(kitchenWith()), size: size);
      await tester.tap(find.byTooltip('Filter by tag'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      final dialog = tester.getRect(find.byType(Dialog));
      expect(dialog.center.dx, closeTo(size.width / 2, 1));
      expect(dialog.center.dy, closeTo(size.height / 2, 1));
      await tester.tap(find.text('quick'));
      await tester.pump();
      await tester.tap(find.text('Show recipes'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(find.textContaining('Nothing matches'), findsOneWidget);
    });
  });

  group('shopping list', () {
    final planned = [entryFor('soup')];

    Future<FakeKitchens> open(
      WidgetTester tester, {
      List<PlannedRecipe>? entries,
      List<ListItem> items = const [],
      List<Check> checks = const [],
      Set<String> staples = const {},
    }) async {
      final kitchens = FakeKitchens(
        kitchenWith(
          planned: entries ?? planned,
          items: items,
          checks: checks,
          staples: staples,
        ),
      );
      await pumpApp(tester, kitchens: kitchens);
      await tester.tap(find.text('Shopping list').last);
      await settle(tester);
      return kitchens;
    }

    testWidgets('lists scaled and merged ingredients', (tester) async {
      await open(
        tester,
        entries: [
          entryFor('soup'),
          entryFor('stew', id: 'e2'),
        ],
      );
      expect(find.text('5 st onion'), findsOneWidget);
      expect(find.text('2 dl cream'), findsOneWidget);
      expect(find.text('Löksoppa, Gryta'), findsOneWidget);
    });

    testWidgets('ticking a line moves it under Checked', (tester) async {
      final kitchens = await open(tester);
      await tester.tap(find.text('4 st onion'));
      await settle(tester);
      expect(kitchens.state.checks.single.by, annaId);
      expect(find.text('Checked (1)'), findsOneWidget);
    });

    testWidgets('unticking takes a line back', (tester) async {
      final kitchens = await open(
        tester,
        checks: [
          Check(
            line: const LineId('onion', BaseMeasure.count),
            at: now,
            quantity: Fraction(4),
          ),
        ],
      );
      await tester.tap(find.text('Checked (1)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('4 st onion'));
      await settle(tester);
      expect(kitchens.state.checks, isEmpty);
    });

    testWidgets('adds an item by hand', (tester) async {
      final kitchens = await open(tester);
      await tester.enterText(find.byType(TextField), ' mjölk ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);
      expect(kitchens.state.items.single.name, 'mjölk');
      expect(kitchens.state.items.single.addedBy, annaId);
      expect(find.text('mjölk'), findsOneWidget);
    });

    testWidgets('ignores an empty item', (tester) async {
      final kitchens = await open(tester);
      await tester.enterText(find.byType(TextField), '   ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);
      expect(kitchens.state.items, isEmpty);
    });

    testWidgets('folds staples away and can bring them back', (tester) async {
      final kitchens = await open(tester, staples: {'cream'});
      expect(find.text('2 dl cream'), findsNothing);
      await tester.tap(find.text('Probably at home (1)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add to list'));
      await settle(tester);
      expect(kitchens.state.overrides['cream'], isTrue);
      expect(find.text('2 dl cream'), findsOneWidget);
    });

    testWidgets('copies the list', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      await open(tester);
      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Copy list'));
      await settle(tester);
      expect(copied, '2 dl cream\n4 st onion');
      expect(find.text('List copied'), findsOneWidget);
    });

    testWidgets('done shopping asks about unticked items', (tester) async {
      final kitchens = await open(tester);
      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done shopping'));
      await tester.pumpAndSettle();
      expect(find.text('Was everything bought?'), findsOneWidget);
      await tester.tap(find.text('Everything is bought'));
      await tester.pumpAndSettle();
      expect(kitchens.state.planned.single.stage, PlannedStage.toCook);
    });

    testWidgets('the by-recipe view can remove a recipe', (tester) async {
      final kitchens = await open(tester);
      await tester.tap(find.text('By recipe'));
      await settle(tester);
      await tester.tap(find.text('Remove'));
      await settle(tester);
      expect(kitchens.state.planned, isEmpty);
    });

    testWidgets('the by-recipe view can leave out an ingredient', (
      tester,
    ) async {
      final kitchens = await open(tester);
      await tester.tap(find.text('By recipe'));
      await settle(tester);
      await tester.tap(find.byTooltip('Already have this').first);
      await settle(tester);
      expect(kitchens.state.planned.single.excluded, contains('onion'));
    });

    testWidgets('the by-recipe view can mark a recipe as bought, with undo', (
      tester,
    ) async {
      final kitchens = await open(tester);
      final before = kitchens.state;
      await tester.tap(find.text('By recipe'));
      await settle(tester);
      await tester.tap(find.text('Already bought'));
      await settle(tester);
      expect(kitchens.state.planned.single.stage, PlannedStage.toCook);
      await tester.tap(find.text('Undo'));
      await settle(tester);
      expect(kitchens.state, before);
    });

    testWidgets('the by-recipe view lists what is already bought', (
      tester,
    ) async {
      await open(
        tester,
        entries: [
          entryFor('soup'),
          entryFor('stew', id: 'e2', shoppedAt: now),
        ],
      );
      await tester.tap(find.text('By recipe'));
      await settle(tester);
      expect(find.text('Already bought'), findsNWidgets(2));
      expect(find.text('Gryta'), findsOneWidget);
      await tester.tap(find.text('Gryta'));
      await settle(tester);
      expect(find.byType(RecipeScreen), findsOneWidget);
    });

    testWidgets('an empty list says what to do', (tester) async {
      await open(tester, entries: []);
      expect(find.textContaining('The list is empty'), findsOneWidget);
    });
  });

  group('recipe', () {
    testWidgets('scales with the servings', (tester) async {
      await pumpApp(
        tester,
        kitchens: FakeKitchens(kitchenWith()),
        location: '/recipes/soup',
      );
      expect(find.text('4 st onion'), findsOneWidget);
      await tester.tap(find.byTooltip('More servings'));
      await settle(tester);
      await tester.tap(find.byTooltip('More servings'));
      await settle(tester);
      expect(find.text('6 st onion'), findsOneWidget);
      expect(find.text('6 servings'), findsOneWidget);
    });

    testWidgets('adds to the shopping list at the chosen servings', (
      tester,
    ) async {
      final kitchens = FakeKitchens(kitchenWith());
      await pumpApp(tester, kitchens: kitchens, location: '/recipes/soup');
      await tester.tap(find.byTooltip('Fewer servings'));
      await settle(tester);
      await tester.tap(find.text('Add to shopping list'));
      await settle(tester);
      expect(kitchens.state.planned.single.servings, 3);
      expect(kitchens.state.planned.single.addedBy, annaId);
    });

    testWidgets('starting ticks it off the list, with undo', (tester) async {
      final kitchens = FakeKitchens(kitchenWith(planned: [entryFor('soup')]));
      final before = kitchens.state;
      await pumpApp(tester, kitchens: kitchens, location: '/recipes/soup');
      await tester.tap(find.text('Start cooking'));
      await settle(tester);
      expect(kitchens.state.planned.single.stage, PlannedStage.cooking);
      expect(shoppingList(kitchens.state).lines, isEmpty);
      await tester.tap(find.text('Undo'));
      await settle(tester);
      expect(kitchens.state, before);
    });

    testWidgets('says what is still to buy while on the list', (tester) async {
      await pumpApp(
        tester,
        kitchens: FakeKitchens(kitchenWith(planned: [entryFor('soup')])),
        location: '/recipes/soup',
      );
      expect(
        find.text('Still on the shopping list, with 2 ingredients to buy.'),
        findsOneWidget,
      );
      expect(find.text('Add to shopping list'), findsNothing);
    });

    testWidgets('can be marked as bought, with undo', (tester) async {
      final kitchens = FakeKitchens(kitchenWith(planned: [entryFor('soup')]));
      final before = kitchens.state;
      await pumpApp(tester, kitchens: kitchens, location: '/recipes/soup');
      await tester.tap(find.text('Already bought'));
      await settle(tester);
      expect(kitchens.state.planned.single.stage, PlannedStage.toCook);
      expect(find.textContaining('Still on the shopping list'), findsNothing);
      await tester.tap(find.text('Undo'));
      await settle(tester);
      expect(kitchens.state, before);
    });

    testWidgets('shows what is missing on the shopping list', (tester) async {
      await pumpApp(
        tester,
        kitchens: FakeKitchens(
          kitchenWith(
            planned: [
              entryFor('stew', id: 'e0'),
              entryFor('soup', id: 'e1'),
            ],
          ),
        ),
        location: '/recipes/soup',
      );
      await tester.tap(find.text('See what\'s missing'));
      await settle(tester);
      expect(find.byType(RecipeScreen), findsNothing);
      expect(find.text('Remove'), findsNWidgets(2));
      expect(find.text('4 st onion'), findsOneWidget);
    });

    testWidgets('a recipe that is not planned simply starts', (tester) async {
      final kitchens = FakeKitchens(kitchenWith());
      await pumpApp(tester, kitchens: kitchens, location: '/recipes/soup');
      await tester.tap(find.text('Start cooking'));
      await settle(tester);
      expect(kitchens.state.planned.single.stage, PlannedStage.cooking);
      expect(find.text('Undo'), findsNothing);
    });

    testWidgets('keeps the screen on only while cooking', (tester) async {
      final screen = FakeScreen();
      await pumpApp(
        tester,
        kitchens: FakeKitchens(kitchenWith()),
        screen: screen,
        location: '/recipes/soup',
      );
      expect(screen.isOn, isFalse);
      await tester.tap(find.text('Start cooking'));
      await settle(tester);
      expect(screen.isOn, isTrue);
      await tester.tap(find.byTooltip('Back'));
      await settle(tester);
      expect(screen.isOn, isFalse);
    });

    testWidgets('ticks are kept on the device while cooking', (tester) async {
      final settings = FakeSettings();
      final kitchens = FakeKitchens(
        kitchenWith(
          planned: [entryFor('soup', shoppedAt: now, cookingStartedAt: now)],
        ),
      );
      await pumpApp(
        tester,
        kitchens: kitchens,
        settings: settings,
        location: '/recipes/soup',
      );
      await tester.tap(find.text('4 st onion'));
      await settle(tester);
      expect(settings.values['ticks.e1'], contains('onion'));
      expect(kitchens.applied, isEmpty);
    });

    testWidgets('done cooking records it and goes home', (tester) async {
      final kitchens = FakeKitchens(
        kitchenWith(
          planned: [entryFor('soup', shoppedAt: now, cookingStartedAt: now)],
        ),
      );
      await pumpApp(tester, kitchens: kitchens, location: '/recipes/soup');
      await tester.tap(find.text('Done cooking'));
      await settle(tester);
      expect(kitchens.state.planned, isEmpty);
      expect(kitchens.state.recipes['soup']!.timesCooked, 1);
      expect(find.byType(RecipeScreen), findsNothing);
    });

    testWidgets('switches to the original language', (tester) async {
      final kitchens = FakeKitchens(kitchenWith());
      final translated = Recipe(
        id: 'soup',
        title: 'Löksoppa',
        servings: 4,
        language: 'sv',
        ingredients: soup.ingredients,
        steps: soup.steps,
        original: RecipeOriginal(
          language: 'en',
          title: 'Onion soup',
          ingredients: soup.ingredients,
          steps: soup.steps,
        ),
      );
      kitchens.state = KitchenState(
        recipes: kitchens.state.recipes.add('soup', translated),
      );
      await pumpApp(tester, kitchens: kitchens, location: '/recipes/soup');
      await tester.tap(find.text('English'));
      await settle(tester);
      expect(find.text('Onion soup'), findsOneWidget);
    });

    testWidgets('fits a tablet without overflowing', (tester) async {
      await pumpApp(
        tester,
        kitchens: FakeKitchens(
          kitchenWith(
            planned: [entryFor('soup', shoppedAt: now, cookingStartedAt: now)],
          ),
        ),
        location: '/recipes/soup',
        size: const Size(1180, 820),
      );
      expect(find.text('Ingredients'), findsOneWidget);
      expect(find.text('Steps'), findsOneWidget);
      expect(find.text('4 st onion').hitTestable(), findsOneWidget);
      expect(find.text('Koka').hitTestable(), findsOneWidget);
    });
  });

  group('housekeeping', () {
    final old = now.subtract(const Duration(hours: 25));
    final state = kitchenWith(
      planned: [entryFor('soup')],
      checks: [
        Check(
          line: const LineId('onion', BaseMeasure.count),
          at: old,
          quantity: Fraction(4),
        ),
      ],
    );

    testWidgets('clears old lines once the kitchen is in sync', (tester) async {
      final kitchens = FakeKitchens(state);
      await pumpApp(tester, kitchens: kitchens);
      expect(kitchens.state.checks, isEmpty);
      expect(kitchens.state.planned.single.done, contains('onion'));
    });

    testWidgets('runs again every hour while the app is open', (tester) async {
      var time = now;
      final kitchens = FakeKitchens(
        kitchenWith(
          planned: [entryFor('soup')],
          checks: [
            Check(
              line: const LineId('onion', BaseMeasure.count),
              at: now.subtract(const Duration(hours: 23)),
              quantity: Fraction(4),
            ),
          ],
        ),
      );
      await pumpApp(tester, kitchens: kitchens, clock: () => time);
      expect(kitchens.state.checks, hasLength(1));
      time = now.add(const Duration(hours: 2));
      await tester.pump(const Duration(hours: 1));
      await settle(tester);
      expect(kitchens.state.checks, isEmpty);
    });

    testWidgets('waits while the data comes from the cache', (tester) async {
      final kitchens = FakeKitchens(state, isSynced: false);
      await pumpApp(tester, kitchens: kitchens);
      expect(kitchens.applied, isEmpty);
    });

    testWidgets('forgets a kitchen that has been deleted', (tester) async {
      final account = FakeAccount();
      final kitchens = FakeKitchens(kitchenWith())
        ..failure = const KitchenGone();
      await pumpApp(tester, kitchens: kitchens, account: account);
      expect(account.left, [kitchenId]);
    });
  });

  group('getting started', () {
    testWidgets('a signed-out user is asked to sign in', (tester) async {
      final account = FakeAccount(user: null);
      await pumpApp(
        tester,
        kitchens: FakeKitchens(kitchenWith()),
        account: account,
      );
      await tester.tap(find.text('Sign in with Google'));
      await settle(tester);
      expect(account.signedInWithGoogle, isTrue);
    });

    testWidgets('a new user creates a kitchen explicitly', (tester) async {
      final account = FakeAccount(kitchens: []);
      await pumpApp(
        tester,
        kitchens: FakeKitchens(kitchenWith()),
        account: account,
      );
      expect(find.text('Set up your kitchen'), findsOneWidget);
      expect(account.created, isEmpty);
      await tester.enterText(find.byType(TextField).first, 'Hemma');
      await tester.tap(find.text('Create kitchen'));
      await settle(tester);
      expect(account.created, ['Hemma']);
    });
  });

  group('kitchen', () {
    testWidgets('lists members with the owner marked', (tester) async {
      await pumpApp(
        tester,
        kitchens: FakeKitchens(kitchenWith()),
        location: '/kitchen',
      );
      expect(find.text('Anna'), findsOneWidget);
      expect(find.text('Erik'), findsOneWidget);
      expect(find.text('Owner'), findsOneWidget);
      expect(find.text('Hand over'), findsOneWidget);
    });

    testWidgets('warns the owner before deleting a kitchen', (tester) async {
      final account = FakeAccount();
      await pumpApp(
        tester,
        kitchens: FakeKitchens(kitchenWith()),
        account: account,
        location: '/kitchen',
      );
      await tester.ensureVisible(find.text('Delete kitchen'));
      await tester.tap(find.text('Delete kitchen'));
      await tester.pumpAndSettle();
      expect(find.textContaining('deletes it with all its'), findsOneWidget);
      expect(account.left, isEmpty);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete kitchen'));
      await tester.pumpAndSettle();
      expect(account.left, [kitchenId]);
    });
  });
}
