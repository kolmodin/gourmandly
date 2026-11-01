import 'dart:async';

import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/repositories.dart';
import '../state/providers.dart';
import 'theme.dart';

/// The two main places: recipes and the shopping list. Also where a kitchen
/// is looked after while it's open.
class Shell extends ConsumerStatefulWidget {
  const Shell({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<Shell> createState() => _ShellState();
}

class _ShellState extends ConsumerState<Shell> {
  String? _tidied;

  void _watchKitchen() {
    ref.listen(kitchenDataProvider, (previous, next) {
      final data = next.value;
      if (next is AsyncData<KitchenData> &&
          data != null &&
          data.isSynced &&
          _tidied != data.kitchen.id) {
        _tidied = data.kitchen.id;
        ref.read(kitchenActionsProvider).houseKeeping(data.state);
      }
      // A kitchen that was deleted while this user was still listed on it.
      if (next.error is KitchenGone) {
        final id = ref.read(currentKitchenIdProvider);
        if (id != null) {
          unawaited(ref.read(accountRepositoryProvider).leaveKitchen(id));
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    _watchKitchen();
    final path = GoRouterState.of(context).uri.path;
    final selected = path == '/list' ? 1 : 0;
    final open = ref
        .watch(shoppingListProvider)
        ?.lines
        .where((line) => line.status is! FullyChecked)
        .length;

    void go(int index) => context.go(index == 1 ? '/list' : '/');

    Widget listIcon(IconData icon) => Badge(
      isLabelVisible: (open ?? 0) > 0,
      backgroundColor: Palette.cobalt,
      textColor: Palette.plate,
      label: Text('${open ?? 0}'),
      child: Icon(icon),
    );

    final wide = MediaQuery.sizeOf(context).width >= wideBreakpoint;
    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: selected,
              onDestinationSelected: go,
              destinations: [
                const NavigationRailDestination(
                  icon: Icon(Icons.restaurant_outlined),
                  selectedIcon: Icon(Icons.restaurant),
                  label: Text('Recipes'),
                ),
                NavigationRailDestination(
                  icon: listIcon(Icons.shopping_basket_outlined),
                  selectedIcon: listIcon(Icons.shopping_basket),
                  label: const Text('Shopping list'),
                ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: widget.child),
          ],
        ),
      );
    }
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: go,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.restaurant_outlined),
            selectedIcon: Icon(Icons.restaurant),
            label: 'Recipes',
          ),
          NavigationDestination(
            icon: listIcon(Icons.shopping_basket_outlined),
            selectedIcon: listIcon(Icons.shopping_basket),
            label: 'Shopping list',
          ),
        ],
      ),
    );
  }
}
