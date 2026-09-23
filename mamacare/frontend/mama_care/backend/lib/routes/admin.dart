import 'dart:convert';
import 'dart:developer' as developer;
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:backend/config/database.dart';
import 'package:backend/utils/jwt.dart';
import 'package:backend/utils/hash.dart';
import 'package:backend/utils/json_safe.dart';
import 'package:uuid/uuid.dart';

Map<String, dynamic>? _extractUser(Request req) {
  final auth = req.headers['authorization'];
  if (auth == null || !auth.startsWith('Bearer ')) return null;
  final token = auth.substring(7);
  final jwt = JwtService();
  final payload = jwt.verify(token);
  return payload;
}

final _adminRouter = Router()
  ..get('/stats', (Request req) async {
    final user = _extractUser(req);
    if (user == null || user['role'] != 'admin') {
      return Response.forbidden(jsonEncode({'message': 'Unauthorized'}),
          headers: {'content-type': 'application/json'});
    }
    final db = Database();
    await db.connect();
    final res = await db.query(
        'SELECT (SELECT COUNT(*) FROM users WHERE role = \'patiente\') as total_patients, (SELECT COUNT(*) FROM users WHERE role = \'medecin\') as total_doctors, (SELECT COUNT(*) FROM users) as total_users, (SELECT COUNT(*) FROM alerts WHERE is_read = FALSE) as total_alerts, (SELECT COUNT(*) FROM appointments) as total_appointments, (SELECT COUNT(*) FROM appointments WHERE status = \'completed\') as completed_appointments');
    await db.close();
    return Response.ok(jsonEncode(jsonSafe(res.first.toColumnMap())),
        headers: {'content-type': 'application/json'});
  })
  ..get('/doctors', (Request req) async {
    final user = _extractUser(req);
    if (user == null || user['role'] != 'admin') {
      return Response.forbidden(jsonEncode({'message': 'Unauthorized'}),
          headers: {'content-type': 'application/json'});
    }

    final db = Database();
    await db.connect();
    try {
      final rows = await db.query('''
        SELECT d.id AS doctor_id, u.id AS user_id, u.email, u.first_name,
               u.last_name, u.status, d.specialization,
               d.hospital_affiliation,
               COUNT(p.id)::int AS patient_count
        FROM doctors d
        JOIN users u ON u.id = d.user_id
        LEFT JOIN patients p ON p.assigned_doctor_id = d.id
        GROUP BY d.id, u.id, u.email, u.first_name, u.last_name, u.status,
                 d.specialization, d.hospital_affiliation
        ORDER BY u.created_at DESC
      ''');
      return Response.ok(
        jsonEncode(rows.map((row) => jsonSafe(row.toColumnMap())).toList()),
        headers: {'content-type': 'application/json'},
      );
    } finally {
      await db.close();
    }
  })
  ..get('/patients', (Request req) async {
    final user = _extractUser(req);
    if (user == null || user['role'] != 'admin') {
      return Response.forbidden(jsonEncode({'message': 'Unauthorized'}),
          headers: {'content-type': 'application/json'});
    }
    final db = Database();
    await db.connect();
    try {
      final rows = await db.query('''
        SELECT u.id AS user_id, u.email, u.first_name, u.last_name,
               u.phone, u.status, u.created_at,
               p.id AS patient_id, p.pregnancy_weeks, p.due_date, p.blood_type,
               d.id AS doctor_id,
               du.first_name AS doctor_first_name,
               du.last_name AS doctor_last_name
        FROM users u
        LEFT JOIN patients p ON p.user_id = u.id
        LEFT JOIN doctors d ON d.id = p.assigned_doctor_id
        LEFT JOIN users du ON du.id = d.user_id
        WHERE u.role = 'patiente'
        ORDER BY u.created_at DESC
      ''');
      return Response.ok(
          jsonEncode(rows.map((row) => jsonSafe(row.toColumnMap())).toList()),
          headers: {'content-type': 'application/json'});
    } finally {
      await db.close();
    }
  })
  ..patch('/patients/<id>/status', (Request req, String id) async {
    try {
      final admin = _extractUser(req);
      if (admin == null || admin['role'] != 'admin') {
        return Response.forbidden(jsonEncode({'message': 'Unauthorized'}),
            headers: {'content-type': 'application/json'});
      }
      final userId = int.parse(id);
      final body = jsonDecode(await req.readAsString());
      final status = body is Map<String, dynamic> ? body['status'] : null;
      if (status != 'active' && status != 'disabled' && status != 'suspended') {
        return Response(400,
            body: jsonEncode({'error': 'Statut invalide'}),
            headers: {'content-type': 'application/json'});
      }
      final adminId = int.tryParse('${admin['id']}');
      if (adminId == null) {
        return Response.forbidden(jsonEncode({'message': 'Unauthorized'}),
            headers: {'content-type': 'application/json'});
      }
      final db = Database();
      await db.connect();
      try {
        final updated = await db.connection.transaction((ctx) async {
          final rows = await ctx.query('''
            UPDATE users
            SET status = @status, updated_at = NOW()
            WHERE id = @userId AND role = 'patiente'
            RETURNING id, status
          ''', substitutionValues: {'status': status, 'userId': userId});
          if (rows.isEmpty) return null;
          await ctx.query('''
            INSERT INTO activity_logs
              (user_id, action, resource_type, resource_id, details)
            VALUES (@adminId, @action, 'patient', @userId, @details)
          ''', substitutionValues: {
            'adminId': adminId,
            'action': status == 'active'
                ? 'PATIENT_ACTIVATION'
                : status == 'disabled'
                    ? 'PATIENT_DEACTIVATION'
                    : 'PATIENT_SUSPENSION',
            'userId': userId,
            'details': 'status=$status',
          });
          return rows.first.toColumnMap();
        });
        if (updated == null) {
          return Response.notFound(
              jsonEncode({'error': 'Patiente introuvable'}),
              headers: {'content-type': 'application/json'});
        }
        return Response.ok(jsonEncode(jsonSafe(updated)),
            headers: {'content-type': 'application/json'});
      } finally {
        await db.close();
      }
    } on FormatException {
      return Response(400,
          body: jsonEncode({'error': 'Identifiant ou JSON invalide'}),
          headers: {'content-type': 'application/json'});
    } catch (error) {
      developer.log('Erreur modification statut patiente: $error',
          level: 1000);
      return Response.internalServerError(
          body: jsonEncode({'error': 'Impossible de modifier le statut'}),
          headers: {'content-type': 'application/json'});
    }
  })
  ..patch('/doctors/<id>/status', (Request req, String id) async {
    try {
      final admin = _extractUser(req);
      if (admin == null || admin['role'] != 'admin') {
        return Response.forbidden(jsonEncode({'message': 'Unauthorized'}),
            headers: {'content-type': 'application/json'});
      }
      final userId = int.parse(id);
      final body = jsonDecode(await req.readAsString());
      final status = body is Map<String, dynamic> ? body['status'] : null;
      if (status != 'active' && status != 'disabled') {
        return Response(400,
            body: jsonEncode({'error': 'Statut invalide'}),
            headers: {'content-type': 'application/json'});
      }

      final adminId = int.tryParse('${admin['id']}');
      if (adminId == null) {
        return Response.forbidden(jsonEncode({'message': 'Unauthorized'}),
            headers: {'content-type': 'application/json'});
      }

      final db = Database();
      await db.connect();
      try {
        final updated = await db.connection.transaction((ctx) async {
          final rows = await ctx.query('''
            UPDATE users
            SET status = @status, updated_at = NOW()
            WHERE id = @userId AND role = 'medecin'
            RETURNING id, status
          ''', substitutionValues: {'status': status, 'userId': userId});
          if (rows.isEmpty) return null;
          await ctx.query('''
            INSERT INTO activity_logs
              (user_id, action, resource_type, resource_id, details)
            VALUES (@adminId, @action, 'doctor', @userId, @details)
          ''', substitutionValues: {
            'adminId': adminId,
            'action': status == 'disabled'
                ? 'DOCTOR_DEACTIVATION'
                : 'DOCTOR_ACTIVATION',
            'userId': userId,
            'details': 'status=$status',
          });
          return rows.first.toColumnMap();
        });
        if (updated == null) {
          return Response.notFound(jsonEncode({'error': 'Médecin introuvable'}),
              headers: {'content-type': 'application/json'});
        }
        return Response.ok(jsonEncode(jsonSafe(updated)),
            headers: {'content-type': 'application/json'});
      } finally {
        await db.close();
      }
    } on FormatException {
      return Response(400,
          body: jsonEncode({'error': 'Identifiant ou JSON invalide'}),
          headers: {'content-type': 'application/json'});
    } catch (error) {
      developer.log('Erreur modification statut médecin: $error', level: 1000);
      return Response.internalServerError(
          body: jsonEncode({'error': 'Impossible de modifier le statut'}),
          headers: {'content-type': 'application/json'});
    }
  })
  ..get('/activity-logs', (Request req) async {
    final admin = _extractUser(req);
    if (admin == null || admin['role'] != 'admin') {
      return Response.forbidden(jsonEncode({'message': 'Unauthorized'}),
          headers: {'content-type': 'application/json'});
    }
    final db = Database();
    await db.connect();
    try {
      final rows = await db.query('''
        SELECT l.id, l.action, l.created_at,
               COALESCE(a.first_name || ' ' || a.last_name, a.email, 'Administrateur') AS actor,
               COALESCE(t.first_name || ' ' || t.last_name, t.email, '') AS target
        FROM activity_logs l
        LEFT JOIN users a ON a.id = l.user_id
        LEFT JOIN users t ON t.id = l.resource_id
        ORDER BY l.created_at DESC
      ''');
      return Response.ok(
          jsonEncode(rows.map((row) => jsonSafe(row.toColumnMap())).toList()),
          headers: {'content-type': 'application/json'});
    } finally {
      await db.close();
    }
  })
  ..post('/doctors', (Request req) async {
    try {
      final user = _extractUser(req);
      if (user == null || user['role'] != 'admin') {
        return Response.forbidden(
          jsonEncode({'error': 'Unauthorized'}),
          headers: {'content-type': 'application/json'},
        );
      }

      final body = jsonDecode(await req.readAsString());
      if (body is! Map<String, dynamic>) {
        return Response(400,
            body: jsonEncode({'error': 'JSON invalide'}),
            headers: {'content-type': 'application/json'});
      }
      final email = (body['email'] as String?)?.trim();
      final password = body['password'] as String?;
      final firstName = (body['firstName'] as String?)?.trim();
      final lastName = (body['lastName'] as String?)?.trim();
      final specialization = (body['specialization'] as String?)?.trim();
      final hospitalAffiliation =
          (body['hospitalAffiliation'] as String?)?.trim();

      if (email == null ||
          email.isEmpty ||
          password == null ||
          password.length < 6 ||
          firstName == null ||
          firstName.isEmpty) {
        return Response(400,
            body: jsonEncode({
              'error':
                  'Nom, e-mail et mot de passe (6 caractères minimum) sont obligatoires'
            }),
            headers: {'content-type': 'application/json'});
      }

      final db = Database();
      await db.connect();
      try {
        final existing = await db.query(
            'SELECT id FROM users WHERE email = @email',
            substitutionValues: {'email': email});
        if (existing.isNotEmpty) {
          return Response(409,
              body: jsonEncode(
                  {'error': 'Cette adresse e-mail est déjà utilisée'}),
              headers: {'content-type': 'application/json'});
        }

        final created = await db.connection.transaction((ctx) async {
          final userRows = await ctx.query('''
            INSERT INTO users (uuid, email, password_hash, first_name, last_name, role, status)
            VALUES (@uuid, @email, @passwordHash, @firstName, @lastName, 'medecin', 'active')
            RETURNING id, uuid, email, first_name, last_name, role, status
          ''', substitutionValues: {
            'uuid': const Uuid().v4(),
            'email': email,
            'passwordHash': HashService.hashPassword(password),
            'firstName': firstName,
            'lastName': lastName?.isEmpty == true ? null : lastName,
          });
          final createdUser = userRows.first.toColumnMap();
          final doctorRows = await ctx.query('''
            INSERT INTO doctors (user_id, specialization, hospital_affiliation)
            VALUES (@userId, @specialization, @hospitalAffiliation)
            RETURNING id, user_id, specialization, hospital_affiliation
          ''', substitutionValues: {
            'userId': createdUser['id'],
            'specialization':
                specialization?.isEmpty == true ? null : specialization,
            'hospitalAffiliation': hospitalAffiliation?.isEmpty == true
                ? null
                : hospitalAffiliation,
          });
          final adminId = int.tryParse('${user['id']}');
          if (adminId == null) {
            throw StateError('Administrateur invalide');
          }
          await ctx.query('''
            INSERT INTO activity_logs
              (user_id, action, resource_type, resource_id, details)
            VALUES (@adminId, 'DOCTOR_CREATION', 'doctor', @doctorId, @details)
          ''', substitutionValues: {
            'adminId': adminId,
            'doctorId': createdUser['id'],
            'details': 'email=$email',
          });
          return {
            'user': createdUser,
            'doctor': doctorRows.first.toColumnMap()
          };
        });

        return Response(201,
            body: jsonEncode(jsonSafe(created)),
            headers: {'content-type': 'application/json'});
      } finally {
        await db.close();
      }
    } on FormatException {
      return Response(400,
          body: jsonEncode({'error': 'JSON invalide'}),
          headers: {'content-type': 'application/json'});
    } catch (error) {
      developer.log('Erreur création médecin: $error', level: 1000);
      return Response.internalServerError(
          body: jsonEncode({'error': 'Impossible de créer le compte médecin'}),
          headers: {'content-type': 'application/json'});
    }
  });

final router = _adminRouter;
