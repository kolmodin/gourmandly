import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:domain/domain.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'codec.dart';
import 'repositories.dart';

typedef _Query = QuerySnapshot<Json>;

final class FirestoreKitchenRepository implements KitchenRepository {
  FirestoreKitchenRepository(this._firestore, this._storage);

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  DocumentReference<Json> _kitchen(String id) => _firestore.doc('kitchens/$id');

  @override
  String newId() => _firestore.collection('kitchens').doc().id;

  @override
  Future<String> photoUrl(String storagePath) =>
      _storage.ref(storagePath).getDownloadURL();

  @override
  Stream<KitchenData> watch(String kitchenId) {
    final kitchen = _kitchen(kitchenId);
    final controller = StreamController<KitchenData>();
    final subscriptions = <StreamSubscription<void>>[];
    DocumentSnapshot<Json>? document;
    final collections = <String, _Query>{};
    const names = [
      'recipes',
      'plannedRecipes',
      'listItems',
      'staples',
      'overrides',
      'checks',
      'tags',
    ];

    Future<void> stop() =>
        Future.wait(subscriptions.map((subscription) => subscription.cancel()));

    // One dead listener would leave its snapshot frozen while the others go
    // on, so any error ends the whole stream.
    void fail(Object error, StackTrace stackTrace) {
      if (controller.isClosed) return;
      controller.addError(error, stackTrace);
      unawaited(controller.close());
      unawaited(stop());
    }

    void emit() {
      if (controller.isClosed) return;
      final snapshot = document;
      if (snapshot == null) return;
      final data = snapshot.data();
      if (data == null) {
        if (!snapshot.metadata.isFromCache) {
          fail(const KitchenGone(), StackTrace.current);
        }
        return;
      }
      if (collections.length < names.length) return;
      controller.add(
        KitchenData(
          kitchen: decodeKitchen(kitchenId, data),
          state: _decodeState(collections),
          tags: collections['tags']!.docs
              .map((doc) => decodeTag(doc.id, doc.data()))
              .toIList(),
          isSynced:
              !snapshot.metadata.isFromCache &&
              collections.values.every((query) => !query.metadata.isFromCache),
        ),
      );
    }

    controller.onListen = () {
      subscriptions.add(
        kitchen.snapshots(includeMetadataChanges: true).listen((snapshot) {
          document = snapshot;
          emit();
        }, onError: fail),
      );
      for (final name in names) {
        subscriptions.add(
          kitchen
              .collection(name)
              .snapshots(includeMetadataChanges: true)
              .listen((snapshot) {
                collections[name] = snapshot;
                emit();
              }, onError: fail),
        );
      }
    };
    controller.onCancel = stop;
    return controller.stream;
  }

  KitchenState _decodeState(Map<String, _Query> collections) => KitchenState(
    recipes: {
      for (final doc in collections['recipes']!.docs)
        doc.id: decodeRecipe(doc.id, doc.data()),
    }.lock,
    planned: collections['plannedRecipes']!.docs
        .map((doc) => decodePlanned(doc.id, doc.data()))
        .toIList(),
    items: collections['listItems']!.docs
        .map((doc) => decodeListItem(doc.id, doc.data()))
        .toIList(),
    staples: collections['staples']!.docs
        .map((doc) => doc.data()['key'])
        .whereType<String>()
        .toISet(),
    overrides: {
      for (final doc in collections['overrides']!.docs)
        if (doc.data()['key'] case final String key)
          key: doc.data()['include'] != false,
    }.lock,
    checks: collections['checks']!.docs
        .map((doc) => decodeCheck(doc.data()))
        .nonNulls
        .toIList(),
  );

  /// Sets and deletes go in one batch, as they can't fail on a missing
  /// document. Updates can, and would take the whole batch down with them when
  /// another member has just removed what they update, so they go separately.
  @override
  Future<void> apply(String kitchenId, Iterable<Effect> effects) async {
    final kitchen = _kitchen(kitchenId);
    final batch = _firestore.batch();
    final updates = <Future<void>>[];
    for (final effect in effects) {
      switch (effect) {
        case UpdatePlanned():
          updates.add(
            _ignoringMissing(
              kitchen
                  .collection('plannedRecipes')
                  .doc(effect.entryId)
                  .update(plannedUpdate(effect)),
            ),
          );
        case FinishCooking():
          updates.add(_finish(kitchen, effect));
        case _:
          _write(batch, kitchen, effect);
      }
    }
    await Future.wait([batch.commit(), ...updates]);
  }

  Future<void> _ignoringMissing(Future<void> update) async {
    try {
      await update;
    } on FirebaseException catch (error) {
      if (error.code != 'not-found') rethrow;
    }
  }

  /// The update of the entry makes the batch fail if the entry is gone, so
  /// that a second client finishing it doesn't count it again. If the batch
  /// fails because the recipe is gone instead, the entry still has to go.
  Future<void> _finish(
    DocumentReference<Json> kitchen,
    FinishCooking effect,
  ) async {
    final entry = kitchen.collection('plannedRecipes').doc(effect.entryId);
    final batch = _firestore.batch()
      ..update(entry, {'finishedAt': Timestamp.fromDate(effect.at)})
      ..delete(entry)
      ..update(kitchen.collection('recipes').doc(effect.recipeId), {
        'lastCookedAt': Timestamp.fromDate(effect.at),
        'timesCooked': FieldValue.increment(1),
      });
    try {
      await batch.commit();
    } on FirebaseException catch (error) {
      if (error.code != 'not-found') rethrow;
      await entry.delete();
    }
  }

  /// Existing documents only ever get field-level writes, so that an older
  /// client can't erase fields it doesn't know about (decision 003).
  void _write(
    WriteBatch batch,
    DocumentReference<Json> kitchen,
    Effect effect,
  ) {
    DocumentReference<Json> doc(String collection, String id) =>
        kitchen.collection(collection).doc(id);

    switch (effect) {
      case SetCheck(:final check):
        batch.set(
          doc('checks', check.line.documentId),
          encodeCheck(check),
          SetOptions(merge: true),
        );
      case DeleteCheck(:final line):
        batch.delete(doc('checks', line.documentId));
      case CreateListItem(:final item):
        batch.set(doc('listItems', item.id), encodeListItem(item));
      case DeleteListItem(:final itemId):
        batch.delete(doc('listItems', itemId));
      case SetOverride(:final key, :final include):
        batch.set(doc('overrides', keySlug(key)), {
          'key': key,
          'include': include,
        }, SetOptions(merge: true));
      case DeleteOverride(:final key):
        batch.delete(doc('overrides', keySlug(key)));
      case CreatePlanned(:final entry):
        batch.set(doc('plannedRecipes', entry.id), encodePlanned(entry));
      case DeletePlanned(:final entryId):
        batch.delete(doc('plannedRecipes', entryId));
      case DeleteRecipe(:final recipeId):
        batch.delete(doc('recipes', recipeId));
      case UpdatePlanned() || FinishCooking():
        throw StateError('Applied on its own: $effect');
    }
  }
}

/// The fields an [UpdatePlanned] changes.
Json plannedUpdate(UpdatePlanned update) {
  Timestamp timestamp(DateTime at) => Timestamp.fromDate(at);
  final done = update.addDone.isNotEmpty
      ? FieldValue.arrayUnion(update.addDone.toList())
      : update.removeDone.isNotEmpty
      ? FieldValue.arrayRemove(update.removeDone.toList())
      : null;
  final excluded = update.addExcluded.isNotEmpty
      ? FieldValue.arrayUnion(update.addExcluded.toList())
      : update.removeExcluded.isNotEmpty
      ? FieldValue.arrayRemove(update.removeExcluded.toList())
      : null;
  return {
    'done': ?done,
    'excluded': ?excluded,
    'servings': ?update.servings,
    if (update.clearShoppedAt)
      'shoppedAt': FieldValue.delete()
    else if (update.shoppedAt case final at?)
      'shoppedAt': timestamp(at),
    if (update.clearCookingStartedAt)
      'cookingStartedAt': FieldValue.delete()
    else if (update.cookingStartedAt case final at?)
      'cookingStartedAt': timestamp(at),
  };
}
