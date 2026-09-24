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
/// un résultat structuré : niveau de risque, état de santé, synthèse médecin,
/// message patiente et recommandations.
///
/// Une analyse « par règles » locale sert de base (et prend le relais si la
/// clé IA n'est pas configurée ou si l'appel échoue) pour que le flux reste
/// fonctionnel et sûr sans l'IA.
Future<Map<String, dynamic>?> analyzeTelemetry(
  Map<String, dynamic> profile,
  Map<String, dynamic> telemetry,
) async {
  final local = ruleBasedAnalysis(profile, telemetry);
  final apiKey = Env.get('GEMINI_API_KEY');
  if (apiKey == null || apiKey.isEmpty) return local;
  const prompt = '''
Tu es l'IA médicale de Mamacare, spécialisée dans le suivi de grossesse.
Tu analyses les constantes saisies par une patiente pour :
1. dire À LA PATIENTE si elle est en bonne santé, préoccupée, dans un état
   grave ou sur le point de faire un malaise ;
2. PRÉALERTER son médecin avec une synthèse concise.
Retourne UNIQUEMENT du JSON valide, sans texte autour, au format :
{"severity":"critical|warning|normal","status":"bonne|preoccupant|grave|malaise","summary":"synthèse pour le médecin","patient_message":"message rassurant et préventif pour la patiente","recommendations":["...max 3 courtes..."]}

Repères (grossesse) :
- Tension artérielle dangereuse : systolique >= 160 ou diastolique >= 110 (critical) ;
  préoccupante : systolique >= 140 ou diastolique >= 90 (warning) ; hypotension : systolique < 90 (warning/malaise).
- Rythme cardiaque : hors 60-100 (warning), hors 50-110 (critical).
- Glycémie : >= 7.0 (warning), >= 11.1 (critical) ; <= 3.9 (critical, risque de malaise).
- Température : >= 38.0 (warning), >= 38.5 (critical).
- Risque de malaise si : hypoglycémie (< 3.9) OU hypotension marquée OU combinaison
  glycémie basse + tension basse ; et si la patiente signale vertiges, malaise, sueurs,
  évanouissement.
- Toujours stresser si la patiente signale douleurs, saignements, perte des eaux,
  contractions ou mouvements du bébé faibles -> critical, recommander les urgences.
Le message patiente ('patient_message') doit être empathique, en français, court et
préventif, sans jamais annoncer un diagnostic.
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
            'maxOutputTokens': 600,
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

        // L'IA ne peut qu'ALOURDIR le niveau d'urgence par rapport aux règles
        // locales : jamais le masquer (sécurité).
        final ia = _normalizeParsed(parsed);
        return {
          'severity': _maxSeverity(local, ia),
          'status': _statusFor(local, ia),
          'summary': ia['summary'],
          'patient_message': ia['patient_message'],
          'recommendations': ia['recommendations'],
          'risk_of_malaise': local['risk_of_malaise'] || ia['risk_of_malaise'],
        };
      }
    }
    return local;
  } on FormatException {
    return local;
  } on SocketException {
    return local;
  } finally {
    client.close();
  }
}

Map<String, dynamic> _normalizeParsed(Map<String, dynamic> parsed) {
  final severity =
      (parsed['severity'] as String?)?.trim().toLowerCase() ?? 'normal';
  final normalizedSeverity =
      ['critical', 'warning', 'normal'].contains(severity) ? severity : 'normal';

  final status = (parsed['status'] as String?)?.trim().toLowerCase() ?? '';
  final normalizedStatus = ['bonne', 'preoccupant', 'grave', 'malaise']
          .contains(status)
      ? status
      : _statusFromSeverity(normalizedSeverity);

  final recommendations = (parsed['recommendations'] as List?)
          ?.map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList() ??
      [];
  final malaise = normalizedStatus == 'malaise';

  return {
    'severity': normalizedSeverity,
    'status': normalizedStatus,
    'summary': (parsed['summary'] as String?)?.trim() ?? 'Analyse réalisée.',
    'patient_message': (parsed['patient_message'] as String?)?.trim() ??
        _messageFor(normalizedStatus),
    'recommendations': recommendations.take(3).toList(),
    'risk_of_malaise': malaise,
  };
}

/// Analyse déterministe (règles médicales grossesse) : toujours disponible,
/// sert de base de sécurité même sans IA.
Map<String, dynamic> ruleBasedAnalysis(
  Map<String, dynamic> profile,
  Map<String, dynamic> telemetry,
) {
  final sys = _num(telemetry['blood_pressure_systolic']);
  final dia = _num(telemetry['blood_pressure_diastolic']);
  final hr = _num(telemetry['heart_rate']);
  final glucose = _num(telemetry['blood_glucose']);
  final temp = _num(telemetry['temperature']);
  final notes = '${telemetry['notes'] ?? ''}'.toLowerCase();

  var severity = 'normal';
  var status = 'bonne';
  var riskOfMalaise = false;

  void escalate(String s, {String? to}) {
    if (_rank(s) > _rank(severity)) severity = s;
    if (to != null && _rank(s) >= _rank('warning')) status = to;
  }

  if (sys != null && (sys >= 160 || (dia ?? 0) >= 110)) {
    escalate('critical', to: 'grave');
  } else if (sys != null && (sys >= 140 || (dia ?? 0) >= 90)) {
    escalate('warning', to: 'preoccupant');
  }
  if (sys != null && sys <= 90) {
    escalate('warning', to: 'preoccupant');
  }
  if ((sys ?? 0) != 0 && (dia ?? 0) != 0 && sys! < 100 && dia! < 65) {
    if (glucose != null && glucose <= 4.5) {
      riskOfMalaise = true;
      escalate('critical', to: 'malaise');
    }
  }
  if (glucose != null) {
    if (glucose >= 11.1) {
      escalate('critical', to: 'grave');
    } else if (glucose >= 7.0) {
      escalate('warning', to: 'preoccupant');
    } else if (glucose <= 3.9) {
      riskOfMalaise = true;
      escalate('critical', to: 'malaise');
    }
  }
  if (hr != null) {
    if (hr < 50 || hr > 110) {
      escalate('critical', to: 'grave');
    } else if (hr < 60 || hr > 100) {
      escalate('warning', to: 'preoccupant');
    }
  }
  if (temp != null) {
    if (temp >= 38.5) {
      escalate('critical', to: 'grave');
    } else if (temp >= 38.0) {
      escalate('warning', to: 'preoccupant');
    }
  }

  // Signaux verbaux : toujours prendre au sérieux.
  const criticalSignals = [
    'saignement',
    'douleur',
    'mal aux',
    'contraction',
    'perte des eaux',
    'fièvre',
  ];
  const malaiseSignals = [
    'vertige',
    'malaise',
    'évanouiss',
    'sueur',
    'mouvement du bébé',
    'nausée',
  ];
  if (criticalSignals.any(notes.contains)) {
    escalate('critical', to: 'grave');
  }
  if (malaiseSignals.any(notes.contains)) {
    riskOfMalaise = true;
    if (_rank(severity) < _rank('critical')) severity = 'warning';
    status = 'malaise';
  }
  if (riskOfMalaise) status = 'malaise';

  final recommendations = <String>[];
  if (status == 'bonne') {
    recommendations.add('Continuez vos mesures régulières.');
    recommendations.add('Reposez-vous suffisamment et buvez de l\'eau.');
  } else {
    recommendations.add('Contactez votre médecin référent rapidement.');
    if (riskOfMalaise) {
      recommendations
          .add('En cas de malaise avéré : allongez-vous et appelez les secours (144).');
    } else if (severity == 'critical') {
      recommendations.add('Direction les urgences si les symptômes s\'aggravent.');
    }
  }

  return {
    'severity': severity,
    'status': status,
    'summary': _summaryFor(severity, status, telemetry),
    'patient_message': _messageFor(status),
    'recommendations': recommendations.take(3).toList(),
    'risk_of_malaise': riskOfMalaise,
  };
}

double? _num(Object? value) {
  if (value == null) return null;
  final n = num.tryParse('$value');
  return n?.toDouble();
}

int _rank(String s) {
  switch (s) {
    case 'normal':
      return 0;
    case 'warning':
      return 1;
    case 'critical':
      return 2;
    default:
      return 0;
  }
}

String _maxSeverity(Map<String, dynamic> local, Map<String, dynamic> ia) {
  final rank = _rank(local['severity'] as String? ?? 'normal');
  final iaRank = _rank(ia['severity'] as String? ?? 'normal');
  return rank >= iaRank
      ? (local['severity'] as String? ?? 'normal')
      : (ia['severity'] as String? ?? 'normal');
}

String _statusFor(Map<String, dynamic> local, Map<String, dynamic> ia) {
  final localStatus = local['status'] as String? ?? 'bonne';
  if (local['risk_of_malaise'] == true ||
      ia['risk_of_malaise'] == true ||
      localStatus == 'malaise' ||
      ia['status'] == 'malaise') {
    return 'malaise';
  }
  return _statusFromSeverity(_maxSeverity(local, ia));
}

String _statusFromSeverity(String severity) {
  switch (severity) {
    case 'critical':
      return 'grave';
    case 'warning':
      return 'preoccupant';
    default:
      return 'bonne';
  }
}

String _summaryFor(String severity, String status, Map<String, dynamic> t) {
  final sys = _num(t['blood_pressure_systolic']);
  final dia = _num(t['blood_pressure_diastolic']);
  final hr = _num(t['heart_rate']);
  final glucose = _num(t['blood_glucose']);
  final temp = _num(t['temperature']);
  final tension = sys != null && dia != null ? '$sys/$dia mmHg' : 'non renseignée';
  final parts = <String>[];
  if (severity == 'normal') {
    parts.add('Constantes dans les limites attendues pour une grossesse.');
  } else if (status == 'malaise') {
    parts.add('Risque de malaise détecté.');
  } else {
    parts.add('Constantes en dehors des valeurs de référence.');
  }
  parts.add(
      'Tension $tension, pouls ${hr?.toStringAsFixed(0) ?? 'n/a'}, glycémie ${glucose?.toStringAsFixed(1) ?? 'n/a'}, température ${temp?.toStringAsFixed(1) ?? 'n/a'}°C.');
  return parts.join(' ');
}

String _messageFor(String status) {
  switch (status) {
    case 'bonne':
      return 'Vos constantes semblent dans les limites attendues pour votre '
          'grossesse. Continuez à prendre soin de vous et à vous reposer.';
    case 'preoccupant':
      return 'Certaines de vos constantes méritent un peu d\'attention. '
          'Reposez-vous et surveillez vos mesures ; pensez à prévenir votre '
          'médecin si cela persiste.';
    case 'grave':
      return 'Vos données montrent des signes qui peuvent être inquiétants. '
          'Contactez votre médecin sans attendre, ou rendez-vous aux urgences '
          'si vous présentez des symptômes.';
    case 'malaise':
      return 'Vos données évoquent un risque de malaise (glycémie ou tension '
          'très basse). Asseyez-vous ou allongez-vous immédiatement, buvez une '
          'boisson sucrée si vous le pouvez, et appelez votre médecin ou les '
          'secours.';
    default:
      return 'Analyse réalisée.';
  }
}