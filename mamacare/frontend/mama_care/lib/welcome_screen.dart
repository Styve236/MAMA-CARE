import 'dart:async';
import 'package:flutter/material.dart';
import 'shared/app_theme.dart';
import 'package:mama_care/login_screen.dart'; // Remplace par le chemin exact de ton écran de connexion universel

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
    // Redirection automatique après 2.5 secondes vers la page de connexion
    _redirectTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const LoginScreen(), // Ton écran de connexion universel
          ),
        );
      }
    });
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