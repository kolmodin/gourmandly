import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Runs integration tests and saves screenshots they take to
/// build/screenshots/.
Future<void> main() => integrationDriver(
  onScreenshot: (name, bytes, [args]) async {
    final file = File('build/screenshots/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
    return true;
  },
);
