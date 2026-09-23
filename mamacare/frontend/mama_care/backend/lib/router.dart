import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'package:backend/routes/auth.dart' as auth;
import 'package:backend/routes/patient.dart' as patient;
import 'package:backend/routes/doctor.dart' as doctor;
import 'package:backend/routes/admin.dart' as admin;
import 'package:backend/routes/notifications.dart' as notifications;

Router buildRouter() {
  final router = Router();

  router.get(
    '/',
    (Request req) => Response.ok(
      jsonEncode({'status': 'ok', 'message': 'MAMA-CARE API is running'}),
      headers: {'content-type': 'application/json'},
    ),
  );

  router.get(
    '/health',
    (Request req) => Response.ok(
      '{"status":"API is running"}',
      headers: {'content-type': 'application/json'},
    ),
  );

  router.mount('/api/auth/', auth.router.call);
  router.mount('/api/patient/', patient.router.call);
  router.mount('/api/doctor/', doctor.router.call);
  router.mount('/api/admin/', admin.router.call);
  router.mount('/api/notifications/', notifications.router.call);

  return router;
}