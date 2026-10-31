import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'repositories.dart';

final class FirebaseAccountRepository implements AccountRepository {
  FirebaseAccountRepository(this._auth, this._firestore, this._functions);

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  Future<Map<String, dynamic>> _call(
    String name, [
    Map<String, Object?> data = const {},
  ]) async {
    final result = await _functions.httpsCallable(name).call<Object?>(data);
    return Map<String, dynamic>.from(result.data as Map? ?? const {});
  }

  @override
  Stream<AppUser?> watchUser() => _auth.userChanges().map(
    (user) => user == null
        ? null
        : AppUser(
            id: user.uid,
            name: user.displayName,
            photoUrl: user.photoURL,
          ),
  );

  @override
  Stream<IList<String>> watchKitchenIds(String userId) =>
      _firestore.doc('users/$userId').snapshots().map((snapshot) {
        final ids = snapshot.data()?['kitchenIds'];
        return ids is List
            ? ids.whereType<String>().toIList()
            : const IListConst([]);
      });

  @override
  Future<void> signInWithGoogle() =>
      _auth.signInWithPopup(GoogleAuthProvider());

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<String> createKitchen({
    required String name,
    required String language,
  }) async {
    final result = await _call('createKitchen', {
      'name': name,
      'language': language,
    });
    return result['kitchenId'] as String;
  }

  @override
  Future<String> createInvite(String kitchenId) async {
    final result = await _call('createInvite', {'kitchenId': kitchenId});
    return result['token'] as String;
  }

  @override
  Future<String> acceptInvite(String token) async {
    final result = await _call('acceptInvite', {'token': token});
    return result['kitchenId'] as String;
  }

  @override
  Future<void> leaveKitchen(String kitchenId) =>
      _call('leaveKitchen', {'kitchenId': kitchenId});

  @override
  Future<void> transferOwnership(String kitchenId, String newOwnerId) => _call(
    'transferOwnership',
    {'kitchenId': kitchenId, 'newOwnerId': newOwnerId},
  );

  @override
  Future<void> deleteAccount() async {
    await _call('deleteAccount');
    await _auth.signOut();
  }
}
