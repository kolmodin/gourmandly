import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:domain/domain.dart';
import 'package:domain/testing.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gourmandly/data/firebase_account_repository.dart';
import 'package:gourmandly/data/firestore_kitchen_repository.dart';
import 'package:gourmandly/data/repositories.dart';
import 'package:gourmandly/firebase/environment.dart';
import 'package:gourmandly/firebase/initialize.dart';
import 'package:integration_test/integration_test.dart';

const local = Local(host: '127.0.0.1');
final t0 = DateTime.utc(2026, 11, 1, 12);

/// A signed-in member of the app, with Firebase instances of their own.
final class Member {
  Member(this.app)
    : firestore = FirebaseFirestore.instanceFor(app: app),
      auth = FirebaseAuth.instanceFor(app: app) {
    repository = FirestoreKitchenRepository(
      firestore,
      FirebaseStorage.instanceFor(app: app),
    );
    account = FirebaseAccountRepository(auth, firestore, functionsFor(app));
  }

  final FirebaseApp app;
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;
  late final FirestoreKitchenRepository repository;
  late final FirebaseAccountRepository account;

  static var _users = 0;

  Future<void> signIn() => auth.createUserWithEmailAndPassword(
    email:
        'user${_users++}-${DateTime.now().millisecondsSinceEpoch}@example.com',
    password: 'password',
  );

  Future<KitchenData> until(
    String kitchenId,
    bool Function(KitchenData data) condition,
  ) => repository
      .watch(kitchenId)
      .firstWhere(condition)
      .timeout(const Duration(seconds: 15));
}

/// Firestore returns documents by ID, so lists are compared without order.
KitchenState sorted(KitchenState state) => KitchenState(
  recipes: state.recipes,
  planned: state.planned.sort((a, b) => a.id.compareTo(b.id)),
  items: state.items.sort((a, b) => a.id.compareTo(b.id)),
  staples: state.staples,
  overrides: state.overrides,
  checks: state.checks.sort(
    (a, b) => a.line.documentId.compareTo(b.line.documentId),
  ),
);

Map<String, Object?> ingredientDoc(
  String id,
  String key,
  int quantity,
  String unit,
) => {
  'id': id,
  'name': key,
  'key': key,
  'text': '$quantity $unit $key',
  'quantity': {'num': quantity, 'den': 1},
  'unit': unit,
};

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Member alice;
  late Member bob;
  late Member mallory;
  late String kitchenId;

  setUpAll(() async {
    await initializeFirebase(local);
    Future<Member> second(String name) async {
      final app = await Firebase.initializeApp(
        name: name,
        options: local.options,
      );
      await connectEmulators(app, local);
      return Member(app);
    }

    alice = Member(Firebase.app());
    bob = await second('bob');
    mallory = await second('mallory');
    await alice.signIn();
    await bob.signIn();
    await mallory.signIn();
  });

  setUp(() async {
    kitchenId = await alice.account.createKitchen(
      name: 'Hemma',
      language: 'sv',
    );
  });

  testWidgets('a new kitchen arrives with its defaults', (tester) async {
    final data = await alice.until(kitchenId, (data) => data.isSynced);
    expect(data.kitchen.name, 'Hemma');
    expect(data.kitchen.language, 'sv');
    expect(data.kitchen.ownerId, alice.auth.currentUser!.uid);
    expect(data.state.staples, contains('black pepper'));
    expect(
      data.tags.where((tag) => tag.key == 'meatFish.chicken').single.category,
      TagCategory.meatFish,
    );
  });

  testWidgets('kitchens of a user are listed', (tester) async {
    final uid = alice.auth.currentUser!.uid;
    final ids = await alice.account
        .watchKitchenIds(uid)
        .firstWhere((ids) => ids.contains(kitchenId));
    expect(ids, contains(kitchenId));
  });

  testWidgets('a user without a document has no kitchens', (tester) async {
    final uid = mallory.auth.currentUser!.uid;
    expect(await mallory.account.watchKitchenIds(uid).first, isEmpty);
  });

  testWidgets('a recipe stored in the documented shape is read back', (
    tester,
  ) async {
    await alice.firestore.doc('kitchens/$kitchenId/recipes/r1').set({
      'title': 'Löksoppa',
      'servings': 4,
      'steps': ['Hacka', 'Koka'],
      'ingredients': [ingredientDoc('i1', 'onion', 4, 'st')],
    });
    final data = await alice.until(
      kitchenId,
      (data) => data.state.recipes.containsKey('r1'),
    );
    final recipe = data.state.recipes['r1']!;
    expect(recipe.title, 'Löksoppa');
    expect(recipe.steps, ['Hacka', 'Koka']);
    expect(recipe.ingredients.single.quantity, Exact(Fraction(4)));
    expect(recipe.ingredients.single.unit, StandardUnit.st);
  });

  testWidgets('Firestore agrees with the model after every decision', (
    tester,
  ) async {
    final recipes = alice.firestore.collection('kitchens/$kitchenId/recipes');
    await recipes.doc('soup').set({
      'title': 'Soppa',
      'servings': 4,
      'ingredients': [
        ingredientDoc('i1', 'onion', 2, 'st'),
        ingredientDoc('i2', 'cream', 2, 'dl'),
        ingredientDoc('i3', 'salt', 1, 'krm'),
      ],
    });
    await recipes.doc('stew').set({
      'title': 'Gryta',
      'servings': 2,
      'ingredients': [ingredientDoc('i1', 'onion', 1, 'st')],
    });

    final initial = await alice.until(
      kitchenId,
      (data) => data.isSynced && data.state.recipes.length == 2,
    );
    var model = initial.state;

    Future<void> decide(Iterable<Effect> effects) async {
      model = applyEffects(model, effects);
      await alice.repository.apply(kitchenId, effects);
      final expected = sorted(model);
      KitchenState? last;
      try {
        await alice.until(kitchenId, (data) {
          last = sorted(data.state);
          return last == expected;
        });
      } on TimeoutException {
        fail('Firestore differs from the model.\n$last\n$expected');
      }
    }

    Line line(String text) =>
        shoppingList(model).lines.firstWhere((l) => l.text.contains(text));

    final soup = model.recipes['soup']!;
    final stew = model.recipes['stew']!;
    final at = t0;

    await decide([addToList(soup, servings: 4, now: at, newEntryId: 'e1')]);
    await decide([addToList(stew, servings: 4, now: at, newEntryId: 'e2')]);
    expect(line('onion').text, '4 st onion');

    await decide([
      CreateListItem(ListItem(id: 'item1', name: 'mjölk', addedAt: at)),
    ]);
    await decide([checkLine(line('onion'), at: at, by: 'alice')]);
    await decide([uncheckLine(line('onion'))]);
    await decide([checkLine(line('onion'), at: at, by: 'alice')]);
    await decide([checkLine(line('mjölk'), at: at, by: 'alice')]);

    PlannedRecipe entry(String id) =>
        model.planned.firstWhere((e) => e.id == id);

    await decide([excludeIngredient(entry('e1'), 'i2')]);
    await decide([includeIngredient(entry('e1'), 'i2')]);
    await decide([bringStapleBack('olive oil')]);
    await decide(clearChecked(model, now: at, isComplete: true));
    expect(model.items, isEmpty);
    expect(entry('e2').stage, PlannedStage.toCook);

    final started = startCooking(
      recipe: soup,
      entry: entry('e1'),
      servings: 6,
      now: at,
      newEntryId: 'unused',
    );
    await decide(started.effects);
    expect(entry('e1').stage, PlannedStage.cooking);
    await decide(started.undo);
    expect(entry('e1').stage, PlannedStage.onList);
    final undone = await alice.firestore
        .doc('kitchens/$kitchenId/plannedRecipes/e1')
        .get();
    expect(undone.data()!.containsKey('shoppedAt'), isFalse);
    expect(undone.data()!.containsKey('cookingStartedAt'), isFalse);
    await decide(started.effects);
    await decide([doneCooking(entry('e1'), now: at)]);
    expect(model.recipes['soup']!.timesCooked, 1);

    final again = startCooking(
      recipe: soup,
      servings: 4,
      now: at,
      newEntryId: 'e4',
    );
    await decide(again.effects);
    await decide([doneCooking(entry('e4'), now: at)]);
    expect(model.recipes['soup']!.timesCooked, 2);

    await decide(
      startCooking(
        recipe: stew,
        servings: 2,
        now: at,
        newEntryId: 'e3',
      ).effects,
    );
    await decide(
      doneShopping(
        model,
        DoneShopping.everythingBought,
        now: at,
        isComplete: true,
      ),
    );
    await decide(deleteRecipe(model, 'stew'));
    expect(model.recipes.keys, ['soup']);
  });

  group('things that disappeared', () {
    testWidgets('a missing entry does not hold back the rest of a decision', (
      tester,
    ) async {
      await alice.repository.apply(kitchenId, [
        CreateListItem(ListItem(id: 'kept', name: 'ost', addedAt: t0)),
        UpdatePlanned('gone', shoppedAt: t0),
      ]);
      final data = await alice.until(kitchenId, (data) => data.isSynced);
      expect(data.state.items.single.id, 'kept');
    });

    testWidgets('an entry whose recipe is gone can be finished', (
      tester,
    ) async {
      await alice.repository.apply(kitchenId, [
        CreatePlanned(
          PlannedRecipe(id: 'e1', recipeId: 'gone', servings: 4, addedAt: t0),
        ),
      ]);
      await alice.repository.apply(kitchenId, [
        FinishCooking(entryId: 'e1', recipeId: 'gone', at: t0),
      ]);
      final data = await alice.until(
        kitchenId,
        (data) => data.isSynced && data.state.planned.isEmpty,
      );
      expect(data.state.planned, isEmpty);
    });

    testWidgets('a deleted kitchen ends the stream', (tester) async {
      final settled = expectLater(
        alice.repository.watch(kitchenId),
        emitsThrough(emitsError(isA<KitchenGone>())),
      );
      await alice.until(kitchenId, (data) => data.isSynced);
      await alice.account.leaveKitchen(kitchenId);
      await settled;
    });
  });

  group('older clients', () {
    testWidgets('field-level writes keep fields they do not know', (
      tester,
    ) async {
      final planned = alice.firestore.doc(
        'kitchens/$kitchenId/plannedRecipes/e1',
      );
      await planned.set({
        'recipeId': 'r',
        'servings': 4,
        'addedAt': Timestamp.fromDate(t0),
        'fromTheFuture': 'keep me',
      });
      await alice.repository.apply(kitchenId, [
        UpdatePlanned('e1', servings: 6, addDone: {'i1'}.lock, shoppedAt: t0),
      ]);
      final stored = (await planned.get()).data()!;
      expect(stored['fromTheFuture'], 'keep me');
      expect(stored['servings'], 6);
      expect(stored['done'], ['i1']);
    });

    testWidgets('ticking a line again keeps a newer field of its check', (
      tester,
    ) async {
      const line = LineId('onion', BaseMeasure.count);
      final check = alice.firestore.doc(
        'kitchens/$kitchenId/checks/${line.documentId}',
      );
      await check.set({
        'key': 'onion',
        'dimension': 'count',
        'fromTheFuture': 'keep me',
      });
      await alice.repository.apply(kitchenId, [
        SetCheck(Check(line: line, at: t0, quantity: Fraction(2))),
      ]);
      expect((await check.get()).data()!['fromTheFuture'], 'keep me');
    });

    testWidgets('documents with unknown fields and values still read', (
      tester,
    ) async {
      final path = 'kitchens/$kitchenId';
      await alice.firestore.doc('$path/recipes/r1').set({
        'title': 'A',
        'fromTheFuture': {'nested': true},
      });
      await alice.firestore.doc('$path/tags/t1').set({
        'name': 'x',
        'category': 'fromTheFuture',
      });
      final data = await alice.until(
        kitchenId,
        (data) => data.state.recipes.containsKey('r1'),
      );
      expect(data.state.recipes['r1']!.title, 'A');
      expect(
        data.tags.firstWhere((tag) => tag.id == 't1').category,
        TagCategory.other,
      );
    });
  });

  group('together', () {
    setUp(() async {
      final token = await alice.account.createInvite(kitchenId);
      await bob.account.acceptInvite(token);
    });

    testWidgets('a change by one member reaches the other', (tester) async {
      await bob.until(kitchenId, (data) => data.isSynced);
      final pending = alice.until(
        kitchenId,
        (data) => data.state.items.any((item) => item.id == 'from-bob'),
      );
      await bob.repository.apply(kitchenId, [
        CreateListItem(ListItem(id: 'from-bob', name: 'kaffe', addedAt: t0)),
      ]);
      expect((await pending).state.items.single.name, 'kaffe');
    });

    testWidgets('changes made offline merge when back online', (tester) async {
      await alice.until(kitchenId, (data) => data.isSynced);
      await bob.until(kitchenId, (data) => data.isSynced);

      await alice.firestore.disableNetwork();
      try {
        final offline = await alice.until(kitchenId, (data) => !data.isSynced);
        expect(offline.isSynced, isFalse);

        // Doesn't complete until back online, but is visible immediately.
        final write = alice.repository.apply(kitchenId, [
          CreateListItem(ListItem(id: 'from-alice', name: 'ost', addedAt: t0)),
        ]);
        await alice.until(
          kitchenId,
          (data) => data.state.items.any((item) => item.id == 'from-alice'),
        );

        await bob.repository.apply(kitchenId, [
          CreateListItem(ListItem(id: 'from-bob', name: 'kaffe', addedAt: t0)),
        ]);

        await alice.firestore.enableNetwork();
        await write;
      } finally {
        await alice.firestore.enableNetwork();
      }

      bool both(KitchenData data) =>
          data.isSynced && data.state.items.length == 2;
      final seenByAlice = await alice.until(kitchenId, both);
      final seenByBob = await bob.until(kitchenId, both);
      expect(sorted(seenByAlice.state), sorted(seenByBob.state));
    });

    testWidgets('two members finishing an entry count it once', (tester) async {
      await alice.firestore.doc('kitchens/$kitchenId/recipes/r').set({
        'title': 'Soppa',
      });
      await alice.repository.apply(kitchenId, [
        CreatePlanned(
          PlannedRecipe(id: 'e1', recipeId: 'r', servings: 4, addedAt: t0),
        ),
      ]);
      await bob.until(kitchenId, (data) => data.state.planned.isNotEmpty);
      await alice.until(kitchenId, (data) => data.state.planned.isNotEmpty);

      final finish = FinishCooking(entryId: 'e1', recipeId: 'r', at: t0);
      await Future.wait([
        alice.repository.apply(kitchenId, [finish]),
        bob.repository.apply(kitchenId, [finish]),
      ]);

      final data = await alice.until(
        kitchenId,
        (data) => data.isSynced && data.state.planned.isEmpty,
      );
      expect(data.state.recipes['r']!.timesCooked, 1);
    });

    testWidgets('member names are shared with the kitchen', (tester) async {
      final data = await bob.until(kitchenId, (data) => data.isSynced);
      expect(
        data.kitchen.memberNames.keys,
        unorderedEquals(data.kitchen.memberIds),
      );
    });

    testWidgets('concurrent changes to a set both survive', (tester) async {
      await alice.repository.apply(kitchenId, [
        CreatePlanned(
          PlannedRecipe(id: 'e1', recipeId: 'r', servings: 4, addedAt: t0),
        ),
      ]);
      await bob.until(kitchenId, (data) => data.state.planned.isNotEmpty);

      await alice.firestore.disableNetwork();
      try {
        final write = alice.repository.apply(kitchenId, [
          UpdatePlanned('e1', addDone: {'from-alice'}.lock),
        ]);
        await bob.repository.apply(kitchenId, [
          UpdatePlanned('e1', addDone: {'from-bob'}.lock),
        ]);
        await alice.firestore.enableNetwork();
        await write;
      } finally {
        await alice.firestore.enableNetwork();
      }

      final data = await alice.until(
        kitchenId,
        (data) => data.isSynced && data.state.planned.single.done.length == 2,
      );
      expect(data.state.planned.single.done, {'from-alice', 'from-bob'}.lock);
    });
  });

  group('outsiders', () {
    testWidgets('cannot watch a kitchen', (tester) async {
      await expectLater(
        mallory.repository.watch(kitchenId).first,
        throwsA(
          isA<FirebaseException>().having(
            (error) => error.code,
            'code',
            'permission-denied',
          ),
        ),
      );
    });

    testWidgets('cannot write to a kitchen', (tester) async {
      await expectLater(
        mallory.repository.apply(kitchenId, [
          CreateListItem(ListItem(id: 'x', name: 'x', addedAt: t0)),
        ]),
        throwsA(isA<FirebaseException>()),
      );
    });
  });

  group('membership', () {
    testWidgets('leaving removes access', (tester) async {
      final token = await alice.account.createInvite(kitchenId);
      await bob.account.acceptInvite(token);
      await bob.until(kitchenId, (data) => data.isSynced);

      await bob.account.leaveKitchen(kitchenId);
      // The local cache may still answer first, but never as synced.
      await expectLater(
        bob.repository.watch(kitchenId).firstWhere((data) => data.isSynced),
        throwsA(isA<FirebaseException>()),
      );
    });

    testWidgets('ownership can be handed over', (tester) async {
      final token = await alice.account.createInvite(kitchenId);
      await bob.account.acceptInvite(token);
      final bobId = bob.auth.currentUser!.uid;

      await alice.account.transferOwnership(kitchenId, bobId);
      final data = await alice.until(
        kitchenId,
        (data) => data.kitchen.ownerId == bobId,
      );
      expect(data.kitchen.ownerId, bobId);
    });
  });
}
