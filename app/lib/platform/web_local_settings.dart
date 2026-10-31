import 'package:web/web.dart' as web;

import 'local_settings.dart';

/// [LocalSettings] in the browser's localStorage. Storage can be unavailable,
/// in a private window for example, so failures just lose the setting.
final class WebLocalSettings implements LocalSettings {
  const WebLocalSettings();

  @override
  String? read(String key) {
    try {
      return web.window.localStorage.getItem(key);
    } on Object {
      return null;
    }
  }

  @override
  void write(String key, String? value) {
    try {
      if (value == null) {
        web.window.localStorage.removeItem(key);
      } else {
        web.window.localStorage.setItem(key, value);
      }
    } on Object {
      return;
    }
  }
}
