import 'package:wakelock_plus/wakelock_plus.dart';

/// Keeps the screen on, for following a recipe with floury hands.
abstract interface class ScreenAwake {
  Future<void> keepOn();
  Future<void> release();
}

final class WakelockScreenAwake implements ScreenAwake {
  const WakelockScreenAwake();

  @override
  Future<void> keepOn() => WakelockPlus.enable();

  @override
  Future<void> release() => WakelockPlus.disable();
}
