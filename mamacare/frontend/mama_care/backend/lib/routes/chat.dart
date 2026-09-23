import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:backend/utils/jwt.dart';
import 'package:backend/utils/env.dart';

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
  return jwt.verify(token);
}

final _chatRouter = Router()
  ..post('/', (Request req) async {
    final user = _extractUser(req);
    if (user == null) {
      return Response.forbidden(jsonEncode({'message': 'Unauthorized'}),
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

    final apiKey = Env.get('GEMINI_API_KEY');
    if (apiKey == null || apiKey.isEmpty) {
      return Response(503,
          body: jsonEncode({
            'error': "L'assistant IA n'est pas encore configuré."
          }),
          headers: {'content-type': 'application/json'});
    }

    final client = HttpClient();
    try {
      final uri = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.6-flash:generateContent?key=$apiKey');
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({
        'systemInstruction': {
          'parts': [
            {'text': _systemPrompt}
          ]
        },
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': message.trim()}
            ]
          }
        ],
        'generationConfig': {
          'maxOutputTokens': 400,
          'temperature': 0.6,
        },
      }));

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        return Response(502,
            body: jsonEncode({'error': 'Réponse invalide du service IA'}),
            headers: {'content-type': 'application/json'});
      }

      final decodedResponse = jsonDecode(responseBody) as Map<String, dynamic>;
      final candidates = decodedResponse['candidates'] as List?;
      String? text;
      if (candidates != null && candidates.isNotEmpty) {
        final content =
            (candidates.first as Map<String, dynamic>)['content'];
        if (content is Map<String, dynamic>) {
          final parts = content['parts'] as List?;
          if (parts != null && parts.isNotEmpty) {
            final first = parts.first;
            if (first is Map<String, dynamic>) {
              text = first['text'] as String?;
            }
          }
        }
      }
      if (text == null || text.trim().isEmpty) {
        return Response(502,
            body: jsonEncode({'error': "L'IA n'a fourni aucune réponse"}),
            headers: {'content-type': 'application/json'});
      }
      return Response.ok(jsonEncode({'reply': text.trim()}),
          headers: {'content-type': 'application/json'});
    } on SocketException {
      return Response(502,
          body: jsonEncode({'error': 'Impossible de joindre le service IA'}),
          headers: {'content-type': 'application/json'});
    } finally {
      client.close();
    }
  });

final router = _chatRouter;