import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gourmandly/firebase/environment.dart';
import 'package:gourmandly/firebase/initialize.dart';
import 'package:gourmandly/main.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the app starts and shows its home screen', (tester) async {
    await initializeFirebase(const Local(host: '127.0.0.1'));
    await tester.pumpWidget(const ProviderScope(child: GourmandlyApp()));
    await tester.pumpAndSettle();

    expect(find.text('Gourmandly'), findsOneWidget);
    await binding.takeScreenshot('home');
  });
}
