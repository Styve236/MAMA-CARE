# MamaCare - Frontend/Backend Integration Guide

## Frontend Configuration

### 1. Update Flutter App to Use Backend API

#### Step 1: Create API Service
Create `lib/services/api_service.dart`:

```dart
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:3000/api';
  // For production, change to: 'https://api.mamacare.com/api'
  
  final _storage = FlutterSecureStorage();

  // Authentication Endpoints
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String role,
    String? phone,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'firstName': firstName,
        'lastName': lastName,
        'role': role,
        'phone': phone,
      }),
    );
    
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    final result = _handleResponse(response);
    if (result.containsKey('token')) {
      await _storage.write(key: 'auth_token', value: result['token']);
    }
    return result;
  }

  Future<void> logout() async {
    await _storage.delete(key: 'auth_token');
  }

  // Patient Endpoints
  Future<Map<String, dynamic>> getPatientProfile() async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/patient/profile'),
      headers: _getHeaders(token),
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> recordTelemetry({
    required double weight,
    required int bloodPressureSystolic,
    required int bloodPressureDiastolic,
    required int heartRate,
    required double bloodGlucose,
    required double temperature,
    String? notes,
  }) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/patient/telemetry'),
      headers: _getHeaders(token),
      body: jsonEncode({
        'weight': weight,
        'bloodPressureSystolic': bloodPressureSystolic,
        'bloodPressureDiastolic': bloodPressureDiastolic,
        'heartRate': heartRate,
        'bloodGlucose': bloodGlucose,
        'temperature': temperature,
        'notes': notes,
      }),
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> getTelemetry({int limit = 50, int offset = 0}) async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/patient/telemetry?limit=$limit&offset=$offset'),
      headers: _getHeaders(token),
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> getAppointments({bool upcomingOnly = false}) async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/patient/appointments?upcomingOnly=$upcomingOnly'),
      headers: _getHeaders(token),
    );
    return _handleResponse(response);
  }

  // Doctor Endpoints
  Future<Map<String, dynamic>> getDoctorPatients() async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/doctor/patients'),
      headers: _getHeaders(token),
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> getDoctorAlerts({bool unreadOnly = false}) async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/doctor/alerts?unreadOnly=$unreadOnly'),
      headers: _getHeaders(token),
    );
    return _handleResponse(response);
  }

  // Admin Endpoints
  Future<Map<String, dynamic>> getAdminStats() async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/admin/stats'),
      headers: _getHeaders(token),
    );
    return _handleResponse(response);
  }

  // Helper Methods
  Future<String?> _getToken() async {
    return await _storage.read(key: 'auth_token');
  }

  Map<String, String> _getHeaders(String? token) {
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    final data = jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'API Error');
    }
  }
}
```

#### Step 2: Update Login Screen

Replace login logic in `lib/login_screen.dart`:

```dart
void _handleLogin() async {
  String email = _emailController.text.trim();
  String password = _passwordController.text.trim();

  if (email.isEmpty || password.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Veuillez remplir tous les champs")),
    );
    return;
  }

  try {
    final apiService = ApiService();
    final response = await apiService.login(email: email, password: password);
    
    if (response.containsKey('user')) {
      final user = response['user'];
      String userRole = user['role'] ?? 'patiente';

      // REDIRECTION EN FONCTION DU RÔLE
      switch (userRole) {
        case 'patiente':
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const Dashboard()),
            (route) => false,
          );
          break;
        case 'medecin':
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const DoctorDashboardMobile()),
            (route) => false,
          );
          break;
        case 'admin':
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const AdminDashboardScreen()),
            (route) => false,
          );
          break;
      }
    }
  } catch (error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Erreur: ${error.toString()}")),
    );
  }
}
```

#### Step 3: Update pubspec.yaml

Add HTTP client dependency:

```yaml
dependencies:
  http: ^1.1.0
  flutter_secure_storage: ^9.0.0
```

### 2. Update Main.dart

Remove hardcoded Supabase initialization if not needed, or keep it for additional features:

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Optional: Keep Supabase for real-time features
  // await Supabase.initialize(
  //   url: 'https://oqozwhtrwlrbduihtnec.supabase.co',
  //   publishableKey: 'sb_publishable_JxZcZ3XPnWU7ShxT8eGRAw_k-cdRVjs',
  // );

  runApp(const MamaCareApp());
}
```

## Backend Configuration

### 1. Enable CORS for Flutter App

Update `src/server.js`:

```javascript
const corsOptions = {
  origin: [
    'http://localhost:3000',     // Web
    'http://10.0.2.2:3000',      // Android emulator
    'http://127.0.0.1:3000',     // iOS simulator
    'https://yourdomain.com',    // Production
  ],
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
};

app.use(cors(corsOptions));
```

### 2. Environment Setup for Mobile Testing

`.env` for local development:

```env
PORT=3000
NODE_ENV=development
DB_HOST=localhost
DB_PORT=5432
DB_NAME=mamacare_db
DB_USER=postgres
DB_PASSWORD=password
JWT_SECRET=dev_secret_key_change_in_production
```

## Development Workflow

### 1. Start PostgreSQL
```bash
# Windows (if using Chocolatey)
pg_ctl -D "C:\Program Files\PostgreSQL\15\data" start

# macOS
brew services start postgresql

# Linux
sudo service postgresql start
```

### 2. Start Backend
```bash
cd backend
npm install
npm run dev
```

### 3. Run Flutter App
```bash
cd mamacare/frontend/mama_care
flutter pub get
flutter run
```

## API Integration Checklist

- [ ] Create `ApiService` class
- [ ] Add HTTP package to `pubspec.yaml`
- [ ] Add flutter_secure_storage for token management
- [ ] Update login/registration screens
- [ ] Update patient dashboard to fetch real data
- [ ] Update doctor dashboard to fetch patient list
- [ ] Update admin dashboard for statistics
- [ ] Add error handling and loading states
- [ ] Configure CORS on backend
- [ ] Test with real backend

## Testing

### 1. Test Authentication
```dart
final apiService = ApiService();
final response = await apiService.login(
  email: 'test@mamacare.com',
  password: '123456'
);
print(response); // Should contain token and user data
```

### 2. Test Patient Endpoints
```dart
final telemetry = await apiService.recordTelemetry(
  weight: 70.5,
  bloodPressureSystolic: 120,
  bloodPressureDiastolic: 80,
  heartRate: 75,
  bloodGlucose: 95,
  temperature: 36.8,
);
```

## Troubleshooting

### Connection Refused
- Ensure backend is running on port 3000
- Check firewall settings
- For Android emulator: use `10.0.2.2` instead of `localhost`

### CORS Errors
- Update CORS configuration in backend
- Ensure headers match between frontend and backend

### Token Issues
- Verify token is stored correctly in secure storage
- Check token format in headers

---

**Version**: 1.0.0  
**Last Updated**: 2024-08-31
