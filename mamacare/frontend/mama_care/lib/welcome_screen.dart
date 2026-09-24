import 'dart:async';
import 'package:flutter/material.dart';
import 'shared/app_theme.dart';
import 'package:mama_care/login_screen.dart';
import 'package:mama_care/services/api_client.dart';
import 'package:mama_care/patiente/dashboard.dart';
import 'package:mama_care/medecin/doctor_dashboard_mobile.dart';
import 'package:mama_care/admin/admin_dashboard_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  // Couleur bordeaux officielle MamaCare
  static const Color burgundy = AppColors.burgundy;
  Timer? _redirectTimer;

  @override
  void initState() {
    super.initState();
    // Redirection automatique après 2.5 secondes :
    // vers le tableau de bord du rôle si une session est active,
    // sinon vers la page de connexion.
    _redirectTimer = Timer(const Duration(milliseconds: 2500), () async {
      if (!mounted) return;
      if (ApiClient.isLoggedIn) {
        final role = '${ApiClient.currentUser?['role'] ?? ''}';
        try {
          await ApiClient.verifySession();
          if (!mounted) return;
          _openHomeForRole(role);
          return;
        } on ApiException {
          await ApiClient.logout();
        }
      }
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    });
  }

  void _openHomeForRole(String role) {
    Widget home;
    switch (role) {
      case 'medecin':
        home = const DoctorDashboardMobile();
        break;
      case 'admin':
        home = AdminDashboardScreen(
          onLogout: () {
            ApiClient.logout();
            Navigator.of(context)
                .pushNamedAndRemoveUntil('/', (route) => false);
          },
        );
        break;
      case 'patiente':
      default:
        home = const Dashboard();
        break;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => home),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _redirectTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // LOGO MAMACARE
              const Icon(
                Icons.favorite,
                color: burgundy,
                size: 120,
              ),
              const SizedBox(height: 20),
              
              // TITRE
              const Text(
                'MamaCare',
                style: TextStyle(
                  color: burgundy,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 10),
              
              // SOUS-TITRE
              const Text(
                'Le suivi intelligent de votre grossesse',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 40),

              // INDICATEUR DE CHARGEMENT DISCRET
              const CircularProgressIndicator(
                color: burgundy,
                strokeWidth: 2.5,
              ),
            ],
          ),
        ),
      ),
    );
  }
}