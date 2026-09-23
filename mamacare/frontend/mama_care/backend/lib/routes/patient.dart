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
    final body = jsonDecode(await req.readAsString());

    final db = Database();
    await db.connect();
    final patientRes = await db.query('SELECT id FROM patients WHERE user_id = @uid', substitutionValues: {'uid': int.parse(uid)});
    if (patientRes.isEmpty) {
      await db.close();
      return Response.notFound(jsonEncode({'message': 'Patient not found'}), headers: {'content-type': 'application/json'});
    }
    final patientId = patientRes.first[0];
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
    await db.close();
    return Response(201, body: jsonEncode({'telemetry': jsonSafe(inserted.first.toColumnMap())}), headers: {'content-type': 'application/json'});
  });

// Export named router
final router = _patientRouter;
