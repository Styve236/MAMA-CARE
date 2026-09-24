import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:backend/utils/env.dart';
import 'package:uuid/uuid.dart';

class JwtService {
  static final Map<String, DateTime> _revoked = {};

  final String _secret = Env.get('JWT_SECRET') ?? '';

  JwtService() {
    if (_secret.length < 32) {
      throw StateError(
          'JWT_SECRET manquant ou trop court (32 caractères minimum). '
          'Ajoutez une valeur forte dans backend/.env');
    }
  }

  String sign(Map<String, dynamic> payload,
      {Duration expiresIn = const Duration(days: 7)}) {
    final jti = const Uuid().v4();
    final jwt = JWT({...payload, 'jti': jti});
    return jwt.sign(SecretKey(_secret), expiresIn: expiresIn);
  }

  Map<String, dynamic>? verify(String token) {
    try {
      _purge();
      final jwt = JWT.verify(token, SecretKey(_secret));
      final payload = Map<String, dynamic>.from(jwt.payload);
      final jti = payload['jti'];
      if (jti == null || _revoked.containsKey(jti.toString())) return null;
      return payload;
    } catch (_) {
      return null;
    }
  }

  void revoke(String token) {
    try {
      final jwt = JWT.verify(token, SecretKey(_secret));
      final jti = jwt.payload['jti'];
      if (jti != null) {
        _purge();
        _revoked[jti.toString()] =
            DateTime.now().add(const Duration(days: 7));
      }
    } catch (_) {}
  }

  static void _purge() {
    final now = DateTime.now();
    _revoked.removeWhere((_, expiry) => expiry.isBefore(now));
  }
}