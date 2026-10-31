/// Small settings kept per device, such as the current kitchen.
abstract interface class LocalSettings {
  String? read(String key);
  void write(String key, String? value);
}
