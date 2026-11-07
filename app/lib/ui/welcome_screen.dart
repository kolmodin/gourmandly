import 'dart:async';
import 'dart:ui';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/providers.dart';
import 'theme.dart';

class _Page extends StatelessWidget {
  const _Page({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: children,
          ),
        ),
      ),
    ),
  );
}

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final developmentSignIn = ref.watch(developmentSignInProvider);
    return _Page(
      children: [
        Text('Gourmandly', style: Fonts.serif(48)),
        const SizedBox(height: 10),
        Text(
          'Your recipes and shopping list, shared with the people you cook '
          'with.',
          style: Fonts.sans(19, color: Palette.pewter),
        ),
        const SizedBox(height: 28),
        const _SignIn(),
        if (developmentSignIn != null) ...[
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => unawaited(developmentSignIn()),
            child: const Text('Sign in as Anna (local)'),
          ),
        ],
      ],
    );
  }
}

class _SignIn extends ConsumerWidget {
  const _SignIn();

  @override
  Widget build(BuildContext context, WidgetRef ref) => FilledButton(
    onPressed: () =>
        unawaited(ref.read(accountRepositoryProvider).signInWithGoogle()),
    child: const Text('Sign in with Google'),
  );
}

/// Shown until a user has a kitchen: nothing is created by accident.
class StartScreen extends ConsumerStatefulWidget {
  const StartScreen({super.key});

  @override
  ConsumerState<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends ConsumerState<StartScreen> {
  final _name = TextEditingController();
  final _invite = TextEditingController();
  bool _busy = false;
  String? _problem;

  @override
  void dispose() {
    _name.dispose();
    _invite.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _problem = null;
    });
    String? problem;
    try {
      await action();
    } on FirebaseFunctionsException catch (error) {
      problem = error.message;
    } on Object catch (error) {
      debugPrint('$error');
      problem = 'That didn\'t work. Try it again.';
    }
    if (mounted) {
      setState(() {
        _busy = false;
        _problem = problem;
      });
    }
  }

  Future<void> _create() => _run(() async {
    final account = ref.read(accountRepositoryProvider);
    final id = await account.createKitchen(
      name: _name.text,
      language: PlatformDispatcher.instance.locale.languageCode,
    );
    ref.read(chosenKitchenProvider.notifier).choose(id);
    if (mounted) context.go('/');
  });

  Future<void> _join() => _run(() async {
    final token = _invite.text.trim().split('/').last;
    final id = await ref.read(accountRepositoryProvider).acceptInvite(token);
    ref.read(chosenKitchenProvider.notifier).choose(id);
    if (mounted) context.go('/');
  });

  @override
  Widget build(BuildContext context) => _Page(
    children: [
      Text('Set up your kitchen', style: Fonts.serif(36)),
      const SizedBox(height: 8),
      Text(
        'A kitchen is a recipe bank and a shopping list that you share.',
        style: Fonts.sans(17, color: Palette.pewter),
      ),
      const SizedBox(height: 24),
      TextField(
        controller: _name,
        decoration: const InputDecoration(hintText: 'Name of your kitchen'),
      ),
      const SizedBox(height: 10),
      FilledButton(
        onPressed: _busy ? null : _create,
        child: const Text('Create kitchen'),
      ),
      const SizedBox(height: 28),
      Text('Or join someone else\'s', style: Fonts.serif(20)),
      const SizedBox(height: 10),
      TextField(
        controller: _invite,
        decoration: const InputDecoration(hintText: 'Paste an invite link'),
      ),
      const SizedBox(height: 10),
      OutlinedButton(
        onPressed: _busy ? null : _join,
        child: const Text('Join kitchen'),
      ),
      if (_problem case final problem?)
        Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Text(
            problem,
            style: Fonts.sans(15, color: Palette.saffronInk),
          ),
        ),
    ],
  );
}

/// Where an invite link leads.
class JoinScreen extends ConsumerStatefulWidget {
  const JoinScreen({required this.token, super.key});

  final String token;

  @override
  ConsumerState<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends ConsumerState<JoinScreen> {
  String? _problem;
  bool _busy = false;

  Future<void> _accept() async {
    setState(() {
      _busy = true;
      _problem = null;
    });
    try {
      final account = ref.read(accountRepositoryProvider);
      final id = await account.acceptInvite(widget.token);
      ref.read(chosenKitchenProvider.notifier).choose(id);
      if (mounted) context.go('/');
    } on Object catch (error) {
      debugPrint('$error');
      if (mounted) {
        setState(() {
          _busy = false;
          _problem = error is FirebaseFunctionsException
              ? error.message
              : 'That didn\'t work. Try it again.';
        });
      }
    }
  }

  /// Joining asks first: following a link alone shouldn't share someone's
  /// name with a kitchen.
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider).value;
    return _Page(
      children: [
        Text('You\'re invited to a kitchen', style: Fonts.serif(36)),
        const SizedBox(height: 24),
        if (user == null)
          const _SignIn()
        else ...[
          Text(
            'Its members will see your name, and you\'ll share their recipes '
            'and shopping list.',
            style: Fonts.sans(17),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _busy ? null : _accept,
            child: const Text('Join kitchen'),
          ),
        ],
        if (_problem case final problem?)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text(
              problem,
              style: Fonts.sans(17, color: Palette.saffronInk),
            ),
          ),
      ],
    );
  }
}
