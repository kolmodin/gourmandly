import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gourmandly/app.dart';
import 'package:gourmandly/firebase/environment.dart';
import 'package:gourmandly/firebase/initialize.dart';
import 'package:gourmandly/firebase/overrides.dart';
import 'package:integration_test/integration_test.dart';

const local = Local(host: '127.0.0.1');
const screen = String.fromEnvironment('SCREEN', defaultValue: 'test');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> until(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 150; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (finder.evaluate().isNotEmpty) return;
    }
    fail('Never appeared: $finder');
  }

  /// Gives photos time to arrive, then saves what's on the screen.
  Future<void> shoot(WidgetTester tester, String name) async {
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    await binding.takeScreenshot('$screen-$name');
  }

  testWidgets('a walk through the seeded kitchen', (tester) async {
    await initializeFirebase(local);
    await tester.pumpWidget(
      ProviderScope(
        overrides: firebaseOverrides(local),
        child: screen == 'phone'
            ? const _PhoneWidth(child: GourmandlyApp())
            : const GourmandlyApp(),
      ),
    );

    await until(tester, find.text('Sign in as Anna (local)'));
    await shoot(tester, 'welcome');

    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: 'anna@example.com',
      password: 'gourmandly',
    );

    await until(tester, find.text('To cook'));
    expect(find.text('Hemma'), findsOneWidget);
    expect(find.text('Cooking now'), findsOneWidget);
    await shoot(tester, 'home');

    await tester.tap(find.text('Fisksoppa med saffran').first);
    await until(tester, find.text('Done cooking'));
    expect(find.text('400 g torskfilé'), findsOneWidget);
    await shoot(tester, 'cooking');
    await tester.tap(find.byTooltip('Back'));

    await until(tester, find.text('To cook'));
    await tester.ensureVisible(find.text('Shakshuka').first);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Shakshuka').first);
    await until(tester, find.text('Svenska'));
    await shoot(tester, 'recipe-translated');
    await tester.tap(find.text('English'));
    await until(
      tester,
      find.text('Soften the onion, pepper and garlic with the spices.'),
    );
    await tester.tap(find.byTooltip('Back'));

    await until(tester, find.text('To cook'));
    await tester.ensureVisible(find.text('Spaghetti carbonara').first);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Spaghetti carbonara').first);
    await until(tester, find.text('Open recipe'));
    await shoot(tester, 'home-missing');
    await tester.tap(find.text('Open recipe'));
    await until(tester, find.text('See what\'s missing'));
    await shoot(tester, 'recipe-shopping');
    await tester.tap(find.text('See what\'s missing'));
    await until(tester, find.text('Added by hand'));
    await shoot(tester, 'list-missing');
    await tester.tap(find.text('Recipes'));

    await until(tester, find.text('To cook'));
    await tester.tap(find.text('Shopping list').last);
    await until(tester, find.text('Add an item'));
    await shoot(tester, 'list');
    await tester.scrollUntilVisible(
      find.text('mjölk'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('mjölk'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('By recipe'),
      -200,
      scrollable: find.byType(Scrollable).first,
    );

    await tester.tap(find.text('By recipe'));
    await until(tester, find.text('Added by hand'));
    await shoot(tester, 'list-by-recipe');

    await tester.tap(find.text('Recipes'));
    await until(tester, find.text('To cook'));
    await tester.tap(find.text('Hemma'));
    await until(tester, find.text('Copy invite link'));
    expect(find.text('Anna'), findsOneWidget);
    expect(find.text('Erik'), findsOneWidget);
    await shoot(tester, 'kitchen');
  });
}

/// Chrome windows don't get narrower than 500 pixels, so the app is kept to
/// the width of a phone instead.
class _PhoneWidth extends StatelessWidget {
  const _PhoneWidth({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    const width = 412.0;
    final media = MediaQueryData.fromView(View.of(context));
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          child: MediaQuery(
            data: media.copyWith(size: Size(width, media.size.height)),
            child: child,
          ),
        ),
      ),
    );
  }
}
