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

final _adminRouter = Router()
  ..get('/stats', (Request req) async {
    final uid = _extractUserId(req);
    if (uid == null) return Response.forbidden(jsonEncode({'message': 'Unauthorized'}), headers: {'content-type': 'application/json'});
    final db = Database();
    await db.connect();
    final res = await db.query('SELECT (SELECT COUNT(*) FROM users WHERE role = \'patiente\') as total_patients, (SELECT COUNT(*) FROM users WHERE role = \'medecin\') as total_doctors, (SELECT COUNT(*) FROM users) as total_users, (SELECT COUNT(*) FROM appointments) as total_appointments, (SELECT COUNT(*) FROM appointments WHERE status = \'completed\') as completed_appointments');
    await db.close();
    return Response.ok(jsonEncode(res.first.toColumnMap()), headers: {'content-type': 'application/json'});
  });

final router = _adminRouter;
