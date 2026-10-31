import 'package:firebase_core/firebase_core.dart';

/// The backend the app talks to, chosen at build time with
/// `--dart-define=GOURMANDLY_ENV=local|dev|prod`.
sealed class Environment {
  const Environment();

  static Environment fromDefine() =>
      switch (const String.fromEnvironment('GOURMANDLY_ENV')) {
        'local' => const Local(),
        '' => throw UnsupportedError('Build with GOURMANDLY_ENV set'),
        final other => throw UnsupportedError('Unknown GOURMANDLY_ENV: $other'),
      };

  FirebaseOptions get options;
}

/// The Firebase Emulator Suite on this machine, using a `demo-` project that
/// never reaches Google's servers.
final class Local extends Environment {
  const Local({this.host = 'localhost'});

  final String host;

  static const projectId = 'demo-gourmandly';

  @override
  FirebaseOptions get options => const FirebaseOptions(
    apiKey: 'demo-api-key',
    appId: '1:000000000000:web:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: projectId,
    storageBucket: '$projectId.appspot.com',
  );
}
