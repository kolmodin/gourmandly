import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/providers.dart';
import 'home_screen.dart';
import 'kitchen_screen.dart';
import 'recipe_screen.dart';
import 'shell.dart';
import 'shopping_screen.dart';
import 'welcome_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final changes = ValueNotifier(0);
  ref.onDispose(changes.dispose);
  ref.listen(userProvider, (_, _) => changes.value++);
  ref.listen(kitchenIdsProvider, (_, _) => changes.value++);

  return GoRouter(
    refreshListenable: changes,
    redirect: (context, state) {
      final path = state.uri.path;
      final user = ref.read(userProvider);
      if (user.isLoading) return null;
      if (path.startsWith('/join/')) return null;
      if (user.value == null) return path == '/welcome' ? null : '/welcome';

      final ids = ref.read(kitchenIdsProvider);
      if (ids.isLoading && !ids.hasValue) return null;
      final hasKitchen = ids.value?.isNotEmpty ?? false;
      if (!hasKitchen) return path == '/start' ? null : '/start';
      return path == '/welcome' || (path == '/start' && state.extra != 'new')
          ? '/'
          : null;
    },
    routes: [
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(path: '/start', builder: (context, state) => const StartScreen()),
      GoRoute(
        path: '/join/:token',
        builder: (context, state) =>
            JoinScreen(token: state.pathParameters['token']!),
      ),
      GoRoute(
        path: '/kitchen',
        builder: (context, state) => const KitchenScreen(),
      ),
      GoRoute(
        path: '/recipes/:id',
        builder: (context, state) =>
            RecipeScreen(recipeId: state.pathParameters['id']!),
      ),
      ShellRoute(
        builder: (context, state, child) => Shell(child: child),
        routes: [
          GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
          GoRoute(
            path: '/list',
            builder: (context, state) => ShoppingScreen(
              focusEntryId: state.uri.queryParameters['entry'],
            ),
          ),
        ],
      ),
    ],
  );
});
