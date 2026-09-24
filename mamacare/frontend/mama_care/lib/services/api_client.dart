import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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
  static Map<String, dynamic>? _user;
  static const _kTokenKey = 'mamacare_auth_token';
  static const _kUserKey = 'mamacare_auth_user';

  static bool get isLoggedIn => _token != null && _token!.isNotEmpty;
  static Map<String, dynamic>? get currentUser => _user;

  static Future<void> restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_kTokenKey);
      final userJson = prefs.getString(_kUserKey);
      if (token == null || token.isEmpty) return;
      _token = token;
      if (userJson != null) {
        try {
          final decoded = jsonDecode(userJson);
          if (decoded is Map<String, dynamic>) _user = decoded;
        } on FormatException {
          _user = null;
        }
      }
    } catch (_) {
      // Le démarrage ne doit jamais échouer pour la restauration.
    }
  }

  static Future<void> _persistSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_token == null || _token!.isEmpty) {
        await prefs.remove(_kTokenKey);
        await prefs.remove(_kUserKey);
        return;
      }
      await prefs.setString(_kTokenKey, _token!);
      if (_user != null) await prefs.setString(_kUserKey, jsonEncode(_user));
    } catch (_) {
      // Silencieux : la persistance est un confort, pas une contrainte.
    }
  }

  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    final response = await _post('/api/auth/login', {
      'email': email,
      'password': password,
    });
    _token = response['token'] as String?;
    final user = response['user'];
    if (user is Map<String, dynamic>) _user = user;
    await _persistSession();
    return response;
  }

  static Future<void> logout() async {
    _token = null;
    _user = null;
    await _persistSession();
  }

  static Future<void> verifySession() async {
    await _getObject('/api/auth/verify');
  }

  static Future<String> sendChatMessage(String message) async {
    final response = await _post('/api/chat/', {'message': message});
    return (response['reply'] as String?) ?? 'Aucune réponse de l\'assistant.';
  }

  static Future<List<Map<String, dynamic>>> patientChatHistory() async {
    final response = await _get('/api/chat/history');
    return response.cast<Map<String, dynamic>>();
  }

  static Future<Map<String, dynamic>> patientHealthState() =>
      _getObject('/api/patient/health-state');

  static Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String firstName,
    String? lastName,
    String? phone,
  }) async {
    final response = await _post('/api/auth/register', {
      'email': email,
      'password': password,
      'role': 'patiente',
      'firstName': firstName,
      'lastName': lastName,
      'phone': phone,
    });
    _token = response['token'] as String?;
    final user = response['user'];
    if (user is Map<String, dynamic>) _user = user;
    await _persistSession();
    return response;
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

  static Future<Map<String, dynamic>> doctorStats() =>
      _getObject('/api/doctor/stats');

  static Future<List<Map<String, dynamic>>> doctorAlerts() async {
    final response = await _get('/api/doctor/alerts');
    return response.cast<Map<String, dynamic>>();
  }

  static Future<int> doctorAlertUnreadCount() async {
    final response = await _getObject('/api/doctor/alerts/unread-count');
    return (response['count'] as num?)?.toInt() ?? 0;
  }

  static Future<void> markDoctorAlertRead(int id) async {
    await _patch('/api/doctor/alerts/$id/read', {});
  }

  static Future<Map<String, dynamic>> doctorPatientDetail(String patientId) =>
      _getObject('/api/doctor/patients/$patientId');

  static Future<List<Map<String, dynamic>>> doctorMessageThreads() async {
    final response = await _get('/api/doctor/messages');
    return response.cast<Map<String, dynamic>>();
  }

  static Future<Map<String, dynamic>> doctorMessageThread(
    String patientUserId,
  ) =>
      _getObject('/api/doctor/messages/$patientUserId');

  static Future<Map<String, dynamic>> sendDoctorMessage({
    required String patientUserId,
    required String message,
  }) =>
      _post('/api/doctor/messages', {
        'patientUserId': patientUserId,
        'message': message,
      });

  static Future<void> markDoctorThreadRead(String patientUserId) async {
    await _post('/api/doctor/messages/$patientUserId/read', {});
  }

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

  static Future<Map<String, dynamic>> createPatientAppointment({
    required DateTime appointmentDate,
    int? durationMinutes,
    String? notes,
  }) {
    return _post('/api/patient/appointments', {
      'appointmentDate': appointmentDate.toUtc().toIso8601String(),
      'durationMinutes': durationMinutes,
      'notes': notes,
    });
  }

  static Future<Map<String, dynamic>> patientAcceptAppointment(int id) {
    return _patchObject('/api/patient/appointments/$id/accept', {});
  }

  static Future<List<Map<String, dynamic>>> doctorAppointmentRequests() async {
    final response = await _get('/api/doctor/appointments/requests');
    return response.cast<Map<String, dynamic>>();
  }

  static Future<Map<String, dynamic>> doctorAcceptAppointment(int id) {
    return _patchObject('/api/doctor/appointments/$id/accept', {});
  }

  static Future<Map<String, dynamic>> doctorRejectAppointment(
    int id, {
    String? reason,
  }) {
    return _patchObject('/api/doctor/appointments/$id/reject', {
      if (reason != null && reason.trim().isNotEmpty) 'message': reason,
    });
  }

  static Future<Map<String, dynamic>> doctorRescheduleAppointment(
    int id,
    DateTime newDate, {
    String? reason,
  }) {
    return _patchObject('/api/doctor/appointments/$id/reschedule', {
      'newDate': newDate.toUtc().toIso8601String(),
      if (reason != null && reason.trim().isNotEmpty) 'message': reason,
    });
  }

  static Future<int> patientMessageUnreadCount() async {
    final response = await _getObject('/api/patient/messages/unread-count');
    return (response['count'] as num?)?.toInt() ?? 0;
  }

  static Future<void> markPatientMessagesRead() async {
    await _post('/api/patient/messages/read', {});
  }

  static Future<Map<String, dynamic>> patientMessages() =>
      _getObject('/api/patient/messages');

  static Future<Map<String, dynamic>> sendPatientMessage(String message) =>
      _post('/api/patient/messages', {'message': message});

  static Future<List<Map<String, dynamic>>> patientReminders() async {
    final response = await _get('/api/patient/reminders');
    return response.cast<Map<String, dynamic>>();
  }

  static Future<Map<String, dynamic>> createPatientReminder({
    required String title,
    required DateTime reminderDate,
  }) {
    return _post('/api/patient/reminders', {
      'title': title,
      'reminderDate': reminderDate.toUtc().toIso8601String(),
    });
  }

  static Future<void> setPatientReminderDone(int id, bool isDone) async {
    await _patch('/api/patient/reminders/$id', {'isDone': isDone});
  }

  static Future<void> deletePatientReminder(int id) async {
    await _delete('/api/patient/reminders/$id');
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

  static Future<void> adminAssignDoctor({
    required String userId,
    int? doctorId,
  }) async {
    await _patch('/api/admin/patients/$userId/assign-doctor', {
      'doctorId': doctorId,
    });
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

  static Future<Map<String, dynamic>> _patchObject(
    String path,
    Map<String, dynamic> body,
  ) async {
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

  static Future<void> _delete(String path) async {
    try {
      final response = await http.delete(
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
