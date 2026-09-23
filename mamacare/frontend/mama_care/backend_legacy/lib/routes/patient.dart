import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:backend/config/database.dart';
import 'package:backend/utils/jwt.dart';

String? _extractUserId(Request req) {
  final auth = req.headers['authorization'];
  if (auth == null || !auth.startsWith('Bearer ')) return null;
  final token = auth.substring(7);
  final jwt = JwtService();
  final payload = jwt.verify(token);
  if (payload == null) return null;
  return payload['id']?.toString();
}

// Use cascade for top-level router method registration
final _patientRouter = Router()
  ..get('/profile', (Request req) async {
    final uid = _extractUserId(req);
    if (uid == null) return Response.forbidden('{"message":"Unauthorized"}', headers: {'content-type': 'application/json'});

    final db = Database();
    await db.connect();
    final res = await db.query('SELECT p.*, u.email, u.first_name, u.last_name, u.phone FROM patients p JOIN users u ON p.user_id = u.id WHERE p.user_id = @id', substitutionValues: {'id': int.parse(uid)});
    await db.close();
    if (res.isEmpty) return Response.notFound(jsonEncode({'message': 'Patient profile not found'}), headers: {'content-type': 'application/json'});
    return Response.ok(jsonEncode(res.first.toColumnMap()), headers: {'content-type': 'application/json'});
  })
  ..post('/telemetry', (Request req) async {
    final uid = _extractUserId(req);
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
    return Response(201, body: jsonEncode({'telemetry': inserted.first.toColumnMap()}), headers: {'content-type': 'application/json'});
  });

// Export named router
final router = _patientRouter;
