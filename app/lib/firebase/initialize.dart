import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import 'environment.dart';

/// Initializes Firebase for [environment] and, for [Local], points every
/// service at the emulators.
Future<void> initializeFirebase(Environment environment) async {
  await Firebase.initializeApp(options: environment.options);
  switch (environment) {
    case Local(:final host):
      FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
      await FirebaseAuth.instance.useAuthEmulator(host, 9099);
  }
}
