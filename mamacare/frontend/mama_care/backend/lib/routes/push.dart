import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'package:backend/config/database.dart';
import 'package:backend/utils/env.dart';
import 'package:backend/utils/jwt.dart';
import 'package:backend/utils/json_safe.dart';
import 'package:backend/utils/web_push.dart';

const _maxSubscriptions = 10;

Map<String, dynamic>? _user(Request request) {
  final authorization = request.headers['authorization'];
  if (authorization == null || !authorization.startsWith('Bearer ')) return null;
  final payload = JwtService().verify(authorization.substring(7));
  if (payload == null || payload['status'] != 'active') return null;
  return payload;
}

Response _json(int status, Object body) => Response(
      status,
      body: jsonEncode(jsonSafe(body)),
      headers: {'content-type': 'application/json'},
    );

final router = Router()
  ..get('/vapid-public-key', (Request request) async {
    final service = WebPushService.getInstance();
    if (service == null) {
      return _json(503, {'error': 'Web push non configuré (clés VAPID manquantes)'});
    }
    return _json(200, {'publicKey': service.publicKeyB64});
  })
  ..post('/register', (Request request) async {
    final user = _user(request);
    if (user == null) return _json(401, {'message': 'Unauthorized'});
    final Object? decoded;
    try {
      decoded = jsonDecode(await request.readAsString());
    } catch (_) {
      return _json(400, {'error': 'JSON invalide'});
    }
    final body = decoded is Map<String, dynamic> ? decoded : null;
    final endpoint = body?['endpoint'] as String?;
    final p256dh = body?['p256dh'] as String?;
    final auth = body?['auth'] as String?;
    if (endpoint == null || p256dh == null || auth == null || endpoint.isEmpty) {
      return _json(400, {'error': 'endpoint, p256dh et auth sont requis'});
    }
    final uri = Uri.tryParse(endpoint);
    if (uri == null || !(uri.scheme == 'https' || uri.scheme == 'http')) {
      return _json(400, {'error': 'endpoint invalide'});
    }
    final db = Database();
    await db.connect();
    try {
      final userId = int.parse(user['id'].toString());
      final count = await db.query(
        'SELECT COUNT(*) AS count FROM push_subscriptions WHERE user_id = @u',
        substitutionValues: {'u': userId},
      );
      final total = (count.first[0] as num).toInt();
      if (total >= _maxSubscriptions) {
        return _json(400, {'error': 'Trop de souscriptions pour ce compte'});
      }
      await db.query(
        '''INSERT INTO push_subscriptions (user_id, endpoint, p256dh, auth, platform, updated_at)
           VALUES (@u, @e, @p, @a, 'web', NOW())
           ON CONFLICT (user_id, endpoint)
           DO UPDATE SET p256dh = EXCLUDED.p256dh, auth = EXCLUDED.auth, updated_at = NOW()''',
        substitutionValues: {
          'u': userId,
          'e': endpoint,
          'p': p256dh,
          'a': auth,
        },
      );
      return _json(201, {'message': 'Subscription registered'});
    } finally {
      await db.close();
    }
  })
  ..post('/unregister', (Request request) async {
    final user = _user(request);
    if (user == null) return _json(401, {'message': 'Unauthorized'});
    final Object? decoded;
    try {
      decoded = jsonDecode(await request.readAsString());
    } catch (_) {
      return _json(400, {'error': 'JSON invalide'});
    }
    final endpoint = decoded is Map<String, dynamic> ? decoded['endpoint'] as String? : null;
    if (endpoint == null || endpoint.isEmpty) {
      return _json(400, {'error': 'endpoint est requis'});
    }
    final db = Database();
    await db.connect();
    try {
      await db.query(
        'DELETE FROM push_subscriptions WHERE user_id = @u AND endpoint = @e',
        substitutionValues: {
          'u': int.parse(user['id'].toString()),
          'e': endpoint,
        },
      );
      return _json(200, {'message': 'Subscription removed'});
    } finally {
      await db.close();
    }
  })
  ..post('/process-reminders', (Request request) async {
    // Sécurité : endpoint pour Render Cron (ou Timer interne de server.dart).
    final secret = Env.get('CRON_SECRET') ?? '';
    if (secret.isNotEmpty && request.headers['x-cron-secret'] != secret) {
      return _json(401, {'message': 'Non autorisé'});
    }
    final db = Database();
    await db.connect();
    try {
      final result = await processDueReminders(db);
      return _json(200, result);
    } finally {
      await db.close();
    }
  });

/// Traite les rappels arrivés à échéance : crée la notification in-app puis
/// envoie le push web à toutes les souscriptions de la patiente.
Future<Map<String, dynamic>> processDueReminders(Database db) async {
  final rows = await db.query('''
    SELECT r.id, r.title, u.id AS user_id
    FROM patient_reminders r
    JOIN patients p ON p.id = r.patient_id
    JOIN users u ON u.id = p.user_id AND u.status = 'active'
    WHERE r.is_done = FALSE AND r.push_notified_at IS NULL AND r.reminder_date <= NOW()
    ORDER BY r.reminder_date
    LIMIT 50
  ''');

  var inAppNotifs = 0;
  var pushSent = 0;
  var pushFailed = 0;

  for (final row in rows) {
    final reminder = row.toColumnMap();
    final reminderId = reminder['id'];
    final userId = (reminder['user_id'] as num).toInt();
    final title = (reminder['title'] as String?) ?? 'Rappel';

    await db.query(
      '''INSERT INTO notifications (user_id, title, message, notification_type, is_sent, sent_at)
         VALUES (@u, 'Rappel', @m, 'reminder', TRUE, NOW())''',
      substitutionValues: {'u': userId, 'm': title},
    );
    inAppNotifs++;

    final subs = await db.query(
      'SELECT id, endpoint, p256dh, auth FROM push_subscriptions WHERE user_id = @u',
      substitutionValues: {'u': userId},
    );
    for (final sub in subs) {
      final map = sub.toColumnMap();
      try {
        final service = WebPushService.getInstance();
        if (service == null || !service.isConfigured) {
          pushFailed++;
          continue;
        }
        // `send` renvoie false quand le serveur push répond 404/410 :
        // l'abonnement est perime, on le supprime pour ne pas reessayer.
        final delivered = await service.send(
          endpoint: map['endpoint'] as String,
          p256dh: map['p256dh'] as String,
          auth: map['auth'] as String,
          title: 'Rappel MamaCare',
          body: title,
          url: '/',
        );
        if (delivered) {
          pushSent++;
        } else {
          await db.query(
            'DELETE FROM push_subscriptions WHERE id = @id',
            substitutionValues: {'id': map['id']},
          );
        }
      } catch (_) {
        pushFailed++;
      }
    }

    await db.query(
      'UPDATE patient_reminders SET push_notified_at = NOW() WHERE id = @id',
      substitutionValues: {'id': reminderId},
    );
  }

  return {
    'processed': rows.length,
    'inAppNotifications': inAppNotifs,
    'pushSent': pushSent,
    'pushFailed': pushFailed,
  };
}