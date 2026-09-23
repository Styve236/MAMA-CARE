import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:backend/config/database.dart';
import 'package:backend/utils/jwt.dart';

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
    return Response.ok(jsonEncode(res.first.toColumnMap()), headers: {'content-type': 'application/json'});
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
    return Response.ok(jsonEncode(patients.map((r) => r.toColumnMap()).toList()), headers: {'content-type': 'application/json'});
  });

final router = _doctorRouter;
