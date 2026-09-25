import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:backend/config/database.dart';
import 'package:backend/utils/jwt.dart';
import 'package:backend/utils/json_safe.dart';
import 'package:backend/utils/mistral.dart';
import 'package:backend/utils/dates_fr.dart';

Map<String, dynamic>? _extractUser(Request req) {
  final auth = req.headers['authorization'];
  if (auth == null || !auth.startsWith('Bearer ')) return null;
  final token = auth.substring(7);
  final jwt = JwtService();
  final payload = jwt.verify(token);
  if (payload == null || payload['status'] != 'active') return null;
  return payload;
}

// Use cascade for top-level router method registration
final _patientRouter = Router()
  ..get('/profile', (Request req) async {
    final user = _extractUser(req);
    if (user == null || user['role'] != 'patiente') return Response.forbidden('{"message":"Unauthorized"}', headers: {'content-type': 'application/json'});
    final uid = user['id']?.toString();

    final db = Database();
    await db.connect();
    final res = await db.query('SELECT p.*, u.email, u.first_name, u.last_name, u.phone FROM patients p JOIN users u ON p.user_id = u.id WHERE p.user_id = @id', substitutionValues: {'id': int.parse(uid!)});
    await db.close();
    if (res.isEmpty) return Response.notFound(jsonEncode({'message': 'Patient profile not found'}), headers: {'content-type': 'application/json'});
    return Response.ok(jsonEncode(jsonSafe(res.first.toColumnMap())), headers: {'content-type': 'application/json'});
  })
  ..patch('/profile', (Request req) async {
    final user = _extractUser(req);
    if (user == null || user['role'] != 'patiente') {
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
    final pregnancyWeeks = body['pregnancyWeeks'];
    final bloodType = (body['bloodType'] as String?)?.trim();
    final medicalConditions = (body['medicalConditions'] as String?)?.trim();
    final allergies = (body['allergies'] as String?)?.trim();
    final emergencyContactName =
        (body['emergencyContactName'] as String?)?.trim();
    final emergencyContactPhone =
        (body['emergencyContactPhone'] as String?)?.trim();

    final db = Database();
    await db.connect();
    try {
      final info = await db.query('''
        SELECT u.first_name, u.last_name, u.phone, u.email,
               p.pregnancy_weeks, p.blood_type, p.medical_conditions,
               p.allergies, p.emergency_contact_name, p.emergency_contact_phone
        FROM users u
        JOIN patients p ON p.user_id = u.id
        WHERE u.id = @uid
      ''', substitutionValues: {'uid': uid});
      if (info.isEmpty) {
        return Response.notFound(jsonEncode({'message': 'Patient not found'}),
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
      final newPregnancyWeeks = pregnancyWeeks == null ||
              '$pregnancyWeeks'.isEmpty
          ? cur['pregnancy_weeks']
          : int.tryParse('$pregnancyWeeks');
      final newBloodType =
          bloodType == null || bloodType.isEmpty ? cur['blood_type'] : bloodType;
      final newMedicalConditions = medicalConditions == null ||
              medicalConditions.isEmpty
          ? cur['medical_conditions']
          : medicalConditions;
      final newAllergies =
          allergies == null || allergies.isEmpty ? cur['allergies'] : allergies;
      final newEmergencyContactName = emergencyContactName == null ||
              emergencyContactName.isEmpty
          ? cur['emergency_contact_name']
          : emergencyContactName;
      final newEmergencyContactPhone = emergencyContactPhone == null ||
              emergencyContactPhone.isEmpty
          ? cur['emergency_contact_phone']
          : emergencyContactPhone;

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
          UPDATE patients
          SET pregnancy_weeks = @pw, blood_type = @bt,
              medical_conditions = @mc, allergies = @al,
              emergency_contact_name = @ecn, emergency_contact_phone = @ecp
          WHERE user_id = @uid
        ''', substitutionValues: {
          'pw': newPregnancyWeeks,
          'bt': newBloodType,
          'mc': newMedicalConditions,
          'al': newAllergies,
          'ecn': newEmergencyContactName,
          'ecp': newEmergencyContactPhone,
          'uid': uid,
        });
      });

      final updated = await db.query('''
        SELECT p.*, u.email, u.first_name, u.last_name, u.phone, u.status
        FROM patients p
        JOIN users u ON p.user_id = u.id
        WHERE p.user_id = @uid
      ''', substitutionValues: {'uid': uid});
      return Response.ok(jsonEncode(jsonSafe(updated.first.toColumnMap())),
          headers: {'content-type': 'application/json'});
    } finally {
      await db.close();
    }
  })
  ..get('/telemetry', (Request req) async {
    final user = _extractUser(req);
    if (user == null || user['role'] != 'patiente') return Response.forbidden(jsonEncode({'message': 'Unauthorized'}), headers: {'content-type': 'application/json'});
    final db = Database();
    await db.connect();
    try {
      final rows = await db.query('''SELECT t.* FROM telemetry t JOIN patients p ON p.id = t.patient_id WHERE p.user_id = @uid ORDER BY t.recorded_at DESC''', substitutionValues: {'uid': int.parse(user['id'].toString())});
      return Response.ok(jsonEncode(rows.map((row) => jsonSafe(row.toColumnMap())).toList()), headers: {'content-type': 'application/json'});
    } finally {
      await db.close();
    }
  })
  ..get('/appointments', (Request req) async {
    final user = _extractUser(req);
    if (user == null || user['role'] != 'patiente') return Response.forbidden(jsonEncode({'message': 'Unauthorized'}), headers: {'content-type': 'application/json'});
    final db = Database();
    await db.connect();
    try {
      final rows = await db.query('''SELECT a.*, du.first_name AS doctor_first_name, du.last_name AS doctor_last_name FROM appointments a JOIN patients p ON p.id = a.patient_id JOIN doctors d ON d.id = a.doctor_id JOIN users du ON du.id = d.user_id WHERE p.user_id = @uid ORDER BY a.appointment_date''', substitutionValues: {'uid': int.parse(user['id'].toString())});
      return Response.ok(jsonEncode(rows.map((row) => jsonSafe(row.toColumnMap())).toList()), headers: {'content-type': 'application/json'});
    } finally {
      await db.close();
    }
  })
  ..post('/telemetry', (Request req) async {
    final user = _extractUser(req);
    final uid = user?['id']?.toString();
    if (user == null || user['role'] != 'patiente') return Response.forbidden(jsonEncode({'message': 'Unauthorized'}), headers: {'content-type': 'application/json'});
    if (uid == null) return Response.forbidden(jsonEncode({'message': 'Unauthorized'}), headers: {'content-type': 'application/json'});
    final Object? decodedBody;
    try {
      decodedBody = jsonDecode(await req.readAsString());
    } on FormatException {
      return Response(400,
          body: jsonEncode({'error': 'JSON invalide'}),
          headers: {'content-type': 'application/json'});
    }
    if (decodedBody is! Map<String, dynamic>) {
      return Response(400,
          body: jsonEncode({'error': 'JSON invalide'}),
          headers: {'content-type': 'application/json'});
    }
    final body = decodedBody;

    final validationError = _validateTelemetry(body);
    if (validationError != null) {
      return Response(400,
          body: jsonEncode({'error': validationError}),
          headers: {'content-type': 'application/json'});
    }

    final db = Database();
    await db.connect();
    try {
      final patientRes = await db.query(
        'SELECT p.id, p.assigned_doctor_id, p.pregnancy_weeks, p.blood_type, '
        'p.medical_conditions, p.allergies, '
        'pu.first_name AS patient_first_name, pu.last_name AS patient_last_name, pu.phone AS patient_phone, '
        'du.id AS doctor_user_id, d.id AS doctor_id '
        'FROM patients p '
        'JOIN users pu ON pu.id = p.user_id '
        'LEFT JOIN doctors d ON d.id = p.assigned_doctor_id '
        'LEFT JOIN users du ON du.id = d.user_id '
        'WHERE p.user_id = @uid',
        substitutionValues: {'uid': int.parse(uid)},
      );
      if (patientRes.isEmpty) {
        return Response.notFound(jsonEncode({'message': 'Patient not found'}), headers: {'content-type': 'application/json'});
      }
      final patientRow = patientRes.first.toColumnMap();
      final patientId = patientRow['id'];

      final q = '''INSERT INTO telemetry (patient_id, weight, blood_pressure_systolic, blood_pressure_diastolic, heart_rate, blood_glucose, temperature, notes) VALUES (@p, @w, @s, @d, @h, @g, @t, @n) RETURNING *''';
      final inserted = await db.query(q, substitutionValues: {
        'p': patientId,
        'w': body['weight'],
        's': body['bloodPressureSystolic'],
        'd': body['bloodPressureDiastolic'],
        'h': body['heartRate'],
        'g': body['bloodGlucose'],
        't': body['temperature'],
        'n': body['notes']
      });
      final telemetryRow = jsonSafe(inserted.first.toColumnMap()) as Map<String, dynamic>;

      final doctorId = patientRow['assigned_doctor_id'];
      final profile = {
        'pregnancy_weeks': patientRow['pregnancy_weeks'],
        'blood_type': patientRow['blood_type'],
        'medical_conditions': patientRow['medical_conditions'],
        'allergies': patientRow['allergies'],
      };
      final analysis = await analyzeTelemetry(profile, telemetryRow);

      if (analysis != null && doctorId != null) {
        final severity = '${analysis['severity'] ?? 'normal'}';
        final isAlertWorthy = severity != 'normal' ||
            analysis['risk_of_malaise'] == true;
        if (isAlertWorthy) {
          final patientName = [
            patientRow['patient_first_name'],
            patientRow['patient_last_name'],
          ]
              .whereType<String>()
              .where((v) => v.isNotEmpty)
              .join(' ');
          final patientPhone =
              '${patientRow['patient_phone'] ?? ''}' == ''
                  ? 'Non renseigné'
                  : '${patientRow['patient_phone']}';

          // Anti-spam : pas de nouvelle alerte identique dans les 10 dernières
          // minutes pour la même patiente (évite le flood de notifications).
          final recent = await db.query(
            '''SELECT 1 FROM alerts
               WHERE patient_id = @p AND severity = @s
                 AND alert_type = 'ia_assessment'
                 AND created_at > NOW() - INTERVAL '10 minutes' LIMIT 1''',
            substitutionValues: {'p': patientId, 's': severity},
          );
          if (recent.isEmpty) {
            final details = jsonEncode({
              ...analysis,
              'patient_name': patientName,
              'patient_phone': patientPhone,
              'telemetry': telemetryRow,
              'pregnancy_weeks': patientRow['pregnancy_weeks'],
            });
            await db.query(
              '''INSERT INTO alerts (doctor_id, patient_id, alert_type, severity, message, details)
                 VALUES (@d, @p, 'ia_assessment', @s, @m, @det)''',
              substitutionValues: {
                'd': doctorId,
                'p': patientId,
                's': severity,
                'm': analysis['summary'],
                'det': details,
              },
            );
            final doctorUserId = patientRow['doctor_user_id'];
            if (doctorUserId != null) {
              await db.query(
                '''INSERT INTO notifications (user_id, title, message, notification_type, data)
                   VALUES (@u, @t, @m, 'alert', @data)''',
                substitutionValues: {
                  'u': doctorUserId,
                  't': 'Alerte IA — $patientName',
                  'm':
                      '${analysis['summary']}\n📞 Patient : $patientName — $patientPhone',
                  'data': details,
                },
              );
            }
          }
        }
      }

      return Response(201,
          body: jsonEncode({
            'telemetry': telemetryRow,
            if (analysis != null) 'ia': analysis,
          }),
          headers: {'content-type': 'application/json'});
    } finally {
      await db.close();
    }
  })
  ..get('/health-state', (Request req) async {
    final user = _extractUser(req);
    if (user == null || user['role'] != 'patiente') {
      return Response.forbidden(jsonEncode({'message': 'Unauthorized'}),
          headers: {'content-type': 'application/json'});
    }
    final db = Database();
    await db.connect();
    try {
      final uid = int.parse(user['id'].toString());
      final rows = await db.query(
        '''SELECT a.severity, a.message, a.details, a.created_at
           FROM alerts a JOIN patients p ON p.id = a.patient_id
           WHERE p.user_id = @u AND a.alert_type = 'ia_assessment'
           ORDER BY a.created_at DESC LIMIT 1''',
        substitutionValues: {'u': uid},
      );
      if (rows.isEmpty) {
        return Response.ok(
            jsonEncode({
              'status': 'aucune',
              'message':
                  'Votre médecin n\'a pas encore reçu d\'analyse. Enregistrez vos mesures pour obtenir un premier bilan.',
            }),
            headers: {'content-type': 'application/json'});
      }
      final row = jsonSafe(rows.first.toColumnMap()) as Map<String, dynamic>;
      final details = row['details'];
      Map<String, dynamic> parsed = {};
      if (details is Map<String, dynamic>) {
        parsed = details;
      } else if (details is String && details.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(details);
          if (decoded is Map) parsed = Map<String, dynamic>.from(decoded);
        } on FormatException {
          // détails non JSON : on ignore
        }
      }
      final status = '${parsed['status'] ?? row['severity'] ?? 'bonne'}';
      final recs = (parsed['recommendations'] as List? ?? [])
          .map((e) => '$e'.trim())
          .where((e) => e.isNotEmpty)
          .take(3)
          .toList();
      return Response.ok(
          jsonEncode({
            'status': status,
            'severity': parsed['severity'] ?? row['severity'],
            'summary': row['message'] ?? parsed['summary'] ?? '',
            'patient_message':
                parsed['patient_message'] ?? parsed['summary'] ?? '',
            'recommendations': recs.isEmpty
                ? recommendationsFor(status,
                    riskOfMalaise: parsed['risk_of_malaise'] == true)
                : recs,
            'telemetry': parsed['telemetry'],
            'patient_name': parsed['patient_name'],
            'analyzed_at': row['created_at'],
          }),
          headers: {'content-type': 'application/json'});
    } finally {
      await db.close();
    }
  })
  ..get('/messages', (Request req) async {
    final user = _extractUser(req);
    if (user == null || user['role'] != 'patiente') {
      return Response.forbidden(jsonEncode({'message': 'Unauthorized'}),
          headers: {'content-type': 'application/json'});
    }
    final uid = int.parse(user['id'].toString());
    final db = Database();
    await db.connect();
    try {
      final doc = await db.query('''SELECT du.id AS user_id, du.first_name, du.last_name,
          d.specialization
          FROM patients p
          LEFT JOIN doctors d ON d.id = p.assigned_doctor_id
          LEFT JOIN users du ON du.id = d.user_id
          WHERE p.user_id = @u''', substitutionValues: {'u': uid});
      if (doc.isEmpty) {
        return Response.notFound(jsonEncode({'message': 'Patient not found'}),
            headers: {'content-type': 'application/json'});
      }
      final doctorRow = doc.first.toColumnMap();
      final doctorUserId = doctorRow['user_id'];
      Map<String, dynamic>? doctor;
      final messages = <Map<String, dynamic>>[];
      if (doctorUserId != null) {
        doctor = {
          'id': doctorUserId,
          'first_name': doctorRow['first_name'],
          'last_name': doctorRow['last_name'],
          'specialization': doctorRow['specialization'],
        };
        final rows = await db.query('''SELECT id, sender_id, recipient_id,
            message_text, is_read, created_at
            FROM messages
            WHERE (sender_id = @u AND recipient_id = @du)
               OR (sender_id = @du AND recipient_id = @u)
            ORDER BY created_at ASC''', substitutionValues: {'u': uid, 'du': doctorUserId});
        for (final row in rows) {
          final m = jsonSafe(row.toColumnMap()) as Map<String, dynamic>;
          m['is_from_me'] = '${m['sender_id']}' == '$uid';
          messages.add(m);
        }
      }
      return Response.ok(jsonEncode({'doctor': doctor, 'messages': messages}),
          headers: {'content-type': 'application/json'});
    } finally {
      await db.close();
    }
  })
  ..get('/messages/unread-count', (Request req) async {
    final user = _extractUser(req);
    if (user == null || user['role'] != 'patiente') {
      return Response.forbidden(jsonEncode({'message': 'Unauthorized'}),
          headers: {'content-type': 'application/json'});
    }
    final uid = int.parse(user['id'].toString());
    final db = Database();
    await db.connect();
    try {
      final rows = await db.query(
          'SELECT COUNT(*) AS c FROM messages '
          'WHERE recipient_id = @u AND is_read = false',
          substitutionValues: {'u': uid});
      return Response.ok(jsonEncode({'count': rows.first[0]}),
          headers: {'content-type': 'application/json'});
    } finally {
      await db.close();
    }
  })
  ..post('/messages/read', (Request req) async {
    final user = _extractUser(req);
    if (user == null || user['role'] != 'patiente') {
      return Response.forbidden(jsonEncode({'message': 'Unauthorized'}),
          headers: {'content-type': 'application/json'});
    }
    final uid = int.parse(user['id'].toString());
    final db = Database();
    await db.connect();
    try {
      await db.query('''UPDATE messages SET is_read = true, read_at = NOW()
          WHERE recipient_id = @u AND is_read = false''',
          substitutionValues: {'u': uid});
      return Response.ok(jsonEncode({'status': 'ok'}),
          headers: {'content-type': 'application/json'});
    } finally {
      await db.close();
    }
  })
  ..post('/messages', (Request req) async {
    final user = _extractUser(req);
    if (user == null || user['role'] != 'patiente') {
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
    final text = (decoded['message'] as String?)?.trim();
    if (text == null || text.isEmpty) {
      return Response(400,
          body: jsonEncode({'error': 'Le message est vide'}),
          headers: {'content-type': 'application/json'});
    }
    final db = Database();
    await db.connect();
    try {
      final doc = await db.query('''SELECT du.id AS user_id FROM patients p
          JOIN doctors d ON d.id = p.assigned_doctor_id
          JOIN users du ON du.id = d.user_id
          WHERE p.user_id = @u''', substitutionValues: {'u': uid});
      if (doc.isEmpty) {
        return Response(409,
            body: jsonEncode(
                {'error': 'Aucun médecin n\'est encore affecté à votre profil'}),
            headers: {'content-type': 'application/json'});
      }
      final doctorUserId = doc.first[0];
      final inserted = await db.query('''INSERT INTO messages
          (sender_id, recipient_id, message_text)
          VALUES (@s, @r, @t) RETURNING id, sender_id, recipient_id,
          message_text, is_read, created_at''', substitutionValues: {
        's': uid,
        'r': doctorUserId,
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
  ..get('/reminders', (Request req) async {
    final user = _extractUser(req);
    if (user == null || user['role'] != 'patiente') {
      return Response.forbidden(jsonEncode({'message': 'Unauthorized'}),
          headers: {'content-type': 'application/json'});
    }
    final uid = int.parse(user['id'].toString());
    final db = Database();
    await db.connect();
    try {
      final rows = await db.query('''SELECT r.* FROM patient_reminders r
          JOIN patients p ON p.id = r.patient_id
          WHERE p.user_id = @u ORDER BY r.reminder_date''',
          substitutionValues: {'u': uid});
      return Response.ok(jsonEncode(
          rows.map((r) => jsonSafe(r.toColumnMap())).toList()),
          headers: {'content-type': 'application/json'});
    } finally {
      await db.close();
    }
  })
  ..post('/reminders', (Request req) async {
    final user = _extractUser(req);
    if (user == null || user['role'] != 'patiente') {
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
    final title = (decoded['title'] as String?)?.trim();
    final dateString = decoded['reminderDate'] as String?;
    if (title == null || title.isEmpty || dateString == null) {
      return Response(400,
          body: jsonEncode({'error': 'Titre et date du rappel requis'}),
          headers: {'content-type': 'application/json'});
    }
    final parsedDate = DateTime.tryParse(dateString);
    if (parsedDate == null) {
      return Response(400,
          body: jsonEncode({'error': 'Date invalide'}),
          headers: {'content-type': 'application/json'});
    }
    final db = Database();
    await db.connect();
    try {
      final patient = await db.query(
          'SELECT id FROM patients WHERE user_id = @u',
          substitutionValues: {'u': uid});
      if (patient.isEmpty) {
        return Response.notFound(
            jsonEncode({'message': 'Patient not found'}),
            headers: {'content-type': 'application/json'});
      }
      final inserted = await db.query('''INSERT INTO patient_reminders
          (patient_id, title, reminder_date)
          VALUES (@p, @t, @d) RETURNING *''', substitutionValues: {
        'p': patient.first[0],
        't': title,
        'd': parsedDate.toUtc(),
      });
      return Response(201,
          body: jsonEncode(jsonSafe(inserted.first.toColumnMap())),
          headers: {'content-type': 'application/json'});
    } finally {
      await db.close();
    }
  })
  ..patch('/reminders/<id>', (Request req, String id) async {
    final user = _extractUser(req);
    if (user == null || user['role'] != 'patiente') {
      return Response.forbidden(jsonEncode({'message': 'Unauthorized'}),
          headers: {'content-type': 'application/json'});
    }
    final uid = int.parse(user['id'].toString());
    final reminderId = int.tryParse(id);
    if (reminderId == null) {
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
    final isDone = decoded['isDone'];
    if (isDone is! bool) {
      return Response(400,
          body: jsonEncode({'error': 'isDone doit être un booléen'}),
          headers: {'content-type': 'application/json'});
    }
    final db = Database();
    await db.connect();
    try {
      final updated = await db.query('''UPDATE patient_reminders SET is_done = @d
          WHERE id = @id AND patient_id IN
          (SELECT id FROM patients WHERE user_id = @u)
          RETURNING *''',
          substitutionValues: {'d': isDone, 'id': reminderId, 'u': uid});
      if (updated.isEmpty) {
        return Response.notFound(jsonEncode({'error': 'Rappel introuvable'}),
            headers: {'content-type': 'application/json'});
      }
      return Response.ok(jsonEncode(jsonSafe(updated.first.toColumnMap())),
          headers: {'content-type': 'application/json'});
    } finally {
      await db.close();
    }
  })
  ..delete('/reminders/<id>', (Request req, String id) async {
    final user = _extractUser(req);
    if (user == null || user['role'] != 'patiente') {
      return Response.forbidden(jsonEncode({'message': 'Unauthorized'}),
          headers: {'content-type': 'application/json'});
    }
    final uid = int.parse(user['id'].toString());
    final reminderId = int.tryParse(id);
    if (reminderId == null) {
      return Response(400,
          body: jsonEncode({'error': 'Identifiant invalide'}),
          headers: {'content-type': 'application/json'});
    }
    final db = Database();
    await db.connect();
    try {
      await db.query('''DELETE FROM patient_reminders
          WHERE id = @id AND patient_id IN
          (SELECT id FROM patients WHERE user_id = @u)''',
          substitutionValues: {'id': reminderId, 'u': uid});
      return Response.ok(jsonEncode({'status': 'ok'}),
          headers: {'content-type': 'application/json'});
    } finally {
      await db.close();
    }
  })
  ..post('/appointments', (Request req) async {
    final user = _extractUser(req);
    if (user == null || user['role'] != 'patiente') {
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
    final dateString = decoded['appointmentDate'] as String?;
    if (dateString == null) {
      return Response(400,
          body: jsonEncode({'error': 'Date du rendez-vous requise'}),
          headers: {'content-type': 'application/json'});
    }
    final parsedDate = DateTime.tryParse(dateString);
    if (parsedDate == null) {
      return Response(400,
          body: jsonEncode({'error': 'Date invalide'}),
          headers: {'content-type': 'application/json'});
    }
    final duration = (decoded['durationMinutes'] as num?)?.toInt() ?? 30;
    final notes = (decoded['notes'] as String?)?.trim();
    final db = Database();
    await db.connect();
    try {
      final patient = await db.query('''SELECT p.id, d.id AS doctor_id,
          d.user_id AS doctor_user_id,
          pu.id AS patient_user_id,
          pu.first_name AS patient_first_name,
          pu.last_name AS patient_last_name
          FROM patients p
          JOIN doctors d ON d.id = p.assigned_doctor_id
          JOIN users pu ON pu.id = p.user_id
          WHERE p.user_id = @u''', substitutionValues: {'u': uid});
      if (patient.isEmpty) {
        return Response(409,
            body: jsonEncode(
                {'error': 'Aucun médecin n\'est encore affecté à votre profil'}),
            headers: {'content-type': 'application/json'});
      }
      final row = patient.first.toColumnMap();
      final inserted = await db.query('''INSERT INTO appointments
          (patient_id, doctor_id, appointment_date, duration_minutes, notes, status)
          VALUES (@p, @d, @date, @dur, @n, 'pending') RETURNING *''',
          substitutionValues: {
            'p': row['id'],
            'd': row['doctor_id'],
            'date': parsedDate.toUtc(),
            'dur': duration,
            'n': notes,
          });
      final patientName =
          '${row['patient_first_name']} ${row['patient_last_name']}'.trim();
      final dateLabel = formatAppointmentFr(parsedDate);
      final motif = notes == null || notes.trim().isEmpty
          ? ''
          : ' Motif : ${notes.trim()}';
      await db.query('''INSERT INTO notifications
          (user_id, title, message, notification_type, data, is_sent, sent_at)
          VALUES (@u, @t, @m, 'appointment', @data, TRUE, NOW())''',
          substitutionValues: {
        'u': row['doctor_user_id'],
        't': 'Nouvelle demande de RDV',
        'm': 'Nouvelle demande de rendez-vous de '
            '${patientName.isEmpty ? 'votre patiente' : patientName} '
            'pour le $dateLabel.$motif',
        'data': jsonEncode({
          'appointment_id': inserted.first[0],
          'status': 'pending',
        }),
      });
      return Response(201,
          body: jsonEncode(jsonSafe(inserted.first.toColumnMap())),
          headers: {'content-type': 'application/json'});
    } finally {
      await db.close();
    }
  })
  ..patch('/appointments/<id>/accept', (Request req, String id) async {
    final user = _extractUser(req);
    if (user == null || user['role'] != 'patiente') {
      return Response.forbidden(
          jsonEncode({'message': 'Unauthorized'}),
          headers: {'content-type': 'application/json'});
    }
    final aptId = int.tryParse(id);
    if (aptId == null) {
      return Response(400,
          body: jsonEncode({'error': 'Identifiant invalide'}),
          headers: {'content-type': 'application/json'});
    }
    final db = Database();
    await db.connect();
    try {
      final appt = await db.query('''SELECT a.id, a.status, a.appointment_date,
          d.user_id AS doctor_user_id,
          pu.first_name AS patient_first_name,
          pu.last_name AS patient_last_name
          FROM appointments a
          JOIN patients p ON p.id = a.patient_id
          JOIN doctors d ON d.id = a.doctor_id
          JOIN users pu ON pu.id = p.user_id
          WHERE a.id = @id AND p.user_id = @u''',
          substitutionValues: {
        'id': aptId,
        'u': int.parse('${user['id']}'),
      });
      if (appt.isEmpty) {
        return Response(404,
            body: jsonEncode({'error': 'Rendez-vous introuvable'}),
            headers: {'content-type': 'application/json'});
      }
      final row = appt.first.toColumnMap();
      if ('${row['status']}' != 'rescheduled') {
        return Response(409,
            body: jsonEncode(
                {'error': 'Aucune nouvelle proposition à accepter'}),
            headers: {'content-type': 'application/json'});
      }
      await db.query('''UPDATE appointments
          SET status = 'confirmed', updated_at = NOW()
          WHERE id = @id''', substitutionValues: {'id': aptId});
      final patientName =
          '${row['patient_first_name']} ${row['patient_last_name']}'.trim();
      await db.query('''INSERT INTO notifications
          (user_id, title, message, notification_type, data, is_sent, sent_at)
          VALUES (@u, @t, @m, 'appointment', @data, TRUE, NOW())''',
          substitutionValues: {
        'u': row['doctor_user_id'],
        't': 'RDV confirmé',
        'm': '${patientName.isEmpty ? 'La patiente' : patientName} a accepté '
            'le rendez-vous du '
            '${formatAppointmentFr(row['appointment_date'])}.',
        'data': jsonEncode({'appointment_id': aptId, 'status': 'confirmed'}),
      });
      final updated = await db.query(
          'SELECT * FROM appointments WHERE id = @id',
          substitutionValues: {'id': aptId});
      return Response.ok(
          jsonEncode(jsonSafe(updated.first.toColumnMap())),
          headers: {'content-type': 'application/json'});
    } finally {
      await db.close();
    }
  });

/// Validation stricte côté serveur des constantes saisies : protège la base
/// contre les valeurs absurdes ou les requêtes modifiées (sécurité).
/// Retourne un message d'erreur en français, ou `null` si valide.
String? _validateTelemetry(Map<String, dynamic> body) {
  double? numOf(String key) {
    final v = body[key];
    if (v == null) return null;
    return num.tryParse('$v')?.toDouble();
  }

  final weight = numOf('weight');
  final systolic = numOf('bloodPressureSystolic');
  final diastolic = numOf('bloodPressureDiastolic');
  final heartRate = numOf('heartRate');
  final temperature = numOf('temperature');
  final glucose = numOf('bloodGlucose');

  if (weight == null || systolic == null || diastolic == null ||
      temperature == null || glucose == null) {
    return 'Constantes incomplètes : poids, tension, température et glycémie sont requis.';
  }
  if (weight < 25 || weight > 300) return 'Poids invalide (25 à 300 kg).';
  if (systolic < 40 || systolic > 260) {
    return 'Tension systolique invalide (40 à 260 mmHg).';
  }
  if (diastolic < 20 || diastolic > 160) {
    return 'Tension diastolique invalide (20 à 160 mmHg).';
  }
  if (systolic <= diastolic) {
    return 'La tension systolique doit être supérieure à la diastolique.';
  }
  if (heartRate != null && (heartRate < 30 || heartRate > 220)) {
    return 'Fréquence cardiaque invalide (30 à 220 bpm).';
  }
  if (temperature < 30 || temperature > 45) {
    return 'Température invalide (30 à 45 °C).';
  }
  if (glucose < 0.3 || glucose > 60) return 'Glycémie invalide.';

  final notes = body['notes'];
  if (notes is String && notes.trim().length > 500) {
    return 'Le commentaire ne doit pas dépasser 500 caractères.';
  }
  return null;
}

// Export named router
final router = _patientRouter;
