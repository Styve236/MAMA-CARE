import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart' as pc;
import 'package:backend/utils/env.dart';

/// Envoi de notifications web push (protocole standard W3C / VAPID,
/// chiffrement aes128gcm selon RFC 8188 + RFC 8291). Aucun Firebase requis.
class WebPushService {
  WebPushService._(this._publicKeyB64, this._privateKeyBytes, this._subject);

  final String _publicKeyB64;
  final List<int> _privateKeyBytes;
  final String _subject;

  late final List<int> _encryptionKey = () {
    final ecParams = pc.ECDomainParameters('prime256v1');
    final d = _fromBytes(_privateKeyBytes, ecParams);
    return (ecParams.G * d)!.getEncoded(false);
  }();

  static WebPushService? _instance;

  static WebPushService? getInstance() {
    if (_instance != null) return _instance;
    final publicKey = Env.get('VAPID_PUBLIC_KEY');
    final privateKey = Env.get('VAPID_PRIVATE_KEY');
    final subject = Env.get('VAPID_SUBJECT');
    if (publicKey == null || privateKey == null) return null;
    try {
      _instance = WebPushService._(
        publicKey,
        _b64urlDecode(privateKey),
        subject == null || subject.isEmpty ? 'mailto:admin@mamacare.com' : subject,
      );
      return _instance;
    } catch (_) {
      return null;
    }
  }

  /// Clé publique VAPID (base64url sans padding) exposée au navigateur.
  String get publicKeyB64 => _publicKeyB64;

  bool get isConfigured => _publicKeyB64.isNotEmpty && _privateKeyBytes.isNotEmpty;

  /// Envoie une notification à une souscription. Retourne `true` si le serveur
  /// push a accepté le message, `false` si la souscription est devenue invalide
  /// (404/410 → à supprimer). Lève [WebPushException] pour les autres erreurs.
  Future<bool> send({
    required String endpoint,
    required String p256dh,
    required String auth,
    required String title,
    required String body,
    String? url,
  }) async {
    final payload = jsonEncode({'title': title, 'body': body, 'url': url ?? '/'});
    final salt = Uint8List.fromList(
        List<int>.generate(16, (_) => Random.secure().nextInt(256)));
    final encrypted = _encrypt(
        payload, _b64urlDecode(p256dh), _b64urlDecode(auth), salt);

    final uri = Uri.tryParse(endpoint);
    if (uri == null || !(uri.scheme == 'https' || uri.scheme == 'http')) {
      throw WebPushException('Endpoint push invalide');
    }

    final vapid = await _vapidJwt(endpoint);
    final dhB64 = _b64urlEncode(_encryptionKey);
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType('application', 'octet-stream');
      request.headers.set('ttl', '60');
      request.headers.set('content-encoding', 'aes128gcm');
      request.headers.set('encryption', 'salt=${_b64urlEncode(salt)}');
      request.headers.set('crypto-key', 'dh=$dhB64; p256ecdsa=$_publicKeyB64');
      request.headers.set('authorization', 'vapid t=$vapid,k=$_publicKeyB64');
      request.contentLength = encrypted.length;
      request.add(encrypted);
      final response = await request.close().timeout(const Duration(seconds: 20));
      await response.drain<void>();
      if (response.statusCode == 404 || response.statusCode == 410) return false;
      if (response.statusCode == 201 ||
          response.statusCode == 202 ||
          response.statusCode == 204 ||
          response.statusCode == 200) {
        return true;
      }
      throw WebPushException('Statut inattendu du serveur push : ${response.statusCode}');
    } on WebPushException {
      rethrow;
    } on SocketException catch (error) {
      throw WebPushException('Connexion impossible ($error)');
    } catch (error) {
      throw WebPushException("Erreur d'envoi ($error)");
    } finally {
      client.close(force: true);
    }
  }

  // --------------------------------------------------------------------------
  // Chiffrement aes128gcm (RFC 8188) + dérivation de clés (RFC 8291)
  // --------------------------------------------------------------------------

  Uint8List _encrypt(String message, List<int> clientPublic, List<int> authSecret, Uint8List salt) {
    final ecParams = pc.ECDomainParameters('prime256v1');
    final serverD = _fromBytes(_privateKeyBytes, ecParams);

    final sharedBytes = _ecdh(serverD, clientPublic, ecParams);
    final serverPublicBytes = (ecParams.G * serverD)!.getEncoded(false);

    final keyInfo = <int>[
      ...utf8.encode('WebPush: info'),
      0x00,
      ...clientPublic,
      ...serverPublicBytes,
    ];
    final ikm = _hkdf(sharedBytes, authSecret, keyInfo, 32);

    final prk = _hkdf(ikm, salt, [...utf8.encode('Content-Encoding: auth'), 0x00], 32);
    final cek = Uint8List.fromList(_hkdfExpand(prk, [...utf8.encode('Content-Encoding: aes128gcm'), 0x00], 16));
    final nonce = Uint8List.fromList(_hkdfExpand(prk, [...utf8.encode('Content-Encoding: nonce'), 0x00], 12));

    // En-tête aes128gcm : salt(16) || rs(4, BE=4096) || idlen(1) || keyid(0)
    final header = Uint8List(21);
    header.setRange(0, 16, salt);
    ByteData.view(header.buffer).setUint32(16, 4096);
    header[20] = 0;

    // Registre unique : message || 0x00 (0 octet de padding, octet de longueur 0)
    final plaintext = Uint8List.fromList([...utf8.encode(message), 0x00]);

    final cipher = pc.GCMBlockCipher(pc.AESEngine())
      ..init(
        true,
        pc.AEADParameters(pc.KeyParameter(cek), 128, nonce, header),
      );
    final out = Uint8List(cipher.getOutputSize(plaintext.length));
    var len = cipher.processBytes(plaintext, 0, plaintext.length, out, 0);
    len += cipher.doFinal(out, len);
    return Uint8List.fromList([...header, ...out.sublist(0, len)]);
  }

  /// ECDH P-256 : point (clientPublic) multiplié par notre scalaire privé,
  /// partagé = coordonnée X (32 octets).
  Uint8List _ecdh(BigInt serverScalar, List<int> clientPublicBytes, pc.ECDomainParameters params) {
    final clientPoint = params.curve.decodePoint(Uint8List.fromList(clientPublicBytes))!;
    final sharedPoint = (clientPoint * serverScalar)!;
    final x = sharedPoint.x!.toBigInteger()!;
    return Uint8List.fromList(_bigIntTo32(x));
  }

  static List<int> _bigIntTo32(BigInt value) {
    var hex = value.toRadixString(16);
    if (hex.length.isOdd) hex = '0$hex';
    final bytes = <int>[];
    for (var i = 0; i < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return _pad32(bytes, 32);
  }

  BigInt _fromBytes(List<int> bytes, pc.ECDomainParameters params) {
    var value = BigInt.zero;
    for (final byte in bytes) {
      value = (value << 8) | BigInt.from(byte);
    }
    return value % params.n;
  }

  static List<int> _pad32(List<int> bytes, int length) {
    if (bytes.length == length) return bytes;
    return List<int>.generate(length, (i) {
      final diff = length - bytes.length;
      return i < diff ? 0 : bytes[i - diff];
    });
  }

  // RFC 5869 (extract + expand avec HMAC-SHA256).
  List<int> _hkdf(List<int> ikm, List<int> salt, List<int> info, int length) {
    return _hkdfExpand(_hkdfExtract(ikm, salt), info, length);
  }

  List<int> _hkdfExtract(List<int> ikm, List<int> salt) {
    return Hmac(sha256, salt).convert(ikm).bytes;
  }

  List<int> _hkdfExpand(List<int> prk, List<int> info, int length) {
    final out = <int>[];
    var t = <int>[];
    var counter = 1;
    while (out.length < length) {
      final mac = Hmac(sha256, prk);
      t = mac.convert([...t, ...info, counter]).bytes;
      out.addAll(t);
      counter++;
    }
    return out.sublist(0, length);
  }

  // --------------------------------------------------------------------------
  // JWT VAPID (ES256, signature = 64 octets R||S bruts)
  // --------------------------------------------------------------------------

  Future<String> _vapidJwt(String endpoint) async {
    final uri = Uri.parse(endpoint);
    final aud = '${uri.scheme}://${uri.host}';
    final header = {'typ': 'JWT', 'alg': 'ES256', 'kid': _publicKeyB64};
    final claims = {
      'aud': aud,
      'exp': DateTime.now().toUtc().add(const Duration(hours: 12)).millisecondsSinceEpoch ~/ 1000,
      'sub': _subject,
    };
    final signingInput =
        '${_b64urlEncode(utf8.encode(jsonEncode(header)))}.${_b64urlEncode(utf8.encode(jsonEncode(claims)))}';

    final ecParams = pc.ECDomainParameters('prime256v1');
    final d = _fromBytes(_privateKeyBytes, ecParams);
    final privateKey = pc.ECPrivateKey(d, ecParams);

    // ECDSA ES256 déterministe (RFC 6979) : digest SHA-256 + HMAC-SHA-256.
    final signer = pc.ECDSASigner(pc.SHA256Digest(), pc.HMac(pc.SHA256Digest(), 64))
      ..init(true, pc.PrivateKeyParameter(privateKey));
    final signature = signer.generateSignature(Uint8List.fromList(utf8.encode(signingInput))) as pc.ECSignature;

    final r = _bigIntTo32(signature.r);
    final s = _bigIntTo32(signature.s);
    return '$signingInput.${_b64urlEncode([...r, ...s])}';
  }

  // --------------------------------------------------------------------------
  // Helpers base64url (sans padding)
  // --------------------------------------------------------------------------

  static String _b64urlEncode(List<int> bytes) {
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  static Uint8List _b64urlDecode(String value) {
    var s = value.trim().replaceAll('-', '+').replaceAll('_', '/');
    while (s.length % 4 != 0) {
      s = '$s=';
    }
    return base64Url.decode(s);
  }
}

class WebPushException implements Exception {
  final String message;
  WebPushException(this.message);
  @override
  String toString() => message;
}