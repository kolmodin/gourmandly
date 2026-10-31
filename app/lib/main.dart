import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'firebase/environment.dart';
import 'firebase/initialize.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeFirebase(Environment.fromDefine());
  runApp(const ProviderScope(child: GourmandlyApp()));
}

final _router = GoRouter(
  routes: [GoRoute(path: '/', builder: (context, state) => const _Home())],
);

class GourmandlyApp extends StatelessWidget {
  const GourmandlyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'Gourmandly',
    theme: ThemeData(colorSchemeSeed: Colors.deepOrange),
    routerConfig: _router,
  );
}

class _Home extends StatelessWidget {
  const _Home();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Gourmandly')));
}
