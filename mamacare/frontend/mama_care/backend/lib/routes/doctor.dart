import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:backend/config/database.dart';
import 'package:backend/utils/jwt.dart';
import 'package:backend/utils/json_safe.dart';

Map<String, dynamic>? _extractUser(Request req) {
  final auth = req.headers['authorization'];
  if (auth == null || !auth.startsWith('Bearer ')) return null;
  final token = auth.substring(7);
  final jwt = JwtService();
  final payload = jwt.verify(token);
  return payload;
}

final _doctorRouter = Router()
  ..get('/profile', (Request req) async {
    final user = _extractUser(req);
    if (user == null || user['role'] != 'medecin') return Response.forbidden(jsonEncode({'message': 'Unauthorized'}), headers: {'content-type': 'application/json'});
    final uid = user['id']?.toString();
    final db = Database();
    await db.connect();
    final res = await db.query('SELECT d.*, u.email, u.first_name, u.last_name, u.phone FROM doctors d JOIN users u ON d.user_id = u.id WHERE d.user_id = @id', substitutionValues: {'id': int.parse(uid!)});
    await db.close();
    if (res.isEmpty) return Response.notFound(jsonEncode({'message': 'Doctor profile not found'}), headers: {'content-type': 'application/json'});
    return Response.ok(jsonEncode(jsonSafe(res.first.toColumnMap())), headers: {'content-type': 'application/json'});
  })
  ..get('/patients', (Request req) async {
    final user = _extractUser(req);
    if (user == null || user['role'] != 'medecin') return Response.forbidden(jsonEncode({'message': 'Unauthorized'}), headers: {'content-type': 'application/json'});
    final uid = user['id']?.toString();
    final db = Database();
    await db.connect();
    final docRes = await db.query('SELECT id FROM doctors WHERE user_id = @uid', substitutionValues: {'uid': int.parse(uid!)});
    if (docRes.isEmpty) { await db.close(); return Response.notFound(jsonEncode({'message': 'Doctor not found'}), headers: {'content-type': 'application/json'});} 
    final docId = docRes.first[0];
    final patients = await db.query('SELECT p.*, u.first_name, u.last_name, u.email FROM patients p JOIN users u ON p.user_id = u.id WHERE p.assigned_doctor_id = @d', substitutionValues: {'d': docId});
    await db.close();
    return Response.ok(jsonEncode(patients.map((r) => jsonSafe(r.toColumnMap())).toList()), headers: {'content-type': 'application/json'});
  })
  ..get('/patients/<id>', (Request req, String id) async {
    final user = _extractUser(req);
    if (user == null || user['role'] != 'medecin') return Response.forbidden(jsonEncode({'message': 'Unauthorized'}), headers: {'content-type': 'application/json'});
    final db = Database();
    await db.connect();
    try {
      final docRes = await db.query('SELECT id FROM doctors WHERE user_id = @uid', substitutionValues: {'uid': int.parse(user['id'].toString())});
      if (docRes.isEmpty) return Response.notFound(jsonEncode({'message': 'Doctor not found'}), headers: {'content-type': 'application/json'});
      final docId = docRes.first[0];
      final pid = int.tryParse(id);
      if (pid == null) return Response(400, body: jsonEncode({'error': 'Identifiant invalide'}), headers: {'content-type': 'application/json'});
      final pat = await db.query('''SELECT p.*, u.email, u.first_name, u.last_name, u.phone
          FROM patients p JOIN users u ON u.id = p.user_id
          WHERE p.id = @pid AND p.assigned_doctor_id = @d''', substitutionValues: {'pid': pid, 'd': docId});
      if (pat.isEmpty) return Response.notFound(jsonEncode({'message': 'Patient not found'}), headers: {'content-type': 'application/json'});
      final telemetry = await db.query('''SELECT * FROM telemetry WHERE patient_id = @pid ORDER BY recorded_at DESC LIMIT 20''', substitutionValues: {'pid': pid});
      final analysisRes = await db.query('''SELECT severity, message, details, created_at FROM alerts
          WHERE patient_id = @pid AND doctor_id = @d AND alert_type = 'ia_assessment'
          ORDER BY created_at DESC LIMIT 1''', substitutionValues: {'pid': pid, 'd': docId});
      final analysis = analysisRes.isEmpty
          ? null
          : (analysisRes.first.toColumnMap().isEmpty ? null : jsonSafe(analysisRes.first.toColumnMap()));
      return Response.ok(jsonEncode({
        'patient': jsonSafe(pat.first.toColumnMap()),
        'telemetry': telemetry.map((r) => jsonSafe(r.toColumnMap())).toList(),
        if (analysis != null) 'analysis': analysis,
      }), headers: {'content-type': 'application/json'});
    } finally {
      await db.close();
    }
  })
  ..get('/alerts', (Request req) async {
    final user = _extractUser(req);
    if (user == null || user['role'] != 'medecin') return Response.forbidden(jsonEncode({'message': 'Unauthorized'}), headers: {'content-type': 'application/json'});
    final db = Database();
    await db.connect();
    try {
      final docRes = await db.query('SELECT id FROM doctors WHERE user_id = @uid', substitutionValues: {'uid': int.parse(user['id'].toString())});
      if (docRes.isEmpty) return Response.notFound(jsonEncode({'message': 'Doctor not found'}), headers: {'content-type': 'application/json'});
      final docId = docRes.first[0];
      final rows = await db.query('''SELECT a.id, a.alert_type, a.severity, a.message, a.details,
          a.is_read, a.created_at, p.id AS patient_id, p.pregnancy_weeks,
          u.first_name, u.last_name
          FROM alerts a JOIN patients p ON p.id = a.patient_id JOIN users u ON u.id = p.user_id
          WHERE a.doctor_id = @d ORDER BY a.created_at DESC''', substitutionValues: {'d': docId});
      return Response.ok(jsonEncode(rows.map((r) => jsonSafe(r.toColumnMap())).toList()), headers: {'content-type': 'application/json'});
    } finally {
      await db.close();
    }
  })
  ..get('/alerts/unread-count', (Request req) async {
    final user = _extractUser(req);
    if (user == null || user['role'] != 'medecin') return Response.forbidden(jsonEncode({'message': 'Unauthorized'}), headers: {'content-type': 'application/json'});
    final db = Database();
    await db.connect();
    try {
      final docRes = await db.query('SELECT id FROM doctors WHERE user_id = @uid', substitutionValues: {'uid': int.parse(user['id'].toString())});
      if (docRes.isEmpty) return Response.notFound(jsonEncode({'message': 'Doctor not found'}), headers: {'content-type': 'application/json'});
      final docId = docRes.first[0];
      final rows = await db.query('SELECT COUNT(*) AS c FROM alerts WHERE doctor_id = @d AND is_read = false', substitutionValues: {'d': docId});
      final count = rows.first[0];
      return Response.ok(jsonEncode({'count': count}), headers: {'content-type': 'application/json'});
    } finally {
      await db.close();
    }
  })
  ..patch('/alerts/<id>/read', (Request req, String id) async {
    final user = _extractUser(req);
    if (user == null || user['role'] != 'medecin') return Response.forbidden(jsonEncode({'message': 'Unauthorized'}), headers: {'content-type': 'application/json'});
    final db = Database();
    await db.connect();
    try {
      final docRes = await db.query('SELECT id FROM doctors WHERE user_id = @uid', substitutionValues: {'uid': int.parse(user['id'].toString())});
      if (docRes.isEmpty) return Response.notFound(jsonEncode({'message': 'Doctor not found'}), headers: {'content-type': 'application/json'});
      final alertId = int.tryParse(id);
      if (alertId == null) return Response(400, body: jsonEncode({'error': 'Identifiant invalide'}), headers: {'content-type': 'application/json'});
      await db.query('UPDATE alerts SET is_read = true, read_at = NOW() WHERE id = @id AND doctor_id = @d', substitutionValues: {'id': alertId, 'd': docRes.first[0]});
      return Response.ok(jsonEncode({'status': 'ok'}), headers: {'content-type': 'application/json'});
    } finally {
      await db.close();
    }
  })
  ..get('/stats', (Request req) async {
    final user = _extractUser(req);
    if (user == null || user['role'] != 'medecin') return Response.forbidden(jsonEncode({'message': 'Unauthorized'}), headers: {'content-type': 'application/json'});
    final uid = int.parse(user['id'].toString());
    final db = Database();
    await db.connect();
    try {
      final docRes = await db.query('SELECT id FROM doctors WHERE user_id = @uid', substitutionValues: {'uid': uid});
      if (docRes.isEmpty) return Response.notFound(jsonEncode({'message': 'Doctor not found'}), headers: {'content-type': 'application/json'});
      final docId = docRes.first[0];
      final patientsRes = await db.query('SELECT COUNT(*) AS c FROM patients WHERE assigned_doctor_id = @d', substitutionValues: {'d': docId});
      final alertsRes = await db.query('SELECT COUNT(*) AS c FROM alerts WHERE doctor_id = @d AND is_read = false', substitutionValues: {'d': docId});
      final messagesRes = await db.query('SELECT COUNT(*) AS c FROM messages WHERE recipient_id = @u AND is_read = false', substitutionValues: {'u': uid});
      return Response.ok(jsonEncode({
        'patients': patientsRes.first[0],
        'alerts': alertsRes.first[0],
        'messages': messagesRes.first[0],
      }), headers: {'content-type': 'application/json'});
    } finally {
      await db.close();
    }
  })
  ..patch('/profile', (Request req) async {
    final user = _extractUser(req);
    if (user == null || user['role'] != 'medecin') {
      return Response.forbidden(jsonEncode({'message': 'Unauthorized'}),
          headers: {'content-type': 'application/json'});
    }
    final uid = int.tryParse('${user['id']}');
    if (uid == null) {
      return Response.forbidden(jsonEncode({'message': 'Unauthorized'}),
          headers: {'content-type': 'application/json'});
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(await req.readAsString());
    } on FormatException {
      return Response(400,
          body: jsonEncode({'error': 'JSON invalide'}),
          headers: {'content-type': 'application/json'});
    }
    if (decoded is! Map<String, dynamic>) {
      return Response(400,
          body: jsonEncode({'error': 'JSON invalide'}),
          headers: {'content-type': 'application/json'});
    }
    final body = decoded;

    final firstName = (body['firstName'] as String?)?.trim();
    final lastName = (body['lastName'] as String?)?.trim();
    final phone = (body['phone'] as String?)?.trim();
    final email = (body['email'] as String?)?.trim();
    final specialization = (body['specialization'] as String?)?.trim();
    final hospitalAffiliation =
        (body['hospitalAffiliation'] as String?)?.trim();

    final db = Database();
    await db.connect();
    try {
      final info = await db.query('''
        SELECT u.first_name, u.last_name, u.phone, u.email,
               d.specialization, d.hospital_affiliation
        FROM users u
        JOIN doctors d ON d.user_id = u.id
        WHERE u.id = @uid
      ''', substitutionValues: {'uid': uid});
      if (info.isEmpty) {
        return Response.notFound(jsonEncode({'message': 'Doctor not found'}),
            headers: {'content-type': 'application/json'});
      }

      final cur = info.first.toColumnMap();
      final newFirstName =
          firstName == null || firstName.isEmpty ? cur['first_name'] : firstName;
      final newLastName =
          lastName == null || lastName.isEmpty ? cur['last_name'] : lastName;
      final newPhone = phone == null || phone.isEmpty ? cur['phone'] : phone;
      final newEmail =
          email == null || email.isEmpty ? cur['email'] : email;
      final newSpecialization = specialization == null || specialization.isEmpty
          ? cur['specialization']
          : specialization;
      final newHospitalAffiliation =
          hospitalAffiliation == null || hospitalAffiliation.isEmpty
              ? cur['hospital_affiliation']
              : hospitalAffiliation;

      if (newEmail.toString() != cur['email'].toString()) {
        final dup = await db.query(
          'SELECT id FROM users WHERE email = @email AND id != @uid',
          substitutionValues: {'email': newEmail, 'uid': uid},
        );
        if (dup.isNotEmpty) {
          return Response(409,
              body: jsonEncode(
                  {'error': 'Cette adresse e-mail est déjà utilisée'}),
              headers: {'content-type': 'application/json'});
        }
      }

      await db.connection.transaction((ctx) async {
        await ctx.query('''
          UPDATE users
          SET first_name = @fn, last_name = @ln, phone = @ph,
              email = @em, updated_at = NOW()
          WHERE id = @uid
        ''', substitutionValues: {
          'fn': newFirstName,
          'ln': newLastName,
          'ph': newPhone,
          'em': newEmail,
          'uid': uid,
        });
        await ctx.query('''
          UPDATE doctors
          SET specialization = @spec, hospital_affiliation = @hosp
          WHERE user_id = @uid
        ''', substitutionValues: {
          'spec': newSpecialization,
          'hosp': newHospitalAffiliation,
          'uid': uid,
        });
      });

      final updated = await db.query('''
        SELECT d.*, u.email, u.first_name, u.last_name, u.phone
        FROM doctors d
        JOIN users u ON d.user_id = u.id
        WHERE d.user_id = @uid
      ''', substitutionValues: {'uid': uid});
      return Response.ok(jsonEncode(jsonSafe(updated.first.toColumnMap())),
          headers: {'content-type': 'application/json'});
    } finally {
      await db.close();
    }
  });

final router = _doctorRouter;
