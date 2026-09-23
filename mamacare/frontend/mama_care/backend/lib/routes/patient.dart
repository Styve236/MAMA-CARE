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
