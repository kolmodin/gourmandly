import 'dart:async';
import 'dart:convert';

import 'package:domain/domain.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories.dart';
import '../platform/local_settings.dart';
import '../platform/screen_awake.dart';

final kitchenRepositoryProvider = Provider<KitchenRepository>(
  (ref) => throw UnimplementedError('Provided in main'),
);
final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => throw UnimplementedError('Provided in main'),
);
final localSettingsProvider = Provider<LocalSettings>(
  (ref) => throw UnimplementedError('Provided in main'),
);
final screenAwakeProvider = Provider<ScreenAwake>(
  (ref) => throw UnimplementedError('Provided in main'),
);

/// Signs in without Google, against the local emulators only.
final developmentSignInProvider = Provider<Future<void> Function()?>(
  (ref) => null,
);

final clockProvider = Provider<DateTime Function()>(
  (ref) =>
      () => DateTime.now().toUtc(),
);

/// Where messages about failures go, wherever the user is by then.
final messengerKey = GlobalKey<ScaffoldMessengerState>();

/// Runs [action] and says whether it worked. When it doesn't, the user is
/// told [failure], so that nothing fails silently.
Future<bool> attempt(String failure, Future<void> Function() action) async {
  try {
    await action();
    return true;
  } on Object catch (error) {
    debugPrint('$failure $error');
    messengerKey.currentState?.showSnackBar(SnackBar(content: Text(failure)));
    return false;
  }
}

Duration? _noRetry(int count, Object error) => null;

final userProvider = StreamProvider<AppUser?>(
  (ref) => ref.watch(accountRepositoryProvider).watchUser(),
  retry: _noRetry,
);

final kitchenIdsProvider = StreamProvider<IList<String>>((ref) {
  final user = ref.watch(userProvider).value;
  if (user == null) return Stream.value(const IListConst([]));
  return ref.watch(accountRepositoryProvider).watchKitchenIds(user.id);
}, retry: _noRetry);

const _currentKitchenKey = 'currentKitchen';

/// The kitchen picked on this device.
final class ChosenKitchen extends Notifier<String?> {
  @override
  String? build() => ref.watch(localSettingsProvider).read(_currentKitchenKey);

  void choose(String kitchenId) {
    ref.read(localSettingsProvider).write(_currentKitchenKey, kitchenId);
    state = kitchenId;
  }
}

final chosenKitchenProvider = NotifierProvider<ChosenKitchen, String?>(
  ChosenKitchen.new,
);

final currentKitchenIdProvider = Provider<String?>((ref) {
  final ids = ref.watch(kitchenIdsProvider).value;
  if (ids == null || ids.isEmpty) return null;
  final chosen = ref.watch(chosenKitchenProvider);
  return ids.contains(chosen) ? chosen : ids.first;
});

final kitchenDataProvider = StreamProvider<KitchenData>((ref) {
  final id = ref.watch(currentKitchenIdProvider);
  if (id == null) return const Stream.empty();
  return ref.watch(kitchenRepositoryProvider).watch(id);
}, retry: _noRetry);

/// The name of another kitchen of the user.
final kitchenNameProvider = StreamProvider.family<String, String>(
  (ref, kitchenId) => ref
      .watch(kitchenRepositoryProvider)
      .watch(kitchenId)
      .map((data) => data.kitchen.name),
  retry: _noRetry,
);

final photoUrlProvider = FutureProvider.family<String, String>(
  (ref, path) => ref.watch(kitchenRepositoryProvider).photoUrl(path),
  retry: _noRetry,
);

final shoppingListProvider = Provider<ShoppingList?>((ref) {
  final state = ref.watch(kitchenDataProvider).value?.state;
  return state == null ? null : shoppingList(state);
});

final byRecipeProvider = Provider<ByRecipeView?>((ref) {
  final state = ref.watch(kitchenDataProvider).value?.state;
  return state == null ? null : byRecipe(state);
});

/// Ingredients and steps ticked off while cooking, kept on this device only.
final class CookingTicks extends Notifier<ISet<String>> {
  CookingTicks(this.entryId);

  final String entryId;

  String get _key => 'ticks.$entryId';

  @override
  ISet<String> build() {
    final stored = ref.watch(localSettingsProvider).read(_key);
    if (stored == null) return const ISetConst({});
    try {
      final decoded = jsonDecode(stored);
      return decoded is List ? decoded.whereType<String>().toISet() : ISet();
    } on FormatException {
      return const ISetConst({});
    }
  }

  void toggle(String id) {
    state = state.contains(id) ? state.remove(id) : state.add(id);
    ref.read(localSettingsProvider).write(_key, jsonEncode(state.toList()));
  }
}

final cookingTicksProvider =
    NotifierProvider.family<CookingTicks, ISet<String>, String>(
      CookingTicks.new,
    );

/// What people do in the app. Changes show up in [kitchenDataProvider] right
/// away, online or not, so nothing here waits for the server.
final class KitchenActions {
  KitchenActions(this._ref);

  final Ref _ref;

  DateTime get now => _ref.read(clockProvider)();
  String? get userId => _ref.read(userProvider).value?.id;
  String newId() => _ref.read(kitchenRepositoryProvider).newId();

  void apply(Iterable<Effect> effects) {
    final kitchenId = _ref.read(currentKitchenIdProvider);
    if (kitchenId == null) return;
    unawaited(
      _ref.read(kitchenRepositoryProvider).apply(kitchenId, effects).catchError(
        (Object error) {
          debugPrint('Saving failed: $error');
          messengerKey.currentState?.showSnackBar(
            const SnackBar(
              content: Text('The last change wasn\'t saved. Try it again.'),
            ),
          );
        },
      ),
    );
  }

  /// Tidies up what nobody finished. Needs the kitchen fully in sync.
  void houseKeeping(KitchenState state) {
    final effects = [
      ...autoClear(state, now: now),
      ...finishForgotten(state, now: now),
    ];
    if (effects.isNotEmpty) apply(effects);
  }
}

final kitchenActionsProvider = Provider<KitchenActions>(KitchenActions.new);
