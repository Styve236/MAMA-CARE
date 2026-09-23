import 'dart:developer' as developer;
import 'dart:io';

import 'package:postgres/postgres.dart';
import 'package:backend/utils/env.dart';

class Database {
  late PostgreSQLConnection connection;

  final String host =
      Env.get('DB_HOST') ?? 'aws-0-eu-central-1.pooler.supabase.com';
  final int port = int.tryParse(Env.get('DB_PORT') ?? '5432')!;
  final String database = Env.get('DB_NAME') ?? 'postgres';
  final String username = Env.get('DB_USER') ?? 'postgres.unwgionfobojsvrefcsn';
  final String password = Env.get('DB_PASSWORD') ?? '';

  Database();

  Future<void> connect() async {
    Object? lastError;
    for (var attempt = 1; attempt <= 3; attempt++) {
      final candidate = PostgreSQLConnection(host, port, database,
          username: username, password: password, useSSL: true);
      try {
        await candidate.open();
        connection = candidate;
        developer.log('Connected to PostgreSQL at $host:$port/$database');
        return;
      } on SocketException catch (error) {
        lastError = error;
        if (attempt == 3) break;
        developer.log(
          'PostgreSQL connection attempt $attempt failed for $host:$port; '
          'retrying...',
          level: 900,
        );
        await Future<void>.delayed(Duration(seconds: attempt));
      }
    }

    throw StateError(
      'Unable to connect to PostgreSQL at $host:$port after 3 attempts. '
      'Verify DB_HOST, DB_PORT, network/DNS access, and Supabase availability. '
      'Last error: $lastError',
    );
  }

  Future<PostgreSQLResult> query(String sql,
      {Map<String, dynamic>? substitutionValues}) async {
    return connection.query(sql, substitutionValues: substitutionValues);
  }

  Future<void> close() async {
    await connection.close();
  }
}
