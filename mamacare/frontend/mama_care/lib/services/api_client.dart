import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final String message;

  const ApiException(this.message);

  @override
  String toString() => message;
}

class ApiClient {
  static const _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );
  static String? _token;

  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    final response = await _post('/api/auth/login', {
      'email': email,
      'password': password,
    });
    _token = response['token'] as String?;
    return response;
  }

  static void logout() {
    _token = null;
  }

  static Future<String> sendChatMessage(String message) async {
    final response = await _post('/api/chat/', {'message': message});
    return (response['reply'] as String?) ?? 'Aucune réponse de l\'assistant.';
  }

  static Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String firstName,
    String? lastName,
    String? phone,
  }) async {
    return _post('/api/auth/register', {
      'email': email,
      'password': password,
      'role': 'patiente',
      'firstName': firstName,
      'lastName': lastName,
      'phone': phone,
    });
  }

  static Future<List<Map<String, dynamic>>> doctorPatients() async {
    final response = await _get('/api/doctor/patients');
    return response.cast<Map<String, dynamic>>();
  }

  static Future<Map<String, dynamic>> patientProfile() =>
      _getObject('/api/patient/profile');

  static Future<void> updatePatientProfile({
    String? firstName,
    String? lastName,
    String? phone,
    String? email,
    int? pregnancyWeeks,
    String? bloodType,
    String? medicalConditions,
    String? allergies,
    String? emergencyContactName,
    String? emergencyContactPhone,
  }) {
    return _patch('/api/patient/profile', {
      'firstName': firstName,
      'lastName': lastName,
      'phone': phone,
      'email': email,
      'pregnancyWeeks': pregnancyWeeks,
      'bloodType': bloodType,
      'medicalConditions': medicalConditions,
      'allergies': allergies,
      'emergencyContactName': emergencyContactName,
      'emergencyContactPhone': emergencyContactPhone,
    });
  }

  static Future<void> updateDoctorProfile({
    String? firstName,
    String? lastName,
    String? phone,
    String? email,
    String? specialization,
    String? hospitalAffiliation,
  }) {
    return _patch('/api/doctor/profile', {
      'firstName': firstName,
      'lastName': lastName,
      'phone': phone,
      'email': email,
      'specialization': specialization,
      'hospitalAffiliation': hospitalAffiliation,
    });
  }

  static Future<Map<String, dynamic>> doctorProfile() =>
      _getObject('/api/doctor/profile');

  static Future<List<Map<String, dynamic>>> patientTelemetry() async {
    final response = await _get('/api/patient/telemetry');
    return response.cast<Map<String, dynamic>>();
  }

  static Future<Map<String, dynamic>> createPatientTelemetry({
    required double weight,
    required int bloodPressureSystolic,
    required int bloodPressureDiastolic,
    required double temperature,
    required double bloodGlucose,
  }) {
    return _post('/api/patient/telemetry', {
      'weight': weight,
      'bloodPressureSystolic': bloodPressureSystolic,
      'bloodPressureDiastolic': bloodPressureDiastolic,
      'temperature': temperature,
      'bloodGlucose': bloodGlucose,
    });
  }

  static Future<List<Map<String, dynamic>>> patientAppointments() async {
    final response = await _get('/api/patient/appointments');
    return response.cast<Map<String, dynamic>>();
  }

  static Future<Map<String, dynamic>> adminStats() =>
      _getObject('/api/admin/stats');

  static Future<List<Map<String, dynamic>>> adminDoctors() async {
    final response = await _get('/api/admin/doctors');
    return response.cast<Map<String, dynamic>>();
  }

  static Future<void> updateDoctorStatus({
    required String userId,
    required String status,
  }) async {
    await _patch('/api/admin/doctors/$userId/status', {'status': status});
  }

  static Future<List<Map<String, dynamic>>> adminPatients() async {
    final response = await _get('/api/admin/patients');
    return response.cast<Map<String, dynamic>>();
  }

  static Future<void> updatePatientStatus({
    required String userId,
    required String status,
  }) async {
    await _patch('/api/admin/patients/$userId/status', {'status': status});
  }

  static Future<List<Map<String, dynamic>>> adminActivityLogs() async {
    final response = await _get('/api/admin/activity-logs');
    return response.cast<Map<String, dynamic>>();
  }

  static Future<Map<String, dynamic>> createDoctor({
    required String email,
    required String password,
    required String firstName,
    String? lastName,
    String? specialization,
    String? hospitalAffiliation,
  }) {
    return _post('/api/admin/doctors', {
      'email': email,
      'password': password,
      'firstName': firstName,
      'lastName': lastName,
      'specialization': specialization,
      'hospitalAffiliation': hospitalAffiliation,
    });
  }

  static Future<List<Map<String, dynamic>>> notifications() async {
    final response = await _get('/api/notifications/');
    return response.cast<Map<String, dynamic>>();
  }

  static Future<int> unreadNotificationCount() async {
    final response = await _getObject('/api/notifications/unread-count');
    return (response['count'] as num?)?.toInt() ?? 0;
  }

  static Future<void> markNotificationRead(int id) async {
    await _post('/api/notifications/$id/read', {});
  }

  static Future<void> markAllNotificationsRead() async {
    await _post('/api/notifications/read-all', {});
  }

  static Future<List<dynamic>> _get(String path) async {
    final response = await _request(path);
    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const ApiException('Réponse invalide du serveur');
    }
    return decoded;
  }

  static Future<Map<String, dynamic>> _getObject(String path) async {
    final response = await _request(path);
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const ApiException('Réponse invalide du serveur');
    }
    return decoded;
  }

  static Future<http.Response> _request(String path) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl$path'),
        headers: {
          'content-type': 'application/json',
          if (_token != null) 'authorization': 'Bearer $_token',
        },
      );
      _ensureJsonResponse(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(_errorMessage(response));
      }
      return response;
    } on ApiException {
      rethrow;
    } on FormatException {
      throw const ApiException('Réponse invalide du serveur');
    } catch (_) {
      throw const ApiException('Serveur indisponible.');
    }
  }

  static Future<void> _patch(String path, Map<String, dynamic> body) async {
    try {
      final response = await http.patch(
        Uri.parse('$_baseUrl$path'),
        headers: {
          'content-type': 'application/json',
          if (_token != null) 'authorization': 'Bearer $_token',
        },
        body: jsonEncode(body),
      );
      _ensureJsonResponse(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(_errorMessage(response));
      }
    } on ApiException {
      rethrow;
    } on FormatException {
      throw const ApiException('Réponse invalide du serveur');
    } catch (_) {
      throw const ApiException(
        'Serveur indisponible. Vérifiez que le backend est démarré.',
      );
    }
  }

  static Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl$path'),
        headers: {
          'content-type': 'application/json',
          if (_token != null) 'authorization': 'Bearer $_token',
        },
        body: jsonEncode(body),
      );
      _ensureJsonResponse(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(_errorMessage(response));
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const ApiException('Réponse JSON invalide du serveur');
      }
      return decoded;
    } on ApiException {
      rethrow;
    } on FormatException {
      throw const ApiException('Réponse invalide du serveur');
    } catch (_) {
      throw const ApiException(
        'Serveur indisponible. Vérifiez que le backend est démarré.',
      );
    }
  }

  static void _ensureJsonResponse(http.Response response) {
    final contentType = response.headers['content-type']?.toLowerCase() ?? '';
    if (!contentType.contains('application/json')) {
      throw const ApiException('Le serveur a renvoyé une réponse non JSON');
    }
  }

  static String _errorMessage(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return (decoded['error'] ?? decoded['message'])?.toString() ??
            'Erreur serveur (${response.statusCode})';
      }
    } on FormatException {
      return 'Erreur serveur (${response.statusCode})';
    }
    return 'Erreur serveur (${response.statusCode})';
  }
}
