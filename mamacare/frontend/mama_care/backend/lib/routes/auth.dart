import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:backend/config/database.dart';
import 'package:backend/models/user.dart';
import 'package:backend/utils/jwt.dart';
import 'package:backend/utils/hash.dart';
import 'package:backend/utils/json_safe.dart';

final router = Router()
  ..post('/register', (Request req) async {
    final body = jsonDecode(await req.readAsString());
    final email = body['email'] as String?;
    final password = body['password'] as String?;
    final role = body['role'] as String? ?? 'patiente';
    final firstName = body['firstName'] as String?;
    final lastName = body['lastName'] as String?;
    final phone = body['phone'] as String?;

    if (email == null || password == null) {
      return Response(400, body: jsonEncode({'message': 'email and password required'}), headers: {'content-type': 'application/json'});
    }

    final db = Database();
    await db.connect();
    final userModel = UserModel(db);
    final existing = await userModel.findByEmail(email);
    if (existing != null) {
      await db.close();
      return Response(400, body: jsonEncode({'message': 'Email already registered'}), headers: {'content-type': 'application/json'});
    }

    final newUser = await userModel.createUser(email: email, password: password, role: role, firstName: firstName, lastName: lastName, phone: phone);

    final jwt = JwtService();
    final token = jwt.sign({'id': newUser['id'], 'email': newUser['email'], 'role': newUser['role']});

    await db.close();
    return Response(201, body: jsonEncode({'message': 'User registered', 'token': token, 'user': jsonSafe(newUser)}), headers: {'content-type': 'application/json'});
  })
  ..post('/login', (Request req) async {
    final body = jsonDecode(await req.readAsString());
    final email = body['email'] as String?;
    final password = body['password'] as String?;

    if (email == null || password == null) {
      return Response(400, body: jsonEncode({'message': 'email and password required'}), headers: {'content-type': 'application/json'});
    }

    final db = Database();
    await db.connect();
    final userModel = UserModel(db);
    final user = await userModel.findByEmail(email);
    if (user == null) {
      await db.close();
      return Response(401, body: jsonEncode({'message': 'Invalid email or password'}), headers: {'content-type': 'application/json'});
    }

    final pwHash = user['password_hash'] as String?;
    final valid = HashService.verifyPassword(password, pwHash ?? '');
    if (!valid) {
      await db.close();
      return Response(401, body: jsonEncode({'message': 'Invalid email or password'}), headers: {'content-type': 'application/json'});
    }

    final jwt = JwtService();
    final token = jwt.sign({'id': user['id'], 'email': user['email'], 'role': user['role']});

    await db.query('UPDATE users SET last_login = NOW() WHERE id = @id', substitutionValues: {'id': user['id']});
    await db.close();

    return Response.ok(jsonEncode({'message': 'Login successful', 'token': token, 'user': {'id': user['id'], 'email': user['email'], 'role': user['role']}}), headers: {'content-type': 'application/json'});
  })
  ..get('/verify', (Request req) async {
    final auth = req.headers['authorization'];
    if (auth == null || !auth.startsWith('Bearer ')) return Response(401, body: jsonEncode({'message': 'Missing token'}), headers: {'content-type': 'application/json'});
    final token = auth.substring(7);
    final jwt = JwtService();
    final payload = jwt.verify(token);
    if (payload == null) return Response(403, body: jsonEncode({'message': 'Invalid or expired token'}), headers: {'content-type': 'application/json'});
    return Response.ok(jsonEncode({'valid': true, 'user': payload}), headers: {'content-type': 'application/json'});
  });
