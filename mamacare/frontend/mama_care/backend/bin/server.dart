import 'dart:developer' as developer;
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:backend/utils/env.dart';
import 'package:logging/logging.dart';

import 'package:backend/config/database.dart';
import 'package:backend/routes/auth.dart' as auth;
import 'package:backend/routes/patient.dart' as patient;
import 'package:backend/routes/doctor.dart' as doctor;
import 'package:backend/routes/admin.dart' as admin;
import 'package:backend/routes/notifications.dart' as notifications;

Future<HttpServer> _serveOnAvailablePort(
  Handler handler,
  InternetAddress address,
  int preferredPort,
) async {
  for (var port = preferredPort; port < preferredPort + 100; port++) {
    try {
      return await io.serve(handler, address, port);
    } on SocketException catch (error) {
      final errorCode = error.osError?.errorCode;
      if (errorCode != 10048 && errorCode != 98) {
        rethrow;
      }
    }
  }

  throw SocketException(
    'No available port found between $preferredPort and ${preferredPort + 99}',
  );
}

void main(List<String> args) async {
  // Environment variables loaded from .env (if present) via utils/env.dart

  final log = Logger('server');
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen(
      (rec) => developer.log('${rec.level.name}: ${rec.time}: ${rec.message}'));

  final db = Database();
  await db.connect();

  final router = Router();

  router.get(
      '/',
      (Request req) => Response.ok('{"status":"MamaCare API is running"}',
          headers: {'content-type': 'application/json'}));

  router.get(
      '/health',
      (Request req) => Response.ok('{"status":"API is running"}',
          headers: {'content-type': 'application/json'}));

  // Mount routes
  router.mount('/api/auth/', auth.router.call);
  router.mount('/api/patient/', patient.router.call);
  router.mount('/api/doctor/', doctor.router.call);
  router.mount('/api/admin/', admin.router.call);
  router.mount('/api/notifications/', notifications.router.call);

  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(corsHeaders())
      .addHandler(router.call);

  final port =
      int.tryParse(Platform.environment['PORT'] ?? Env.get('PORT') ?? '3000') ??
          3000;
  final ip = InternetAddress.anyIPv4;

  final server = await _serveOnAvailablePort(handler, ip, port);
  log.info(
      '✓ MamaCare Dart Backend running on http://${server.address.host}:${server.port}');
}
