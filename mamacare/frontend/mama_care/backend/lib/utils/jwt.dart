import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:backend/utils/env.dart';

class JwtService {
  final String _secret = Env.get('JWT_SECRET') ?? 'dev_secret';

  String sign(Map<String, dynamic> payload, {Duration expiresIn = const Duration(days: 7)}) {
    final jwt = JWT(payload);
    return jwt.sign(SecretKey(_secret), expiresIn: expiresIn);
  }

  Map<String, dynamic>? verify(String token) {
    try {
      final jwt = JWT.verify(token, SecretKey(_secret));
      return Map<String, dynamic>.from(jwt.payload);
    } catch (e) {
      return null;
    }
  }
}
