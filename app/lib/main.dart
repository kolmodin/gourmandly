import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'app.dart';
import 'firebase/environment.dart';
import 'firebase/initialize.dart';
import 'firebase/overrides.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  final environment = Environment.fromDefine();
  await initializeFirebase(environment);
  runApp(
    ProviderScope(
      overrides: firebaseOverrides(environment),
      child: const GourmandlyApp(),
    ),
  );
}
