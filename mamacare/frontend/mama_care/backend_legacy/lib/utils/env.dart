import 'dart:io';

class Env {
  static final Map<String, String> _map = _loadEnv();

  static Map<String, String> _loadEnv() {
    final map = Map<String, String>.from(Platform.environment);
    final file = File('.env');
    if (!file.existsSync()) return map;
    for (final line in file.readAsLinesSync()) {
      final l = line.trim();
      if (l.isEmpty || l.startsWith('#')) continue;
      final idx = l.indexOf('=');
      if (idx <= 0) continue;
      var key = l.substring(0, idx).trim();
      var value = l.substring(idx + 1).trim();
      if (value.startsWith('"') && value.endsWith('"')) {
        value = value.substring(1, value.length - 1);
      }
      map[key] = value;
    }
    return map;
  }

  static String? get(String key) => _map[key];
}
