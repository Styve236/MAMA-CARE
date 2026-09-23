import 'dart:developer' as developer;
import 'dart:io';

import 'package:backend/config/database.dart';

Future<void> main() async {
  final migrationsDirectory = Directory('migrations');
  if (!migrationsDirectory.existsSync()) {
    throw StateError(
        'Migration directory not found: ${migrationsDirectory.path}');
  }

  final db = Database();
  await db.connect();

  try {
    await db.connection.execute('''
      CREATE TABLE IF NOT EXISTS schema_migrations (
        version VARCHAR(100) PRIMARY KEY,
        applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
    ''');

    final migrations = migrationsDirectory
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.sql'))
        .toList()
      ..sort((left, right) => left.path.compareTo(right.path));

    for (final migration in migrations) {
      final version = migration.uri.pathSegments.last.replaceFirst('.sql', '');
      final applied = await db.query(
        'SELECT version FROM schema_migrations WHERE version = @version',
        substitutionValues: {'version': version},
      );

      if (applied.isNotEmpty) {
        developer.log('Skipping $version (already applied)');
        continue;
      }

      final sql = await migration.readAsString();
      await db.connection.transaction((context) async {
        await context.execute(sql);
        await context.execute(
          'INSERT INTO schema_migrations (version) VALUES (@version)',
          substitutionValues: {'version': version},
        );
      });
      developer.log('Applied $version');
    }
  } finally {
    await db.close();
  }
}
