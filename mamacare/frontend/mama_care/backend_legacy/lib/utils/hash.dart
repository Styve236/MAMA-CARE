import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

class HashService {
  // PBKDF2 parameters
  static const int _iterations = 100000;
  static const int _keyLength = 32; // 32 bytes = 256 bits

  static String _randomSalt([int length = 16]) {
    final rnd = Random.secure();
    final bytes = List<int>.generate(length, (_) => rnd.nextInt(256));
    return base64Url.encode(bytes);
  }

  static List<int> _pbkdf2(String password, List<int> salt, int iterations, int dkLen) {
    final hmac = Hmac(sha256, utf8.encode(password));
    // Implementation of PBKDF2 as per RFC 2898
    int hashLen = hmac.convert([]).bytes.length;
    int l = (dkLen / hashLen).ceil();
    final List<int> dk = [];

    for (int i = 1; i <= l; i++) {
      // U_1 = PRF(P, S || INT(i))
      final si = <int>[
        ...salt,
        (i >> 24) & 0xff,
        (i >> 16) & 0xff,
        (i >> 8) & 0xff,
        i & 0xff,
      ];
      var u = hmac.convert(si).bytes;
      var t = List<int>.from(u);

      for (int j = 1; j < iterations; j++) {
        u = hmac.convert(u).bytes;
        for (int k = 0; k < t.length; k++) {
          t[k] ^= u[k];
        }
      }

      dk.addAll(t);
    }

    return dk.sublist(0, dkLen);
  }

  static String hashPassword(String password) {
    final saltStr = _randomSalt();
    final salt = base64Url.decode(saltStr);
    final dk = _pbkdf2(password, salt, _iterations, _keyLength);
    final keyStr = base64Url.encode(dk);
    // Store as: pbkdf2$iterations$salt$key
    return 'pbkdf2\u001f\u001f$_iterations\u001f$saltStr\u001f$keyStr';
  }

  static bool verifyPassword(String password, String stored) {
    try {
      // stored format: pbkdf2\u001f\u001f{iterations}\u001f{salt}\u001f{key}
      final parts = stored.split('\u001f');
      if (parts.length != 5) return false;
      final iterations = int.parse(parts[2]);
      final saltStr = parts[3];
      final keyStr = parts[4];
      final salt = base64Url.decode(saltStr);
      final dk = _pbkdf2(password, salt, iterations, base64Url.decode(keyStr).length);
      final derived = base64Url.encode(dk);
      return _constantTimeEquals(derived, keyStr);
    } catch (e) {
      return false;
    }
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    int res = 0;
    for (int i = 0; i < a.length; i++) {
      res |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return res == 0;
  }
}
