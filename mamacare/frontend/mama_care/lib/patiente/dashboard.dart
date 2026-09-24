import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mama_care/services/api_client.dart';
import 'package:mama_care/patiente/stats_screen.dart';
import 'package:mama_care/patiente/ia_chatbot_screen.dart';
import 'package:mama_care/patiente/doctor_messaging.dart';
import 'package:mama_care/patiente/appointments_reminders_screen.dart';
import 'package:mama_care/patiente/telemetry_input.dart';
import 'package:mama_care/patiente/patiente_profile_screen.dart'; // Import de ton écran profil séparé
import 'package:mama_care/shared/date_utils.dart';

const Color burgundyColor = Color(0xFF6B1D2F);

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  // --- VARIABLES D'ÉTAT DU TABLEAU DE BORD ---
  String patientName = "";
  String pregnancyWeek = "--";
  String lastTension = "--/--";
  String lastWeight = "--";
  String lastGlycemia = "--";
  String nextAppointmentDate = "Aucun rendez-vous prévu";
  String doctorName = "En attente d'affectation";

  int _selectedIndex = 0;
  int _unreadMessages = 0;
  Map<String, dynamic>? _healthState;

  // LISTE DES 5 ÉCRANS LIÉS AUX 5 ONGLETS DU BAS
  List<Widget> _pages(BuildContext context) => [
        _buildAccueil(context),        // Index 0 : Accueil
        const StatsScreen(),           // Index 1 : Statistiques
        const IAChatbotScreen(),       // Index 2 : Chatbot IA
        const DoctorMessaging(),       // Index 3 : Messagerie
        const PatienteProfileScreen(), // Index 4 : Ton écran de profil
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      // Affichage dynamique de l'écran selon l'onglet cliqué
      body: _pages(context)[_selectedIndex],

      // Configuration de la barre de navigation du bas
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed, // Maintient les 5 onglets lisibles
        selectedItemColor: burgundyColor,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Accueil',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Stats',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: 'AI Chat',
          ),
          BottomNavigationBarItem(
            icon: Badge(
              isLabelVisible: _unreadMessages > 0,
              label: Text('$_unreadMessages'),
              child: const Icon(Icons.message),
            ),
            label: 'Messages',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
  Timer? _refreshTimer;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _refreshDashboard();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _refreshDashboard();
    });
  }

  Future<void> _refreshDashboard() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    try {
      final results = await Future.wait([
        ApiClient.patientProfile(),
        ApiClient.patientTelemetry(),
        ApiClient.patientAppointments(),
        ApiClient.patientMessageUnreadCount(),
        ApiClient.patientHealthState(),
      ]);
      if (!mounted) return;

      final profile = results[0] as Map<String, dynamic>;
      final telemetry = results[1] as List<Map<String, dynamic>>;
      final appointments = results[2] as List<Map<String, dynamic>>;
      final latestTelemetry = telemetry.isEmpty ? null : telemetry.first;
      final upcomingAppointment = appointments.isEmpty ? null : appointments.first;

      setState(() {
        _unreadMessages = results[3] as int;
        _healthState = results[4] as Map<String, dynamic>;
        patientName = [profile['first_name'], profile['last_name']]
            .whereType<String>()
            .where((value) => value.isNotEmpty)
            .join(' ');
        pregnancyWeek = '${profile['pregnancy_weeks'] ?? '--'}';
        lastTension = latestTelemetry == null
            ? '--/--'
            : '${latestTelemetry['blood_pressure_systolic'] ?? '--'}/${latestTelemetry['blood_pressure_diastolic'] ?? '--'}';
        lastWeight = '${latestTelemetry?['weight'] ?? '--'}';
        lastGlycemia = '${latestTelemetry?['blood_glucose'] ?? '--'}';
        nextAppointmentDate = upcomingAppointment == null
            ? 'Aucun rendez-vous prévu'
            : '${upcomingAppointment['appointment_date'] ?? 'Date inconnue'}';
        doctorName = upcomingAppointment == null
            ? 'En attente d’affectation'
            : '${upcomingAppointment['doctor_first_name'] ?? ''} ${upcomingAppointment['doctor_last_name'] ?? ''}'.trim();
      });
    } on ApiException {
      return;
    } finally {
      _isRefreshing = false;
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  // --- LOGIQUE ET DESIGN DE VOTRE ÉCRAN D'ACCUEIL (INDEX 0) ---
  Widget _buildAccueil(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER : LOGO & NOTIFICATIONS
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Image.asset('assets/images/logo_mamacare.png', height: 90),
                IconButton(
                  icon: const Icon(Icons.notifications_none, color: burgundyColor, size: 30),
                  onPressed: () => Navigator.pushNamed(context, '/notifications'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Center(
              child: Image.asset(
                'assets/images/femme_enceinte.png',
                height: 140,
              ),
            ),
            const SizedBox(height: 20),

            // SALUTATIONS
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 230, 200, 201),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: const Color.fromARGB(255, 207, 147, 150), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Bonjour, $patientName",
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: burgundyColor),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Semaine de grossesse : $pregnancyWeek",
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: burgundyColor),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),

            // ANALYSE IA DE L'ÉTAT DE SANTÉ
            _buildHealthStateCard(),
            const SizedBox(height: 25),

            // CARTES DES CONSTANTES
            const Text(
              "Vos dernières constantes",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: burgundyColor),
            ),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildConstanteCard("Tension", lastTension, Icons.favorite, Colors.red),
                _buildConstanteCard("Poids", "$lastWeight kg", Icons.scale, Colors.blue),
                _buildConstanteCard("Glycémie", "$lastGlycemia g/L", Icons.bloodtype, Colors.orange),
              ],
            ),
            const SizedBox(height: 30),

            // BOUTON AJOUTER MESURE
            _buildActionButton(),
            const SizedBox(height: 30),

            // BLOC RENDEZ-VOUS TOTALEMENT CLIQUABLE ET RELIÉ À L'AGENDA
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AppointmentsRemindersScreen(
                      appointments: [],
                      reminders: [],
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, color: burgundyColor),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nextAppointmentDate,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Text(
                            doctorName,
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 16, color: burgundyColor),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConstanteCard(String title, String value, IconData icon, Color color) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 5),
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 5),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildHealthStateCard() {
    final state = _healthState;
    if (state == null) return const SizedBox.shrink();

    final status = '${state['status']}';
    final noAnalysis = status == 'aucune';
    final Color cardColor;
    final Color iconColor;
    final IconData icon;
    final String label;
    if (noAnalysis) {
      cardColor = const Color(0xFFF0E7E9);
      iconColor = Colors.grey;
      icon = Icons.health_and_safety_outlined;
      label = 'Pas encore de bilan';
    } else {
      switch (status) {
        case 'malaise':
          cardColor = const Color(0xFFB3261E);
          iconColor = Colors.white;
          icon = Icons.emergency;
          label = 'Risque de malaise';
          break;
        case 'grave':
          cardColor = const Color(0xFFB3261E);
          iconColor = Colors.white;
          icon = Icons.warning_amber;
          label = 'État grave';
          break;
        case 'preoccupant':
          cardColor = const Color(0xFFB54708);
          iconColor = Colors.white;
          icon = Icons.notifications_active;
          label = 'État préoccupant';
          break;
        default:
          cardColor = const Color(0xFF2E7D32);
          iconColor = Colors.white;
          icon = Icons.check_circle;
          label = 'Bonne santé';
      }
    }

    final analyzedAt = timeAgo(state['analyzed_at']);
    final message = noAnalysis
        ? '${state['message']}'
        : '${state['patient_message'] ?? state['summary'] ?? ''}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: cardColor.withValues(alpha: noAnalysis ? 0 : 0.3),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: noAnalysis ? Colors.black87 : Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (analyzedAt.isNotEmpty && !noAnalysis)
                Text(
                  analyzedAt,
                  style: TextStyle(
                    color: noAnalysis ? Colors.grey : Colors.white70,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              message,
              style: TextStyle(
                color: noAnalysis ? Colors.black87 : Colors.white,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: burgundyColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const TelemetryInput()));
        },
        child: const Text(
          "+ Ajouter mes mesures",
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}