import 'package:uuid/uuid.dart';
import 'package:backend/config/database.dart';
import 'package:backend/utils/hash.dart';

class UserModel {
  final Database db;
  UserModel(this.db);

  Future<Map<String, dynamic>?> findByEmail(String email) async {
    final res = await db.query('SELECT * FROM users WHERE email = @email', substitutionValues: {'email': email});
    if (res.isNotEmpty) return Map<String, dynamic>.fromEntries(res.first.toColumnMap().entries);
    return null;
  }

  Future<Map<String, dynamic>> createUser({required String email, required String password, required String role, String? firstName, String? lastName, String? phone}) async {
    final uuid = Uuid().v4();
    final passwordHash = HashService.hashPassword(password);
    final res = await db.query(
      '''INSERT INTO users (uuid, email, password_hash, first_name, last_name, phone, role, status)
         VALUES (@uuid, @email, @passwordHash, @firstName, @lastName, @phone, @role, 'active')
         RETURNING id, uuid, email, role, created_at''',
      substitutionValues: {
        'uuid': uuid,
        'email': email,
        'passwordHash': passwordHash,
        'firstName': firstName,
        'lastName': lastName,
        'phone': phone,
        'role': role
      }
    );
    final user = Map<String, dynamic>.fromEntries(res.first.toColumnMap().entries);
    if (role == 'medecin') {
      await db.query(
        'INSERT INTO doctors (user_id) VALUES (@userId)',
        substitutionValues: {'userId': user['id']},
      );
    }
    return user;
  }
}
