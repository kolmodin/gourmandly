import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'state/providers.dart';
import 'ui/router.dart';
import 'ui/theme.dart';

class GourmandlyApp extends ConsumerWidget {
  const GourmandlyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: 'Gourmandly',
    debugShowCheckedModeBanner: false,
    theme: gourmandlyTheme(),
    scaffoldMessengerKey: messengerKey,
    routerConfig: ref.watch(routerProvider),
  );
}
