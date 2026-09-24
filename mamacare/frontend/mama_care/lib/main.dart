import 'package:flutter/material.dart';

import 'services/api_client.dart';
import 'shared/app_theme.dart';

// --- ÉCRAN D'ACCUEIL COMMUN ---

import 'welcome_screen.dart';
import 'login_screen.dart';
import 'notifications_screen.dart';

// --- IMPORTATIONS DES ÉCRANS PATIENTE ---

import 'patiente/register_patiente.dart';

import 'patiente/profil_config.dart';

import 'patiente/dashboard.dart';

import 'patiente/telemetry_input.dart';

import 'patiente/stats_screen.dart';

import 'patiente/ia_chatbot_screen.dart';

import 'patiente/doctor_messaging.dart';

import 'patiente/appointments_reminders_screen.dart';
import 'patiente/patiente_profile_screen.dart';

// --- IMPORTATIONS DES ÉCRANS MÉDECIN

import 'medecin/doctor_dashboard_mobile.dart';

import 'medecin/doctor_patiente_detail.dart';

import 'medecin/doctor_alerts_center.dart';

import 'medecin/doctor_messages_list.dart';
import 'medecin/doctor_profile_screen.dart';
//importation des ecrans admin
import 'admin/admin_dashboard_screen.dart';
import 'admin/admin_account_management_screen.dart';
import 'admin/admin_patient_accounts_screen.dart';
import 'admin/admin_doctor_accounts_screen.dart';
import 'admin/admin_assign_doctor_screen.dart';
import 'admin/admin_global_statistics_screen.dart';
import 'admin/admin_activity_log_entry_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await ApiClient.restoreSession();

  runApp(const MamaCareApp());
}

class MamaCareApp extends StatelessWidget {
  const MamaCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MamaCare',
      theme: AppTheme.light(),
      initialRoute: '/',

      routes: {
        // --- ACCUEIL COMMUN ---
        '/': (context) => const WelcomeScreen(),
        '/login': (context) => const LoginScreen(),
        '/notifications': (context) => const NotificationsScreen(),

        // --- PATIENTE ---
        '/patiente/register_patiente': (context) => const RegisterPatiente(),

        '/patiente/profil-config': (context) => const ProfilConfig(),

        '/patiente/dashboard': (context) => const Dashboard(),

        '/patiente/telemetry_input': (context) => const TelemetryInput(),

        '/patiente/stats_screen': (context) => const StatsScreen(),

        '/patiente/ia-chatbot_screen': (context) => const IAChatbotScreen(),

        '/patiente/doctor-messaging': (context) => const DoctorMessaging(),
        '/patiente/appointments_reminders_screen': (context) =>
            const AppointmentsRemindersScreen(),
        '/patiente/patiente_profile_sreen': (context) =>
            const PatienteProfileScreen(),

        // --- MÉDECIN ---
        '/medecin/doctor_dashboard_mobile': (context) =>
            const DoctorDashboardMobile(),

        '/medecin/doctor_patiente_detail': (context) =>
            const DoctorPatienteDetail(),

        '/medecin/doctor_alerts_center': (context) =>
            const DoctorAlertsCenter(),

        '/medecin/doctor_messages_list': (context) =>
            const DoctorMessagesList(),
        '/medecin/doctor_profile_screen': (context) =>
            const DoctorProfileScreen(),

        //admin
        '/admin/admin_dashboard_screen': (context) =>
            AdminDashboardScreen(
              onLogout: () {
                ApiClient.logout();
                Navigator.of(context)
                    .pushNamedAndRemoveUntil('/', (route) => false);
              },
            ),
        '/admin/admin_account_management_screen': (context) =>
            const AdminAccountManagementScreen(),
        '/admin/admin_patient_accounts_screen': (context) =>
            const AdminPatientAccountsScreen(),
        '/admin/admin_doctor_accounts_screen': (context) =>
            const AdminDoctorAccountsScreen(),
        '/admin/admin_assign_doctor_screen': (context) {
          final arguments =
              ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return AdminAssignDoctorScreen(
            initialPatientId: arguments?['initialPatientId'] as String?,
          );
        },
        '/admin/admin_global_statistics_screen': (context) =>
            const AdminGlobalStatisticsScreen(),
        '/admin/admin_activity_log_entry_screen': (context) =>
            const AdminActivityLogScreen(),
      },
    );
  }
}
