import 'dart:convert';
import 'dart:io';
import 'package:backend/utils/env.dart';

/// Modèles Gemini tentés en cascade : si un modèle est saturé (503 "high
/// demand"), à quota (429) ou indisponible (404), on passe au suivant.
const kGeminiModels = [
  'gemini-3.6-flash',
  'gemini-3.5-flash',
  'gemini-3.5-flash-lite',
  'gemini-3-flash-preview',
  'gemini-flash-lite-latest',
];

/// Analyse les constantes (télémétrie) d'une patiente via Gemini et retourne
/// un résultat structuré : niveau de risque, synthèse et recommandations.
///
/// Retourne `null` si la clé IA n'est pas configurée ou si l'analyse échoue
/// (le flux principal doit fonctionner sans l'IA).
Future<Map<String, dynamic>?> analyzeTelemetry(
  Map<String, dynamic> profile,
  Map<String, dynamic> telemetry,
) async {
  final apiKey = Env.get('GEMINI_API_KEY');
  if (apiKey == null || apiKey.isEmpty) return null;
  const prompt = '''
Tu es l'IA médicale de Mamacare, spécialisée dans le suivi de grossesse.
Tu analyses les constantes saisies par une patiente pour PRÉALERTER le médecin
avant qu'il ne consulte le dossier. Retourne UNIQUEMENT du JSON valide, sans
texte autour, au format :
{"severity":"critical|warning|normal","summary":"...","recommendations":[...max 3 courtes...]}

Repères (grossesse) :
- Tension artérielle dangereuse : systolique >= 160 ou diastolique >= 110 (critical) ;
  préoccupante : systolique >= 140 ou diastolique >= 90 (warning).
- Rythme cardiaque : hors 60-100 (warning), hors 50-110 (critical).
- Glycémie : >= 7.0 (warning), >= 11.1 (critical) ; <= 3.9 (critical).
- Température : >= 38.0 (warning), >= 38.5 (critical).
- Toujours stresser si la patiente signale douleurs, saignements, perte des eaux
  ou mouvements du bébé faibles -> critical, recommander les urgences.
Parle toujours en français, de façon concise et professionnelle.
''';

  final client = HttpClient();
  try {
    for (final model in kGeminiModels) {
      for (var attempt = 0; attempt < 2; attempt++) {
        if (model != kGeminiModels.first || attempt > 0) {
          await Future.delayed(Duration(seconds: 1 + attempt));
        }
        final uri = Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey');
        final request = await client.postUrl(uri);
        request.headers.contentType = ContentType.json;
        final context = {
          'profile': profile,
          'telemetry': telemetry,
        };
        request.write(jsonEncode({
          'systemInstruction': {
            'parts': [
              {'text': prompt}
            ]
          },
          'contents': [
            {
              'role': 'user',
              'parts': [
                {
                  'text':
                      'Analyse ces données patiente et retourne le JSON demandé :\n${jsonEncode(context)}'
                }
              ]
            }
          ],
          'generationConfig': {
            'maxOutputTokens': 500,
            'temperature': 0.2,
          },
        }));

        final response = await request.close();
        final responseBody = await response.transform(utf8.decoder).join();
        if (response.statusCode != 200) continue;

        final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
        final candidates = decoded['candidates'] as List?;
        if (candidates == null || candidates.isEmpty) continue;
        final content = (candidates.first as Map<String, dynamic>)['content'];
        if (content is! Map<String, dynamic>) continue;
        final parts = content['parts'] as List?;
        if (parts == null || parts.isEmpty) continue;
        final text = parts.map((p) {
          final map = p as Map<String, dynamic>;
          return map['text'] as String? ?? '';
        }).join();
        if (text.trim().isEmpty) continue;

        final jsonStart = text.indexOf('{');
        final jsonEnd = text.lastIndexOf('}');
        if (jsonStart < 0 || jsonEnd <= jsonStart) continue;
        final parsed = jsonDecode(text.substring(jsonStart, jsonEnd + 1))
            as Map<String, dynamic>;
        final severity =
            (parsed['severity'] as String?)?.trim().toLowerCase() ?? 'normal';
        final normalized = ['critical', 'warning', 'normal'].contains(severity)
            ? severity
            : 'normal';
        return {
          'severity': normalized,
          'summary':
              (parsed['summary'] as String?)?.trim() ?? 'Analyse réalisée.',
          'recommendations': (parsed['recommendations'] as List?)
                  ?.map((e) => e.toString().trim())
                  .where((e) => e.isNotEmpty)
                  .toList() ??
              [],
        };
      }
    }
    return null;
  } on FormatException {
    return null;
  } on SocketException {
    return null;
  } finally {
    client.close();
  }
}
