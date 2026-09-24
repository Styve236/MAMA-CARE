import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:backend/config/database.dart';
import 'package:backend/models/user.dart';
import 'package:backend/utils/jwt.dart';
import 'package:backend/utils/hash.dart';
import 'package:backend/utils/json_safe.dart';
import 'package:backend/utils/rate_limit.dart';
import 'package:backend/utils/http_body.dart';

final _registerLimiter = RateLimiter(5, const Duration(minutes: 10));
final _loginIpLimiter = RateLimiter(30, const Duration(minutes: 15));
final _loginAccountLimiter = RateLimiter(5, const Duration(minutes: 15));

final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

String _clientIp(Request req) =>
    req.headers['x-forwarded-for']?.split(',').first.trim() ??
    req.headers['x-real-ip'] ??
    'unknown';

bool _weakPassword(String password) {
  if (password.length < 8) return true;
  if (!RegExp(r'[a-zA-Z]').hasMatch(password)) return true;
  if (!RegExp(r'[0-9]').hasMatch(password)) return true;
  return false;
}

Response _json(int status, Object body, {int? retryAfter}) => Response(
      status,
      body: jsonEncode(body),
      headers: {
        'content-type': 'application/json',
        if (retryAfter != null) 'retry-after': '$retryAfter',
      },
    );

final router = Router()
  ..post('/register', (Request req) async {
    final ip = _clientIp(req);
    final wait = _registerLimiter.hit(ip);
    if (wait != null) {
      return _json(429, {'message': 'Trop d\'inscriptions, réessayez plus tard'}, retryAfter: wait);
    }

    final Map<String, dynamic> body;
    try {
      body = await readJsonObject(req);
    } on HttpError catch (e) {
      return _json(e.status, {'message': e.message});
    }

    final email = (body['email'] as String?)?.trim();
    final password = body['password'] as String?;
    final role = (body['role'] as String?)?.toLowerCase();
    final firstName = (body['firstName'] as String?)?.trim();
    final lastName = (body['lastName'] as String?)?.trim();
    final phone = (body['phone'] as String?)?.trim();

    if (role != null && role != 'patiente') {
      return _json(400, {'message': 'L\'inscription publique est réservée aux patientes'});
    }
    if (email == null || email.isEmpty) {
      return _json(400, {'message': 'Adresse e-mail requise'});
    }
    if (!_emailPattern.hasMatch(email)) {
      return _json(400, {'message': 'Adresse e-mail invalide'});
    }
    if (email.length > 120) {
      return _json(400, {'message': 'Adresse e-mail trop longue'});
    }
    if (password == null || _weakPassword(password)) {
      return _json(400, {'message': 'Mot de passe : 8 caractères minimum, avec lettres et chiffres'});
    }
    if ((firstName ?? '').length > 80 || (lastName ?? '').length > 80) {
      return _json(400, {'message': 'Prénom ou nom trop long'});
    }
    if ((phone ?? '').length > 30) {
      return _json(400, {'message': 'Numéro de téléphone trop long'});
    }

    final db = Database();
    await db.connect();
    final userModel = UserModel(db);
    final existing = await userModel.findByEmail(email);
    if (existing != null) {
      await db.close();
      return _json(400, {'message': 'Email déjà enregistré'});
    }

    final newUser = await userModel.createUser(
      email: email,
      password: password,
      role: 'patiente',
      firstName: firstName,
      lastName: lastName,
      phone: phone,
    );

    await db.close();
    return _json(201, {
      'message': 'Compte créé. Un administrateur va valider votre profil.',
      'user': jsonSafe(newUser),
    });
  })
  ..post('/login', (Request req) async {
    final ip = _clientIp(req);
    final ipWait = _loginIpLimiter.hit(ip);
    if (ipWait != null) {
      return _json(429, {'message': 'Trop de tentatives, réessayez plus tard'}, retryAfter: ipWait);
    }

    final Map<String, dynamic> body;
    try {
      body = await readJsonObject(req);
    } on HttpError catch (e) {
      return _json(e.status, {'message': e.message});
    }

    final email = (body['email'] as String?)?.trim();
    final password = body['password'] as String?;
    if (email == null || email.isEmpty || password == null || password.isEmpty) {
      return _json(400, {'message': 'email and password required'});
    }

    final accountWait = _loginAccountLimiter.hit(email.toLowerCase());
    if (accountWait != null) {
      return _json(429, {'message': 'Trop de tentatives pour ce compte, réessayez plus tard'}, retryAfter: accountWait);
    }

    final db = Database();
    await db.connect();
    final userModel = UserModel(db);
    final user = await userModel.findByEmail(email);
    if (user == null) {
      await db.close();
      return _json(401, {'message': 'Invalid email or password'});
    }

    final status = user['status'] as String?;
    final pwHash = user['password_hash'] as String?;
    final valid = HashService.verifyPassword(password, pwHash ?? '');
    if (!valid) {
      await db.close();
      return _json(401, {'message': 'Invalid email or password'});
    }
    _loginAccountLimiter.reset(email.toLowerCase());

    if (status != 'active') {
      await db.close();
      return _json(403, {'message': 'Compte en attente de validation par un administrateur'});
    }

    final jwt = JwtService();
    final token = jwt.sign({
      'id': user['id'],
      'email': user['email'],
      'role': user['role'],
      'status': status,
    });

    await db.query('UPDATE users SET last_login = NOW() WHERE id = @id', substitutionValues: {'id': user['id']});
    await db.close();

    return _json(200, {
      'message': 'Login successful',
      'token': token,
      'user': {
        'id': user['id'],
        'email': user['email'],
        'role': user['role'],
        'status': status,
      },
    });
  })
  ..post('/logout', (Request req) async {
    final auth = req.headers['authorization'];
    if (auth == null || !auth.startsWith('Bearer ')) return _json(401, {'message': 'Missing token'});
    final token = auth.substring(7);
    final jwt = JwtService();
    if (jwt.verify(token) == null) return _json(401, {'message': 'Token invalide ou expiré'});
    jwt.revoke(token);
    return _json(200, {'message': 'Déconnecté'});
  })
  ..get('/verify', (Request req) async {
    final auth = req.headers['authorization'];
    if (auth == null || !auth.startsWith('Bearer ')) return _json(401, {'message': 'Missing token'});
    final token = auth.substring(7);
    final jwt = JwtService();
    final payload = jwt.verify(token);
    if (payload == null) return _json(403, {'message': 'Invalid or expired token'});
    return _json(200, {'valid': true, 'user': payload});
  });