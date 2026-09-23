Object? jsonSafe(Object? value) {
  if (value is DateTime) return value.toIso8601String();
  if (value is Map) {
    return value
        .map((key, val) => MapEntry(key.toString(), jsonSafe(val)));
  }
  if (value is List) return value.map(jsonSafe).toList();
  return value;
}