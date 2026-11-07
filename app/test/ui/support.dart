import 'dart:async';

import 'package:domain/domain.dart';
import 'package:domain/testing.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gourmandly/app.dart';
import 'package:gourmandly/data/repositories.dart';
import 'package:gourmandly/platform/local_settings.dart';
import 'package:gourmandly/platform/screen_awake.dart';
import 'package:gourmandly/state/providers.dart';
import 'package:gourmandly/ui/router.dart';

final now = DateTime.utc(2026, 11, 1, 12);

const kitchenId = 'k1';
const annaId = 'anna';

Ingredient ingredient(String key, int quantity, Unit unit) => Ingredient(
  id: key,
  name: key,
  key: key,
  quantity: Exact(Fraction(quantity)),
  unit: unit,
);

final soup = Recipe(
  id: 'soup',
  title: 'Löksoppa',
  servings: 4,
  ingredients: [
    ingredient('onion', 4, StandardUnit.st),
    ingredient('cream', 2, StandardUnit.dl),
  ].lock,
  steps: ['Koka'].lock,
  totalTime: 30,
);

final stew = Recipe(
  id: 'stew',
  title: 'Gryta',
  servings: 4,
  ingredients: [ingredient('onion', 1, StandardUnit.st)].lock,
);

KitchenState kitchenWith({
  List<PlannedRecipe> planned = const [],
  List<ListItem> items = const [],
  List<Check> checks = const [],
  Set<String> staples = const {},
}) => KitchenState(
  recipes: {'soup': soup, 'stew': stew}.lock,
  planned: planned.lock,
  items: items.lock,
  checks: checks.lock,
  staples: staples.lock,
);

PlannedRecipe entryFor(
  String recipeId, {
  String id = 'e1',
  DateTime? shoppedAt,
  DateTime? cookingStartedAt,
  List<String> excluded = const [],
}) => PlannedRecipe(
  id: id,
  recipeId: recipeId,
  servings: 4,
  addedAt: now,
  shoppedAt: shoppedAt,
  cookingStartedAt: cookingStartedAt,
  excluded: excluded.toISet(),
);

final class FakeKitchens implements KitchenRepository {
  FakeKitchens(this.state, {this.isSynced = true});

  KitchenState state;
  bool isSynced;
  Object? failure;
  final applied = <Effect>[];
  final _changes = StreamController<KitchenData>.broadcast();
  var _ids = 0;

  KitchenData get _data => KitchenData(
    kitchen: Kitchen(
      id: kitchenId,
      name: 'Hemma',
      ownerId: annaId,
      memberIds: [annaId, 'erik'].lock,
      memberNames: {annaId: 'Anna', 'erik': 'Erik'}.lock,
      language: 'sv',
    ),
    state: state,
    tags: const IListConst([
      Tag(id: 't1', name: 'quick', category: TagCategory.effort),
    ]),
    isSynced: isSynced,
  );

  @override
  Stream<KitchenData> watch(String id) async* {
    final error = failure;
    if (error != null) throw error;
    yield _data;
    yield* _changes.stream;
  }

  @override
  Future<void> apply(String id, Iterable<Effect> effects) async {
    applied.addAll(effects);
    state = applyEffects(state, effects);
    _changes.add(_data);
  }

  @override
  String newId() => 'new-${_ids++}';

  @override
  Future<String> photoUrl(String storagePath) async =>
      throw UnimplementedError();
}

final class FakeAccount implements AccountRepository {
  FakeAccount({this.user = const AppUser(id: annaId), List<String>? kitchens})
    : _kitchens = (kitchens ?? [kitchenId]).lock;

  final AppUser? user;
  final IList<String> _kitchens;
  final left = <String>[];
  final created = <String>[];
  var signedInWithGoogle = false;

  @override
  Stream<AppUser?> watchUser() => Stream.value(user);

  @override
  Stream<IList<String>> watchKitchenIds(String userId) =>
      Stream.value(_kitchens);

  @override
  Future<void> signInWithGoogle() async => signedInWithGoogle = true;

  @override
  Future<void> signOut() async {}

  @override
  Future<String> createKitchen({
    required String name,
    required String language,
  }) async {
    created.add(name);
    return kitchenId;
  }

  @override
  Future<String> createInvite(String kitchenId) async => 'token';

  @override
  Future<String> acceptInvite(String token) async => kitchenId;

  @override
  Future<void> leaveKitchen(String kitchenId) async => left.add(kitchenId);

  @override
  Future<void> transferOwnership(String kitchenId, String newOwnerId) async {}

  @override
  Future<void> deleteAccount() async {}
}

final class FakeSettings implements LocalSettings {
  final values = <String, String>{};

  @override
  String? read(String key) => values[key];

  @override
  void write(String key, String? value) {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }
}

final class FakeScreen implements ScreenAwake {
  var isOn = false;

  @override
  Future<void> keepOn() async => isOn = true;

  @override
  Future<void> release() async => isOn = false;
}

/// Runs the app on a phone-sized screen, starting at [location]. The time is
/// [at], or what [clock] says, for a test in which time passes.
Future<void> pumpApp(
  WidgetTester tester, {
  required FakeKitchens kitchens,
  FakeAccount? account,
  FakeScreen? screen,
  FakeSettings? settings,
  String location = '/',
  Size size = const Size(412, 915),
  DateTime? at,
  DateTime Function()? clock,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [
      kitchenRepositoryProvider.overrideWithValue(kitchens),
      accountRepositoryProvider.overrideWithValue(account ?? FakeAccount()),
      localSettingsProvider.overrideWithValue(settings ?? FakeSettings()),
      screenAwakeProvider.overrideWithValue(screen ?? FakeScreen()),
      clockProvider.overrideWithValue(clock ?? () => at ?? now),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const GourmandlyApp(),
    ),
  );
  await settle(tester);
  if (location != '/') {
    unawaited(container.read(routerProvider).push(location));
    await settle(tester);
  }
}

/// Lets streams deliver and the screen update. Not pumpAndSettle, as loading
/// spinners never settle.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}
