import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gourmandly/firebase/environment.dart';
import 'package:gourmandly/firebase/initialize.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Firebase plugins reach the emulators', (tester) async {
    await initializeFirebase(const Local(host: '127.0.0.1'));
    final credential = await FirebaseAuth.instance.signInAnonymously();
    expect(credential.user?.isAnonymous, isTrue);

    await expectLater(
      FirebaseFirestore.instance.doc('connectivity/check').set({'a': 1}),
      throwsA(
        isA<FirebaseException>().having(
          (e) => e.code,
          'code',
          'permission-denied',
        ),
      ),
    );
  });
}
