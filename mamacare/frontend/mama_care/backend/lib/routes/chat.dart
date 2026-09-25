import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:backend/config/database.dart';
import 'package:backend/utils/jwt.dart';
import 'package:backend/utils/env.dart';
import 'package:backend/utils/json_safe.dart';
import 'package:backend/utils/mistral.dart';

const _systemPrompt = '''
Tu es Mamacare AI, l'assistante virtuelle de l'application Mamacare dédiée au suivi de la grossesse.
Tu accompagnes des femmes enceintes et des professionnels de santé.

Règles impératives :
- Réponds toujours en français, de façon claire et bienveillante.
- Ne pose JAMAIS de diagnostic médical et ne remplace pas l'avis d'un médecin.
- Pour tout symptôme inquiétant (saignements, douleurs intenses, perte des eaux, absence de mouvements du bébé, etc.), recommande de contacter un médecin ou les urgences immédiatement.
- Reste concise : 80 à 150 mots maximum.
- Peux donner des conseils généraux sur la nutrition, le bien-être, les rendez-vous, les médicaments sans danger (toujours sous réserve de l'avis médical) et les signes d'alerte.
''';

Map<String, dynamic>? _extractUser(Request req) {
  final auth = req.headers['authorization'];
  if (auth == null || !auth.startsWith('Bearer ')) return null;
  final token = auth.substring(7);
  final jwt = JwtService();
  final payload = jwt.verify(token);
  if (payload == null || payload['status'] != 'active') return null;
  return payload;
}

final _chatRouter = Router()
  ..post('/', (Request req) async {
    final user = _extractUser(req);
    if (user == null) {
      return Response.forbidden(jsonEncode({'message': 'Unauthorized'}),
          headers: {'content-type': 'application/json'});
    }
    // L'historique est lié à la patiente connectée : le chat est réservé au
    // rôle patiente (sécurité des données).
    if (user['role'] != 'patiente') {
      return Response.forbidden(jsonEncode({'message': 'Forbidden'}),
          headers: {'content-type': 'application/json'});
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(await req.readAsString());
    } on FormatException {
      return Response(400,
          body: jsonEncode({'error': 'JSON invalide'}),
          headers: {'content-type': 'application/json'});
    }
    final message =
        decoded is Map<String, dynamic> ? decoded['message'] as String? : null;
    if (message == null || message.trim().isEmpty) {
      return Response(400,
          body: jsonEncode({'error': 'Le message est vide'}),
          headers: {'content-type': 'application/json'});
    }
    if (message.trim().length > 2000) {
      return Response(400,
          body: jsonEncode({'error': 'Message trop long (2000 caractères max)'}),
          headers: {'content-type': 'application/json'});
    }

    final apiKey = Env.get('MISTRAL_API_KEY');
    if (apiKey == null || apiKey.isEmpty) {
      return Response(503,
          body: jsonEncode(
              {'error': "L'assistant IA n'est pas encore configuré."}),
          headers: {'content-type': 'application/json'});
    }

    final text = await mistralChatCompletion(
      systemPrompt: _systemPrompt,
      userMessage: message.trim(),
    );
    if (text == null) {
      return Response(502,
          body: jsonEncode({'error': 'Réponse invalide du service IA'}),
          headers: {'content-type': 'application/json'});
    }

    // Persistance : la patiente pourra relire cet échange à tout moment.
    final db = Database();
    await db.connect();
    try {
      final patient = await db.query(
          'SELECT id FROM patients WHERE user_id = @u',
          substitutionValues: {'u': int.parse('${user['id']}')});
      if (patient.isNotEmpty) {
        await db.query(
          '''INSERT INTO chatbot_conversations (patient_id, user_message, bot_response)
             VALUES (@p, @um, @bm)''',
          substitutionValues: {
            'p': patient.first[0],
            'um': message.trim(),
            'bm': text.trim(),
          },
        );
      }
    } finally {
      await db.close();
    }

    return Response.ok(jsonEncode({'reply': text.trim()}),
        headers: {'content-type': 'application/json'});
  })
  ..get('/history', (Request req) async {
    final user = _extractUser(req);
    if (user == null || user['role'] != 'patiente') {
      return Response.forbidden(jsonEncode({'message': 'Unauthorized'}),
          headers: {'content-type': 'application/json'});
    }
    final db = Database();
    await db.connect();
    try {
      final rows = await db.query(
        '''SELECT c.id, c.user_message, c.bot_response, c.created_at
           FROM chatbot_conversations c JOIN patients p ON p.id = c.patient_id
           WHERE p.user_id = @u
           ORDER BY c.created_at DESC LIMIT 100''',
        substitutionValues: {'u': int.parse('${user['id']}')},
      );
      final items = rows.map((r) => jsonSafe(r.toColumnMap())).toList();
      return Response.ok(jsonEncode(items.reversed.toList()),
          headers: {'content-type': 'application/json'});
    } finally {
      await db.close();
    }
  });

final router = _chatRouter;
