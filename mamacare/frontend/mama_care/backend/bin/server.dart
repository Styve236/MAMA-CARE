import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:backend/utils/env.dart';
import 'package:backend/router.dart';
import 'package:logging/logging.dart';

import 'package:backend/config/database.dart';
import 'package:backend/routes/push.dart';

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

  final jwtSecret = Env.get('JWT_SECRET');
  if (jwtSecret == null || jwtSecret.length < 32) {
    log.shout(
        'FATAL: JWT_SECRET manquant ou trop court (32 caractères minimum). '
        'Configurer la variable d\'environnement JWT_SECRET puis relancer.');
    exit(1);
  }
  final db = Database();
  await db.connect();

  final router = buildRouter();

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

  // Envoi des rappels arrivés à échéance toutes les minutes pendant que le
  // processus vit (en complément de l'endpoint /api/push/process-reminders
  // utilisé par une éventuelle Cron Job Render).
  Timer.periodic(
    const Duration(minutes: 1),
    (_) async {
      try {
        final result = await processDueReminders(db);
        if (result['processed'] != 0) {
          log.info('Rappels traités : $result');
        }
      } catch (error, stack) {
        log.severe('Échec traitement des rappels : $error\n$stack');
      }
    },
  );
}
