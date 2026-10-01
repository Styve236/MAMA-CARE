/// Erreur exposée par la couche de notifications push.
class PushException implements Exception {
  final String message;

  const PushException(this.message);

  @override
  String toString() => message;
}
