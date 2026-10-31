import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'environment.dart';

/// Where the Cloud Functions run, see decision 001.
const functionsRegion = 'europe-north1';

FirebaseFunctions functionsFor(FirebaseApp app) =>
    FirebaseFunctions.instanceFor(app: app, region: functionsRegion);

/// Initializes Firebase for [environment] and, for [Local], points every
/// service at the emulators.
Future<void> initializeFirebase(Environment environment) async {
  final app = await Firebase.initializeApp(options: environment.options);
  // Offline use: the data survives a reload, and all tabs stay in step.
  FirebaseFirestore.instanceFor(app: app).settings = const Settings(
    persistenceEnabled: true,
    webPersistentTabManager: WebPersistentMultipleTabManager(),
  );
  await connectEmulators(app, environment);
}

/// Points [app] at the emulators, for the [Local] environment.
Future<void> connectEmulators(FirebaseApp app, Environment environment) async {
  switch (environment) {
    case Local(:final host):
      FirebaseFirestore.instanceFor(app: app).useFirestoreEmulator(host, 8080);
      await FirebaseAuth.instanceFor(app: app).useAuthEmulator(host, 9099);
      functionsFor(app).useFunctionsEmulator(host, 5001);
      await FirebaseStorage.instanceFor(app: app)
          .useStorageEmulator(host, 9199);
  }
}
