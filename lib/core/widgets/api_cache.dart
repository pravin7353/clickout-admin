/// Simple in-memory cache to avoid repeated API calls for the same key
/// within a session (e.g. same pincode or IFSC looked up twice).
/// Not persisted across app restarts - just avoids redundant network calls.
class ApiCache {
  static final Map<String, dynamic> _store = {};

  static dynamic get(String key) => _store[key];

  static void set(String key, dynamic value) {
    _store[key] = value;
  }

  static bool has(String key) => _store.containsKey(key);
}
