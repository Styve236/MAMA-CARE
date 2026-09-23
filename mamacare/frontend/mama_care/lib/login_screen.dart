import 'package:flutter/material.dart';
import 'services/api_client.dart';

// IMPORTS DES ÉCRANS DE DESTINATION
import 'package:mama_care/patiente/dashboard.dart';
import 'package:mama_care/medecin/doctor_dashboard_mobile.dart';
import 'package:mama_care/patiente/register_patiente.dart'; 
import 'package:mama_care/admin/admin_dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isObscure = true;
  bool _isLoading = false;
  final _emailController = TextEditingController(text: "test@mamacare.com");
  final _passwordController = TextEditingController(text: "123456");

  // Couleur Bordeaux officielle de Mamacare
  final Color burgundyColor = const Color(0xFF800020);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --- LOGIQUE DE CONNEXION UNIVERSELLE ---
  Future<void> _handleLogin() async {
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez remplir tous les champs")),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await ApiClient.login(email, password);
      if (!mounted) return;
      final userRole = response['user']['role'] as String?;
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

        default:
          throw const ApiException('Rôle utilisateur non reconnu');
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 80),

              // Logo circulaire
              Center(
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: Offset(0, 5),
                      ),
                    ],
                    image: DecorationImage(
                      image: AssetImage('assets/images/logo_mamacare.png'),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 50),

              // Champ Email
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email',
                  labelStyle: TextStyle(color: burgundyColor),
                  prefixIcon: Icon(Icons.email_outlined, color: burgundyColor),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: burgundyColor.withValues(alpha: 0.5)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: burgundyColor, width: 2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Champ Mot de passe
              TextFormField(
                controller: _passwordController,
                obscureText: _isObscure,
                decoration: InputDecoration(
                  labelText: 'Mot de passe',
                  labelStyle: TextStyle(color: burgundyColor),
                  prefixIcon: Icon(Icons.lock_outline, color: burgundyColor),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isObscure ? Icons.visibility_off : Icons.visibility,
                      color: burgundyColor,
                    ),
                    onPressed: () {
                      setState(() {
                        _isObscure = !_isObscure;
                      });
                    },
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: burgundyColor.withValues(alpha: 0.5)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: burgundyColor, width: 2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // Bouton Se connecter
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: burgundyColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 5,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Se connecter', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),

              const SizedBox(height: 40),

              // Lien Inscription (Dédié aux patientes)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Nouvelle patiente ?",
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context, 
                        MaterialPageRoute(builder: (context) => const RegisterPatiente()),
                      );
                    },
                    child: Text(
                      "Créer un compte",
                      style: TextStyle(
                        color: burgundyColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}