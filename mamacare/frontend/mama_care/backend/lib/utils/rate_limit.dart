class _Bucket {
  _Bucket(this.start);
  final DateTime start;
  int count = 1;
}

class RateLimiter {
  RateLimiter(this.max, this.window);

  final int max;
  final Duration window;
  final Map<String, _Bucket> _buckets = {};

  /// Retourne le nombre de secondes à attendre si la limite est dépassée,
  /// null si la requête est autorisée.
  int? hit(String key) {
    final now = DateTime.now();
    final bucket = _buckets[key];
    if (bucket == null || now.difference(bucket.start) >= window) {
      _buckets[key] = _Bucket(now);
      return null;
    }
    if (bucket.count >= max) {
      final remaining = window.inMilliseconds - now.difference(bucket.start).inMilliseconds;
      return (remaining / 1000).ceil().clamp(1, 9999);
    }
    bucket.count++;
    return null;
  }

  void reset(String key) => _buckets.remove(key);

  void purge() {
    final now = DateTime.now();
    _buckets.removeWhere((_, bucket) => now.difference(bucket.start) >= window);
  }
}