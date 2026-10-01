import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart' as pc;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_cors_headers/shelf_cors_headers.dart';

import 'package:backend/config/database.dart';
import 'package:backend/router.dart';
import 'package:backend/utils/env.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:uuid/uuid.dart';

// ---------------------------------------------------------------------------
// Test d'intégration des notifications push (VAPID + aes128gcm réel).
// L'app et le récepteur mock tournent dans ce processus.
// ---------------------------------------------------------------------------

final rng = Random.secure();

void ok(bool cond, String label) {
  if (!cond) {
    stderr.writeln('KO: $label');
    exit(1);
  }
  stdout.writeln('OK: $label');
}

String b64u(List<int> b) => base64Url.encode(b).replaceAll('=', '');
Uint8List b64d(String s) {
  var x = s.replaceAll('-', '+').replaceAll('_', '/');
  while (x.length % 4 != 0) {
    x += '=';
  }
  return base64Url.decode(x);
}

BigInt bigIntFromBytes(List<int> bytes) {
  var value = BigInt.zero;
  for (final byte in bytes) {
    value = (value << 8) | BigInt.from(byte);
  }
  return value;
}

List<int> bigIntTo32(BigInt v) {
  var hex = v.toRadixString(16);
  if (hex.length.isOdd) hex = '0$hex';
  final out = <int>[];
  for (var i = 0; i < hex.length; i += 2) {
    out.add(int.parse(hex.substring(i, i + 2), radix: 16));
  }
  while (out.length < 32) {
    out.insert(0, 0);
  }
  return out;
}

List<int> hkdf(List<int> ikm, List<int> salt, List<int> info, int length) {
  final prk = Hmac(sha256, salt).convert(ikm).bytes;
  return hkdfExpand(prk, info, length);
}

List<int> hkdfExpand(List<int> prk, List<int> info, int length) {
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

Future<void> main() async {
  // ---- 0. App embarquée (pas de processus externe) ------------------------
  final appServer = await io.serve(
    const Pipeline()
        .addMiddleware(corsHeaders())
        .addHandler(buildRouter().call),
    InternetAddress.loopbackIPv4,
    3001,
  );
  stdout.writeln('app up on :${appServer.port}');
  final base = 'http://127.0.0.1:${appServer.port}';

  // ---- 1. Mock serveur push (récepteur) ------------------------------------
  final received = <String, List<Map<String, dynamic>>>{};
  BigInt clientD;
  while (true) {
    final v = bigIntFromBytes(List<int>.generate(32, (_) => rng.nextInt(256)));
    final n = pc.ECDomainParameters('prime256v1').n;
    if (v > BigInt.one && v < n) {
      clientD = v;
      break;
    }
  }
  final ecParams = pc.ECDomainParameters('prime256v1');
  final mockPub = (ecParams.G * clientD)!.getEncoded(false);

  final mock = await HttpServer.bind(InternetAddress.loopbackIPv4, 4056);
  mock.listen((HttpRequest req) async {
    final body = await req.fold<List<int>>(<int>[], (a, b) => a..addAll(b));
    final headerMap = <String, String>{};
    req.headers.forEach((k, v) => headerMap[k] = v.join(','));
    received.putIfAbsent(req.uri.path, () => []).add({
      'body': body,
      'headers': headerMap,
    });
    req.response.statusCode = 201;
    await req.response.close();
  });
  stdout.writeln('mock receiver up on :4056');

  // ---- 2. Nettoyage --------------------------------------------------------
  final db = Database();
  await db.connect();
  for (final mail in ['a@push.test', 'b@push.test']) {
    await db.query('DELETE FROM users WHERE email = @e', substitutionValues: {'e': mail});
  }

  // ---- 3. Helpers HTTP ------------------------------------------------------
  final http = HttpClient();
  Future<Map<String, dynamic>> api(String method, String path,
      {Map<String, dynamic>? body, String? token, Map<String, String>? headers}) async {
    final req = await http.openUrl(method, Uri.parse('$base$path'));
    if (body != null) req.headers.contentType = ContentType.json;
    if (token != null) req.headers.set('authorization', 'Bearer $token');
    if (headers != null) {
      headers.forEach(req.headers.set);
    }
    if (body != null) {
      req.write(jsonEncode(body));
    }
    final res = await req.close();
    final text = await res.transform(utf8.decoder).join();
    return {'status': res.statusCode, 'text': text};
  }

  Future<void> dumpSubs(String label) async {
    final rows = await db.query('SELECT user_id, endpoint FROM push_subscriptions ORDER BY id');
    final parts = rows.map((r) {
      final m = r.toColumnMap();
      return 'u${m['user_id']}:${m['endpoint']}';
    }).join(' | ');
    stdout.writeln('  [$label] subs => $parts');
  }

  Future<(int, String)> createUserDB(String email, String suffix) async {
    final uuid = const Uuid().v4();
    final hash = (await db.query(
        'SELECT password_hash FROM users WHERE password_hash != \'\' ORDER BY id LIMIT 1'))
        .first[0] as String;
    final ins = await db.query(
        '''INSERT INTO users (uuid, email, password_hash, first_name, last_name, role, status)
           VALUES (@u, @e, @h, @fn, @ln, 'patiente', 'active') RETURNING id, uuid''',
        substitutionValues: {'u': uuid, 'e': email, 'h': hash, 'fn': 'Test$suffix', 'ln': 'Push'});
    final row = ins.first.toColumnMap();
    final uid = (row['id'] as num).toInt();
    await db.query('INSERT INTO patients (user_id) VALUES (@id)', substitutionValues: {'id': uid});
    return (uid, row['uuid'] as String);
  }

  String mintToken(int uid, String uuid, String email) {
    return JWT({
      'id': uid,
      'uuid': uuid,
      'email': email,
      'role': 'patiente',
      'status': 'active',
      'jti': const Uuid().v4(),
    }).sign(SecretKey(Env.get('JWT_SECRET')!));
  }

  // ---- 4. Bout-en-bout ------------------------------------------------------
  final emailA = 'a@push.test';
  final (uidA, uuidA) = await createUserDB(emailA, 'A');
  final tokenA = mintToken(uidA, uuidA, emailA);
  ok(tokenA.isNotEmpty, 'token A');

  final authSecret = List<int>.generate(16, (_) => rng.nextInt(256));

  final vk = await api('GET', '/api/push/vapid-public-key');
  ok(vk['status'] == 200, 'GET vapid-public-key -> ${vk['status']}');
  final vapidPub =
      (jsonDecode(vk['text'] as String) as Map<String, dynamic>)['publicKey'] as String;
  ok(vapidPub.isNotEmpty, 'vapid public key non vide');

  final regA = await api('POST', '/api/push/register', token: tokenA, body: {
    'endpoint': 'http://127.0.0.1:4056/pushA',
    'p256dh': b64u(mockPub),
    'auth': b64u(authSecret),
  });
  ok(regA['status'] == 201, 'register A -> ${regA['status']}');
  await dumpSubs('après register A');

  final emailB = 'b@push.test';
  final (uidB, uuidB) = await createUserDB(emailB, 'B');
  final tokenB = mintToken(uidB, uuidB, emailB);
  ok(tokenB.isNotEmpty, 'token B');
  final regB = await api('POST', '/api/push/register', token: tokenB, body: {
    'endpoint': 'http://127.0.0.1:4056/pushB',
    'p256dh': b64u(mockPub),
    'auth': b64u(authSecret),
  });
  ok(regB['status'] == 201, 'register B -> ${regB['status']}');
  await dumpSubs('après register B');

  final past = DateTime.now().toUtc().subtract(const Duration(hours: 2)).toIso8601String();
  final rem = await api('POST', '/api/patient/reminders', token: tokenA, body: {
    'title': 'Prise de médicament',
    'reminderDate': past,
  });
  ok(rem['status'] == 201, 'reminder A -> ${rem['status']}');

  final proc = await api('POST', '/api/push/process-reminders',
      headers: {'x-cron-secret': Env.get('CRON_SECRET')!});
  ok(proc['status'] == 200, 'process-reminders -> ${proc['status']}');
  final procBody = jsonDecode(proc['text'] as String) as Map<String, dynamic>;
  ok((procBody['processed'] as num) >= 1, 'processed>=1 (${procBody['processed']})');
  ok((procBody['inAppNotifications'] as num) >= 1,
      'inAppNotifications>=1 (${procBody['inAppNotifications']})');
  ok(procBody['pushSent'] == 1, 'pushSent=1 (${procBody['pushSent']})');
  ok(procBody['pushFailed'] == 0, 'pushFailed=0 (${procBody['pushFailed']})');

  // La notification in-app de A doit exister et être scopée à A.
  final notifsA = await db.query(
      'SELECT title, message FROM notifications WHERE user_id = @u ORDER BY id DESC LIMIT 1',
      substitutionValues: {'u': uidA});
  ok(notifsA.isNotEmpty, 'notification in-app créée pour A');
  ok((notifsA.first[0] as String) == 'Rappel' &&
      (notifsA.first[1] as String) == 'Prise de médicament',
      'notification in-app = "Rappel / Prise de médicament"');
  final notifsB = await db.query(
      'SELECT COUNT(*) FROM notifications WHERE user_id = @u', substitutionValues: {'u': uidB});
  ok((notifsB.first[0] as num) == 0, 'aucune notification in-app pour B');
  await dumpSubs('après process-reminders');

  // ---- 5. Réception + déchiffrement réel -------------------------------------
  await Future.delayed(const Duration(milliseconds: 300));
  final pushesA = received['/pushA'] ?? [];
  final pushesB = received['/pushB'] ?? [];
  ok(pushesA.length == 1, 'push A reçu (1)');
  ok(pushesB.isEmpty, 'aucun push pour B (isolation)');

  final p = pushesA.first;
  final hdr = Map<String, dynamic>.from(p['headers'] as Map);
  final keys = hdr.keys.map((k) => k.toLowerCase()).toSet();
  ok(keys.contains('authorization') &&
      (hdr['authorization'] as String).startsWith('vapid t='), 'header vapid t=');
  ok(keys.contains('content-encoding') && hdr['content-encoding'] == 'aes128gcm',
      'content-encoding=aes128gcm');
  ok(keys.contains('ttl'), 'header TTL');

  final body = List<int>.from(p['body'] as List);
  final encryption = hdr['encryption'] as String;
  final cryptoKey = hdr['crypto-key'] as String;
  final salt = b64d(RegExp(r'salt=([^;,\s]+)').firstMatch(encryption)!.group(1)!);
  final serverPub = b64d(RegExp(r'dh=([^;,\s]+)').firstMatch(cryptoKey)!.group(1)!);
  ok(serverPub.length == 65, 'dh=65 octets (${serverPub.length})');

  final serverPt = ecParams.curve.decodePoint(serverPub)!;
  final sharedPt = (serverPt * clientD)!;
  final shared = bigIntTo32(sharedPt.x!.toBigInteger()!);
  ok(serverPt.x!.toBigInteger()! != BigInt.zero, 'point partagé non nul');

  final ikm = hkdf(shared, authSecret, [
    ...utf8.encode('WebPush: info'), 0x00, ...mockPub, ...serverPub,
  ], 32);
  final prk = hkdf(ikm, salt, [...utf8.encode('Content-Encoding: auth'), 0x00], 32);
  final cek = hkdfExpand(prk, [...utf8.encode('Content-Encoding: aes128gcm'), 0x00], 16);
  final nonce = hkdfExpand(prk, [...utf8.encode('Content-Encoding: nonce'), 0x00], 12);

  final rs = ByteData.sublistView(Uint8List.fromList(body)).getUint32(16);
  ok(rs == 4096, 'record size=4096');
  final idlen = body[20];
  ok(idlen == 0, 'keyid len=0');
  final ciphertext = Uint8List.fromList(body.sublist(21));
  final plain = Uint8List(ciphertext.length);
  final gcm = pc.GCMBlockCipher(pc.AESEngine())
    ..init(
        false,
        pc.AEADParameters(
            pc.KeyParameter(Uint8List.fromList(cek)),
            128,
            Uint8List.fromList(nonce),
            Uint8List.fromList(body.sublist(0, 21))));
  final len1 = gcm.processBytes(ciphertext, 0, ciphertext.length, plain, 0);
  final len2 = gcm.doFinal(plain, len1);
  final record = plain.sublist(0, len1 + len2);
  ok(record.last == 0, 'padding final 0x00');

  final raw = utf8.decode(record.sublist(0, record.length - 1));
  final payload = jsonDecode(raw) as Map<String, dynamic>;
  ok(payload['title'] == 'Rappel MamaCare', 'titre décrypté OK');
  ok(payload['body'] == 'Prise de médicament', 'body décrypté OK');

  // ---- 6. Sécurité : B ne peut pas désinscrire A ------------------------------
  final unregB = await api('POST', '/api/push/unregister', token: tokenB, body: {
    'endpoint': 'http://127.0.0.1:4056/pushA',
  });
  ok(unregB['status'] == 200, 'unregister B réponse 200');
  await dumpSubs('après unregister B');
  final subsA = await db.query(
      'SELECT COUNT(*) FROM push_subscriptions WHERE user_id = (SELECT id FROM users WHERE email = @e)',
      substitutionValues: {'e': emailA});
  ok((subsA.first[0] as num) > 0, 'la souscription de A est intacte après tentative de B');

  // ---- 7. Redémarrage idempotent -----------------------------------------------
  final proc2 = await api('POST', '/api/push/process-reminders',
      headers: {'x-cron-secret': Env.get('CRON_SECRET')!});
  final proc2Body = jsonDecode(proc2['text'] as String) as Map<String, dynamic>;
  ok(proc2Body['inAppNotifications'] == 0 && proc2Body['pushSent'] == 0,
      'aucun renvoi (idempotence)');

  // ---- 8. Nettoyage -----------------------------------------------------------
  for (final mail in [emailA, emailB]) {
    await db.query('DELETE FROM users WHERE email = @e', substitutionValues: {'e': mail});
  }
  await mock.close(force: true);
  await appServer.close(force: true);
  await db.close();
  stdout.writeln('ALL_PASS');
}