import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/providers.dart';
import 'theme.dart';

/// The current kitchen, its members, and the user's other kitchens.
class KitchenScreen extends ConsumerWidget {
  const KitchenScreen({super.key});

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String text,
    required String action,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title, style: Fonts.serif(22)),
          content: Text(text),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(kitchenDataProvider).value;
    final user = ref.watch(userProvider).value;
    final ids = ref.watch(kitchenIdsProvider).value;
    final account = ref.watch(accountRepositoryProvider);
    if (data == null || user == null || ids == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final kitchen = data.kitchen;
    final isOwner = kitchen.ownerId == user.id;

    Future<void> invite() async {
      String? token;
      final made = await attempt(
        'The invite link wasn\'t made. Try it again.',
        () async => token = await account.createInvite(kitchen.id),
      );
      if (!made) return;
      await Clipboard.setData(
        ClipboardData(text: '${Uri.base.origin}/join/$token'),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invite link copied. It works for a week.'),
          ),
        );
      }
    }

    Future<void> leave() async {
      final confirmed = await _confirm(
        context,
        title: isOwner ? 'Delete ${kitchen.name}?' : 'Leave ${kitchen.name}?',
        text: isOwner
            ? 'You own this kitchen, so leaving deletes it with all its '
                  'recipes, for everyone. Hand it over first to keep it.'
            : 'You can come back with a new invite.',
        action: isOwner ? 'Delete kitchen' : 'Leave kitchen',
      );
      if (!confirmed) return;
      final left = await attempt(
        isOwner
            ? 'The kitchen wasn\'t deleted. Try it again.'
            : 'You haven\'t left the kitchen. Try it again.',
        () => account.leaveKitchen(kitchen.id),
      );
      if (left && context.mounted) context.go('/');
    }

    Future<void> handOver(String memberId, String name) async {
      final confirmed = await _confirm(
        context,
        title: 'Hand over to $name?',
        text: '$name becomes the owner of ${kitchen.name}.',
        action: 'Hand over',
      );
      if (confirmed) {
        await attempt(
          'The kitchen wasn\'t handed over. Try it again.',
          () => account.transferOwnership(kitchen.id, memberId),
        );
      }
    }

    Future<void> deleteAccount() async {
      final confirmed = await _confirm(
        context,
        title: 'Delete your account?',
        text:
            'You leave all your kitchens. Those you own are deleted, with '
            'their recipes.',
        action: 'Delete account',
      );
      if (confirmed) {
        await attempt(
          'Your account wasn\'t deleted. Try it again.',
          account.deleteAccount,
        );
      }
    }

    return Scaffold(
      appBar: AppBar(backgroundColor: Palette.enamel),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            children: [
              Text(kitchen.name, style: Fonts.serif(34)),
              const SizedBox(height: 20),
              Text('Members', style: Fonts.serif(20)),
              for (final memberId in kitchen.memberIds)
                _member(
                  name: switch (kitchen.memberNames[memberId]) {
                    null || '' => 'Someone',
                    final name => name,
                  },
                  isOwnerRow: memberId == kitchen.ownerId,
                  onHandOver: isOwner && memberId != user.id
                      ? (name) => unawaited(handOver(memberId, name))
                      : null,
                ),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: () => unawaited(invite()),
                child: const Text('Copy invite link'),
              ),
              const SizedBox(height: 28),
              Text('Your kitchens', style: Fonts.serif(20)),
              for (final id in ids)
                _KitchenRow(
                  kitchenId: id,
                  current: id == kitchen.id,
                  onTap: () {
                    ref.read(chosenKitchenProvider.notifier).choose(id);
                    context.go('/');
                  },
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => context.go('/start', extra: 'new'),
                  child: const Text('Create or join another kitchen'),
                ),
              ),
              const SizedBox(height: 28),
              const Divider(),
              const SizedBox(height: 12),
              Wrap(
                spacing: 4,
                children: [
                  TextButton(
                    onPressed: () => unawaited(leave()),
                    child: Text(isOwner ? 'Delete kitchen' : 'Leave kitchen'),
                  ),
                  TextButton(
                    onPressed: () => unawaited(account.signOut()),
                    child: const Text('Sign out'),
                  ),
                  TextButton(
                    onPressed: () => unawaited(deleteAccount()),
                    child: const Text('Delete account'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _member({
    required String name,
    required bool isOwnerRow,
    required ValueChanged<String>? onHandOver,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Expanded(child: Text(name, style: Fonts.sans(17))),
        if (isOwnerRow)
          Text('Owner', style: Fonts.sans(14, color: Palette.pewter)),
        if (onHandOver case final handOver?)
          TextButton(
            onPressed: () => handOver(name),
            child: const Text('Hand over'),
          ),
      ],
    ),
  );
}

class _KitchenRow extends ConsumerWidget {
  const _KitchenRow({
    required this.kitchenId,
    required this.current,
    required this.onTap,
  });

  final String kitchenId;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(kitchenNameProvider(kitchenId)).value ?? '…';
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(child: Text(name, style: Fonts.sans(17))),
            if (current) const Icon(Icons.check, color: Palette.cobalt),
          ],
        ),
      ),
    );
  }
}
