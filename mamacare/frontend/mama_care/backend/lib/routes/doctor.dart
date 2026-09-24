import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:backend/config/database.dart';
import 'package:backend/utils/jwt.dart';
import 'package:backend/utils/json_safe.dart';
import 'package:backend/utils/dates_fr.dart';

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
          u.first_name, u.last_name, u.phone AS patient_phone
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
      final alertsBySeverity = await db.query('''SELECT COALESCE(NULLIF(severity, ''), 'info') AS severity,
          COUNT(*)::int AS count FROM alerts WHERE doctor_id = @d
          GROUP BY severity ORDER BY count DESC''', substitutionValues: {'d': docId});
      final alertsTrend = await db.query('''
        SELECT to_char(d.day, 'YYYY-MM-DD') AS date, COUNT(a.id)::int AS count
        FROM generate_series(CURRENT_DATE - INTERVAL '13 days', CURRENT_DATE, '1 day') d(day)
        LEFT JOIN alerts a ON a.doctor_id = @d AND a.created_at::date = d.day
        GROUP BY d.day ORDER BY d.day''', substitutionValues: {'d': docId});
      final patientsByWeeks = await db.query('''
        SELECT CASE
            WHEN pregnancy_weeks IS NULL OR pregnancy_weeks < 1 THEN 'Non défini'
            WHEN pregnancy_weeks <= 12 THEN '1-12 sem'
            WHEN pregnancy_weeks <= 27 THEN '13-27 sem'
            ELSE '28+ sem'
          END AS bracket, COUNT(*)::int AS count
        FROM patients WHERE assigned_doctor_id = @d
        GROUP BY bracket ORDER BY count DESC''', substitutionValues: {'d': docId});
      return Response.ok(jsonEncode({
        'patients': patientsRes.first[0],
        'alerts': alertsRes.first[0],
        'messages': messagesRes.first[0],
        'alerts_by_severity': alertsBySeverity.map((r) => jsonSafe(r.toColumnMap())).toList(),
        'alerts_trend': alertsTrend.map((r) => jsonSafe(r.toColumnMap())).toList(),
        'patients_by_weeks': patientsByWeeks.map((r) => jsonSafe(r.toColumnMap())).toList(),
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
  })
  ..get('/messages', (Request req) async {
    final user = _extractUser(req);
    if (user == null || user['role'] != 'medecin') {
      return Response.forbidden(jsonEncode({'message': 'Unauthorized'}),
          headers: {'content-type': 'application/json'});
    }
    final docUid = int.parse(user['id'].toString());
    final db = Database();
    await db.connect();
    try {
      final docRes = await db.query(
          'SELECT id FROM doctors WHERE user_id = @uid',
          substitutionValues: {'uid': docUid});
      if (docRes.isEmpty) {
        return Response.notFound(jsonEncode({'message': 'Doctor not found'}),
            headers: {'content-type': 'application/json'});
      }
      final docId = docRes.first[0];
      final rows = await db.query('''SELECT u.id AS patient_user_id, u.first_name,
          u.last_name, p.id AS patient_id,
          (SELECT m2.message_text FROM messages m2
             WHERE (m2.sender_id = u.id AND m2.recipient_id = @du)
                OR (m2.sender_id = @du AND m2.recipient_id = u.id)
             ORDER BY m2.created_at DESC LIMIT 1) AS last_message,
          (SELECT m2.created_at FROM messages m2
             WHERE (m2.sender_id = u.id AND m2.recipient_id = @du)
                OR (m2.sender_id = @du AND m2.recipient_id = u.id)
             ORDER BY m2.created_at DESC LIMIT 1) AS last_message_at,
          (SELECT COUNT(*) FROM messages m2
             WHERE m2.sender_id = u.id AND m2.recipient_id = @du
               AND m2.is_read = FALSE) AS unread_count
          FROM patients p
          JOIN users u ON u.id = p.user_id
          WHERE p.assigned_doctor_id = @docId
          ORDER BY u.first_name''',
          substitutionValues: {'du': docUid, 'docId': docId});
      return Response.ok(jsonEncode(
          rows.map((r) => jsonSafe(r.toColumnMap())).toList()),
          headers: {'content-type': 'application/json'});
    } finally {
      await db.close();
    }
  })
  ..get('/messages/<patientUserId>', (Request req, String patientUserId) async {
    final user = _extractUser(req);
    if (user == null || user['role'] != 'medecin') {
      return Response.forbidden(jsonEncode({'message': 'Unauthorized'}),
          headers: {'content-type': 'application/json'});
    }
    final docUid = int.parse(user['id'].toString());
    final pid = int.tryParse(patientUserId);
    if (pid == null) {
      return Response(400,
          body: jsonEncode({'error': 'Identifiant invalide'}),
          headers: {'content-type': 'application/json'});
    }
    final db = Database();
    await db.connect();
    try {
      final docRes = await db.query(
          'SELECT id FROM doctors WHERE user_id = @uid',
          substitutionValues: {'uid': docUid});
      if (docRes.isEmpty) {
        return Response.notFound(jsonEncode({'message': 'Doctor not found'}),
            headers: {'content-type': 'application/json'});
      }
      final docId = docRes.first[0];
      final patient = await db.query('''SELECT u.id AS user_id, u.first_name,
          u.last_name FROM patients p JOIN users u ON u.id = p.user_id
          WHERE p.user_id = @pid AND p.assigned_doctor_id = @docId''',
          substitutionValues: {'pid': pid, 'docId': docId});
      if (patient.isEmpty) {
        return Response.notFound(
            jsonEncode({'message': 'Patiente non affectée à ce médecin'}),
            headers: {'content-type': 'application/json'});
      }
      final rows = await db.query('''SELECT id, sender_id, recipient_id,
          message_text, is_read, created_at
          FROM messages
          WHERE (sender_id = @du AND recipient_id = @pid)
             OR (sender_id = @pid AND recipient_id = @du)
          ORDER BY created_at ASC''', substitutionValues: {'du': docUid, 'pid': pid});
      final messages = rows.map((r) {
        final m = jsonSafe(r.toColumnMap()) as Map<String, dynamic>;
        m['is_from_me'] = '${m['sender_id']}' == '$docUid';
        return m;
      }).toList();
      return Response.ok(jsonEncode({
        'patient': jsonSafe(patient.first.toColumnMap()),
        'messages': messages,
      }), headers: {'content-type': 'application/json'});
    } finally {
      await db.close();
    }
  })
  ..post('/messages', (Request req) async {
    final user = _extractUser(req);
    if (user == null || user['role'] != 'medecin') {
      return Response.forbidden(jsonEncode({'message': 'Unauthorized'}),
          headers: {'content-type': 'application/json'});
    }
    final docUid = int.tryParse('${user['id']}');
    if (docUid == null) {
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
    final pid = int.tryParse('${decoded['patientUserId']}');
    final text = (decoded['message'] as String?)?.trim();
    if (pid == null || text == null || text.isEmpty) {
      return Response(400,
          body: jsonEncode({'error': 'Patient et message requis'}),
          headers: {'content-type': 'application/json'});
    }
    final db = Database();
    await db.connect();
    try {
      final docRes = await db.query(
          'SELECT id FROM doctors WHERE user_id = @uid',
          substitutionValues: {'uid': docUid});
      if (docRes.isEmpty) {
        return Response.notFound(jsonEncode({'message': 'Doctor not found'}),
            headers: {'content-type': 'application/json'});
      }
      final docId = docRes.first[0];
      final patient = await db.query('''SELECT id FROM patients
          WHERE user_id = @pid AND assigned_doctor_id = @docId''',
          substitutionValues: {'pid': pid, 'docId': docId});
      if (patient.isEmpty) {
        return Response.notFound(
            jsonEncode({'message': 'Patiente non affectée à ce médecin'}),
            headers: {'content-type': 'application/json'});
      }
      final inserted = await db.query('''INSERT INTO messages
          (sender_id, recipient_id, message_text)
          VALUES (@s, @r, @t) RETURNING id, sender_id, recipient_id,
          message_text, is_read, created_at''', substitutionValues: {
        's': docUid,
        'r': pid,
        't': text,
      });
      final message = jsonSafe(inserted.first.toColumnMap())
          as Map<String, dynamic>;
      message['is_from_me'] = true;
      return Response(201,
          body: jsonEncode({'message': message}),
          headers: {'content-type': 'application/json'});
    } finally {
      await db.close();
    }
  })
  ..post('/messages/<patientUserId>/read', (Request req, String patientUserId) async {
    final user = _extractUser(req);
    if (user == null || user['role'] != 'medecin') {
      return Response.forbidden(jsonEncode({'message': 'Unauthorized'}),
          headers: {'content-type': 'application/json'});
    }
    final docUid = int.parse(user['id'].toString());
    final pid = int.tryParse(patientUserId);
    if (pid == null) {
      return Response(400,
          body: jsonEncode({'error': 'Identifiant invalide'}),
          headers: {'content-type': 'application/json'});
    }
    final db = Database();
    await db.connect();
    try {
      await db.query('''UPDATE messages SET is_read = TRUE, read_at = NOW()
          WHERE sender_id = @pid AND recipient_id = @du AND is_read = FALSE''',
          substitutionValues: {'pid': pid, 'du': docUid});
      return Response.ok(jsonEncode({'status': 'ok'}),
          headers: {'content-type': 'application/json'});
    } finally {
      await db.close();
    }
  })
  ..get('/appointments/requests', (Request req) async {
    final user = _extractUser(req);
    if (user == null || user['role'] != 'medecin') {
      return Response.forbidden(jsonEncode({'message': 'Unauthorized'}),
          headers: {'content-type': 'application/json'});
    }
    final docUid = int.parse('${user['id']}');
    final db = Database();
    await db.connect();
    try {
      final docRes = await db.query(
          'SELECT id FROM doctors WHERE user_id = @uid',
          substitutionValues: {'uid': docUid});
      if (docRes.isEmpty) {
        return Response.notFound(jsonEncode({'message': 'Doctor not found'}),
            headers: {'content-type': 'application/json'});
      }
      final docId = docRes.first[0];
      final rows = await db.query('''SELECT a.id, a.appointment_date,
          a.duration_minutes, a.status, a.notes, a.created_at,
          u.id AS patient_user_id, u.first_name, u.last_name,
          u.phone AS patient_phone, p.id AS patient_id, p.pregnancy_weeks
          FROM appointments a
          JOIN patients p ON p.id = a.patient_id
          JOIN users u ON u.id = p.user_id
          WHERE a.doctor_id = @d
          ORDER BY a.appointment_date DESC''', substitutionValues: {'d': docId});
      return Response.ok(jsonEncode(
          rows.map((r) => jsonSafe(r.toColumnMap())).toList()),
          headers: {'content-type': 'application/json'});
    } finally {
      await db.close();
    }
  })
  ..patch('/appointments/<id>/accept', (Request req, String id) async {
    final user = _extractUser(req);
    if (user == null || user['role'] != 'medecin') {
      return Response.forbidden(jsonEncode({'message': 'Unauthorized'}),
          headers: {'content-type': 'application/json'});
    }
    final docUid = int.parse('${user['id']}');
    final aptId = int.tryParse(id);
    if (aptId == null) {
      return Response(400,
          body: jsonEncode({'error': 'Identifiant invalide'}),
          headers: {'content-type': 'application/json'});
    }
    final db = Database();
    await db.connect();
    try {
      final docRes = await db.query(
          'SELECT id FROM doctors WHERE user_id = @uid',
          substitutionValues: {'uid': docUid});
      if (docRes.isEmpty) {
        return Response.notFound(jsonEncode({'message': 'Doctor not found'}),
            headers: {'content-type': 'application/json'});
      }
      final changed = await db.query('''UPDATE appointments
          SET status = 'confirmed', updated_at = NOW()
          WHERE id = @id AND doctor_id = @d
          RETURNING id, appointment_date, status''',
          substitutionValues: {'id': aptId, 'd': docRes.first[0]});
      if (changed.isEmpty) {
        return Response(404,
            body: jsonEncode({'error': 'Rendez-vous introuvable'}),
            headers: {'content-type': 'application/json'});
      }
      final info = await db.query('''SELECT p.user_id AS patient_user_id,
          pu.first_name, pu.last_name
          FROM appointments a
          JOIN patients p ON p.id = a.patient_id
          JOIN users pu ON pu.id = p.user_id
          WHERE a.id = @id''', substitutionValues: {'id': aptId});
      final c = info.first.toColumnMap();
      final patientName =
          '${c['first_name']} ${c['last_name']}'.trim();
      await db.query('''INSERT INTO notifications
          (user_id, title, message, notification_type, data, is_sent, sent_at)
          VALUES (@u, @t, @m, 'appointment', @data, TRUE, NOW())''',
          substitutionValues: {
        'u': c['patient_user_id'],
        't': 'Rendez-vous confirmé',
        'm': 'Votre médecin a confirmé votre rendez-vous du '
            '${formatAppointmentFr(changed.first[1])}.',
        'data': jsonEncode({'appointment_id': aptId, 'status': 'confirmed'}),
      });
      return Response.ok(jsonEncode({
        'id': aptId,
        'status': 'confirmed',
        'patient_name': patientName,
      }), headers: {'content-type': 'application/json'});
    } finally {
      await db.close();
    }
  })
  ..patch('/appointments/<id>/reject', (Request req, String id) async {
    final user = _extractUser(req);
    if (user == null || user['role'] != 'medecin') {
      return Response.forbidden(jsonEncode({'message': 'Unauthorized'}),
          headers: {'content-type': 'application/json'});
    }
    final docUid = int.parse('${user['id']}');
    final aptId = int.tryParse(id);
    if (aptId == null) {
      return Response(400,
          body: jsonEncode({'error': 'Identifiant invalide'}),
          headers: {'content-type': 'application/json'});
    }
    String? reason;
    final raw = await req.readAsString();
    if (raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          reason = (decoded['message'] as String?)?.trim();
        }
      } on FormatException {
        // Corps malformé : on le traite comme aucun motif.
      }
    }
    final db = Database();
    await db.connect();
    try {
      final docRes = await db.query(
          'SELECT id FROM doctors WHERE user_id = @uid',
          substitutionValues: {'uid': docUid});
      if (docRes.isEmpty) {
        return Response.notFound(jsonEncode({'message': 'Doctor not found'}),
            headers: {'content-type': 'application/json'});
      }
      final changed = await db.query('''UPDATE appointments
          SET status = 'rejected', notes = COALESCE(@reason, notes),
              updated_at = NOW()
          WHERE id = @id AND doctor_id = @d
          RETURNING id, appointment_date, status''',
          substitutionValues: {
        'id': aptId,
        'd': docRes.first[0],
        'reason': reason,
      });
      if (changed.isEmpty) {
        return Response(404,
            body: jsonEncode({'error': 'Rendez-vous introuvable'}),
            headers: {'content-type': 'application/json'});
      }
      final info = await db.query('''SELECT p.user_id AS patient_user_id
          FROM appointments a JOIN patients p ON p.id = a.patient_id
          WHERE a.id = @id''', substitutionValues: {'id': aptId});
      final c = info.first.toColumnMap();
      final suffix =
          reason == null || reason.isEmpty ? '.' : ' Motif : $reason';
      await db.query('''INSERT INTO notifications
          (user_id, title, message, notification_type, data, is_sent, sent_at)
          VALUES (@u, @t, @m, 'appointment', @data, TRUE, NOW())''',
          substitutionValues: {
        'u': c['patient_user_id'],
        't': 'Rendez-vous refusé',
        'm': 'Votre médecin a refusé la demande de rendez-vous du '
            '${formatAppointmentFr(changed.first[1])}$suffix',
        'data': jsonEncode({'appointment_id': aptId, 'status': 'rejected'}),
      });
      return Response.ok(jsonEncode({'id': aptId, 'status': 'rejected'}),
          headers: {'content-type': 'application/json'});
    } finally {
      await db.close();
    }
  })
  ..patch('/appointments/<id>/reschedule', (Request req, String id) async {
    final user = _extractUser(req);
    if (user == null || user['role'] != 'medecin') {
      return Response.forbidden(jsonEncode({'message': 'Unauthorized'}),
          headers: {'content-type': 'application/json'});
    }
    final docUid = int.parse('${user['id']}');
    final aptId = int.tryParse(id);
    if (aptId == null) {
      return Response(400,
          body: jsonEncode({'error': 'Identifiant invalide'}),
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
    final newDate = DateTime.tryParse('${decoded['newDate']}');
    if (newDate == null) {
      return Response(400,
          body: jsonEncode({'error': 'Date invalide'}),
          headers: {'content-type': 'application/json'});
    }
    if (newDate.isBefore(DateTime.now().add(const Duration(minutes: 15)))) {
      return Response(400,
          body: jsonEncode({'error': 'La nouvelle date doit être dans le futur'}),
          headers: {'content-type': 'application/json'});
    }
    final message = (decoded['message'] as String?)?.trim();
    final db = Database();
    await db.connect();
    try {
      final docRes = await db.query(
          'SELECT id FROM doctors WHERE user_id = @uid',
          substitutionValues: {'uid': docUid});
      if (docRes.isEmpty) {
        return Response.notFound(jsonEncode({'message': 'Doctor not found'}),
            headers: {'content-type': 'application/json'});
      }
      final info = await db.query('''SELECT a.appointment_date AS old_date,
          p.user_id AS patient_user_id
          FROM appointments a JOIN patients p ON p.id = a.patient_id
          WHERE a.id = @id''', substitutionValues: {'id': aptId});
      if (info.isEmpty) {
        return Response(404,
            body: jsonEncode({'error': 'Rendez-vous introuvable'}),
            headers: {'content-type': 'application/json'});
      }
      final c = info.first.toColumnMap();
      final changed = await db.query('''UPDATE appointments
          SET status = 'rescheduled', appointment_date = @nd,
              notes = COALESCE(@reason, notes), updated_at = NOW()
          WHERE id = @id AND doctor_id = @d
          RETURNING id, appointment_date, status, notes''',
          substitutionValues: {
        'id': aptId,
        'd': docRes.first[0],
        'nd': newDate.toUtc(),
        'reason': message,
      });
      if (changed.isEmpty) {
        return Response(404,
            body: jsonEncode({'error': 'Rendez-vous introuvable'}),
            headers: {'content-type': 'application/json'});
      }
      final suffix =
          message == null || message.isEmpty ? '' : ' $message';
      await db.query('''INSERT INTO notifications
          (user_id, title, message, notification_type, data, is_sent, sent_at)
          VALUES (@u, @t, @m, 'appointment', @data, TRUE, NOW())''',
          substitutionValues: {
        'u': c['patient_user_id'],
        't': 'Nouvelle date de RDV proposée',
        'm': 'Le médecin est indisponible à la date demandée et vous propose '
            'le ${formatAppointmentFr(newDate)} au lieu de '
            '${formatAppointmentFr(c['old_date'])}.$suffix',
        'data': jsonEncode({'appointment_id': aptId, 'status': 'rescheduled'}),
      });
      return Response.ok(jsonEncode({
        'id': aptId,
        'status': 'rescheduled',
        'appointment_date': '${changed.first[1]}',
      }), headers: {'content-type': 'application/json'});
    } finally {
      await db.close();
    }
  });

final router = _doctorRouter;
