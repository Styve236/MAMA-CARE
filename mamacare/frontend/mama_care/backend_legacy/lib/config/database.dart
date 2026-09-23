import 'package:postgres/postgres.dart';
import 'package:backend/utils/env.dart';
import 'package:logging/logging.dart';

class Database {
  late PostgreSQLConnection connection;

  final String host = Env.get('DB_HOST') ?? 'localhost';
  final int port = int.tryParse(Env.get('DB_PORT') ?? '5432')!;
  final String database = Env.get('DB_NAME') ?? 'mamacare_db';
  final String username = Env.get('DB_USER') ?? 'postgres';
  final String password = Env.get('DB_PASSWORD') ?? '';

  Database();

  Future<void> connect() async {
    connection = PostgreSQLConnection(host, port, database, username: username, password: password);
    await connection.open();
    Logger('database').info('Connected to PostgreSQL at $host:$port/$database');
  }

  Future<PostgreSQLResult> query(String sql, {Map<String, dynamic>? substitutionValues}) async {
    return connection.query(sql, substitutionValues: substitutionValues);
  }

  Future<void> close() async {
    await connection.close();
  }
}
