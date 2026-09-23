import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'package:backend/config/database.dart';
import 'package:backend/utils/jwt.dart';
import 'package:backend/utils/json_safe.dart';

Map<String, dynamic>? _user(Request request) {
  final authorization = request.headers['authorization'];
  if (authorization == null || !authorization.startsWith('Bearer ')) return null;
  return JwtService().verify(authorization.substring(7));
}

Response _json(int status, Object body) => Response(
      status,
      body: jsonEncode(jsonSafe(body)),
      headers: {'content-type': 'application/json'},
    );

final router = Router()
  ..get('/', (Request request) async {
    final user = _user(request);
    if (user == null) return _json(401, {'message': 'Unauthorized'});
    final db = Database();
    await db.connect();
    try {
      final rows = await db.query('''
        SELECT id, title, message, notification_type, data, is_sent, is_read,
               sent_at, read_at, created_at
        FROM notifications
        WHERE user_id = @userId
        ORDER BY created_at DESC
        LIMIT 100
      ''', substitutionValues: {'userId': int.parse(user['id'].toString())});
      return _json(200, rows.map((row) => row.toColumnMap()).toList());
    } finally {
      await db.close();
    }
  })
  ..get('/unread-count', (Request request) async {
    final user = _user(request);
    if (user == null) return _json(401, {'message': 'Unauthorized'});
    final db = Database();
    await db.connect();
    try {
      final rows = await db.query(
        'SELECT COUNT(*) AS count FROM notifications WHERE user_id = @userId AND is_read = FALSE',
        substitutionValues: {'userId': int.parse(user['id'].toString())},
      );
      return _json(200, {'count': rows.first[0]});
    } finally {
      await db.close();
    }
  })
  ..post('/read-all', (Request request) async {
    final user = _user(request);
    if (user == null) return _json(401, {'message': 'Unauthorized'});
    final db = Database();
    await db.connect();
    try {
      await db.query('''
        UPDATE notifications
        SET is_read = TRUE, read_at = NOW()
        WHERE user_id = @userId AND is_read = FALSE
      ''', substitutionValues: {'userId': int.parse(user['id'].toString())});
      return _json(200, {'message': 'Notifications marked as read'});
    } finally {
      await db.close();
    }
  })
  ..post('/<id>/read', (Request request, String id) async {
    final user = _user(request);
    if (user == null) return _json(401, {'message': 'Unauthorized'});
    final db = Database();
    await db.connect();
    try {
      final result = await db.query('''
        UPDATE notifications
        SET is_read = TRUE, read_at = NOW()
        WHERE id = @id AND user_id = @userId
        RETURNING id
      ''', substitutionValues: {
        'id': int.parse(id),
        'userId': int.parse(user['id'].toString()),
      });
      if (result.isEmpty) return _json(404, {'message': 'Notification not found'});
      return _json(200, {'message': 'Notification marked as read'});
    } finally {
      await db.close();
    }
  })
  ..post('/', (Request request) async {
    final user = _user(request);
    if (user == null || user['role'] != 'admin') return _json(403, {'message': 'Admin role required'});
    final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
    final userId = body['userId'] as int?;
    final message = body['message'] as String?;
    if (userId == null || message == null || message.trim().isEmpty) {
      return _json(400, {'message': 'userId and message are required'});
    }
    final db = Database();
    await db.connect();
    try {
      final result = await db.query('''
        INSERT INTO notifications (user_id, title, message, notification_type, is_sent, sent_at)
        VALUES (@userId, @title, @message, @type, TRUE, NOW())
        RETURNING id, user_id, title, message, notification_type, is_read, created_at
      ''', substitutionValues: {
        'userId': userId,
        'title': body['title'] as String? ?? 'MamaCare',
        'message': message,
        'type': body['type'] as String? ?? 'system',
      });
      return _json(201, result.first.toColumnMap());
    } finally {
      await db.close();
    }
  });
