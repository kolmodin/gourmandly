import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/misc.dart';

import '../data/firebase_account_repository.dart';
import '../data/firestore_kitchen_repository.dart';
import '../platform/screen_awake.dart';
import '../platform/web_local_settings.dart';
import '../state/providers.dart';
import 'environment.dart';
import 'initialize.dart';

/// Connects the app to Firebase and the browser.
List<Override> firebaseOverrides(Environment environment) {
  final app = Firebase.app();
  final firestore = FirebaseFirestore.instanceFor(app: app);
  final auth = FirebaseAuth.instanceFor(app: app);
  return [
    kitchenRepositoryProvider.overrideWithValue(
      FirestoreKitchenRepository(
        firestore,
        FirebaseStorage.instanceFor(app: app),
      ),
    ),
    accountRepositoryProvider.overrideWithValue(
      FirebaseAccountRepository(auth, firestore, functionsFor(app)),
    ),
    localSettingsProvider.overrideWithValue(const WebLocalSettings()),
    screenAwakeProvider.overrideWithValue(const WakelockScreenAwake()),
    if (environment is Local)
      developmentSignInProvider.overrideWithValue(
        () => auth.signInWithEmailAndPassword(
          email: 'anna@example.com',
          password: 'gourmandly',
        ),
      ),
  ];
}
