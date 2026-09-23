import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mama_care/services/api_client.dart';
import 'package:mama_care/medecin/doctor_patiente_detail.dart';
import 'package:mama_care/medecin/doctor_alerts_center.dart';
import 'package:mama_care/medecin/doctor_messages_list.dart';
import 'package:mama_care/medecin/doctor_profile_screen.dart';
import 'package:mama_care/medecin/widgets_patient_list_tab.dart';

class DoctorDashboardMobile extends StatefulWidget {
  const DoctorDashboardMobile({super.key});

  @override
  State<DoctorDashboardMobile> createState() => _DoctorDashboardMobileState();
}

class _DoctorDashboardMobileState extends State<DoctorDashboardMobile> {
  static const Color burgundy = Color(0xFF800020);
  int _currentIndex = 0;
  List<Map<String, dynamic>> _patients = [];
  List<Map<String, dynamic>> _alerts = [];
  Map<String, int> _stats = const {'patients': 0, 'alerts': 0, 'messages': 0};
  bool _loading = true;
  String? _error;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _loadData(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        ApiClient.doctorPatients(),
        ApiClient.doctorAlerts(),
        ApiClient.doctorStats(),
      ]);
      if (mounted) {
        setState(() {
          _patients = (results[0] as List).cast<Map<String, dynamic>>();
          _alerts = (results[1] as List).cast<Map<String, dynamic>>();
          final stats = results[2] as Map<String, dynamic>;
          _stats = {
            'patients': (stats['patients'] as num?)?.toInt() ?? _patients.length,
            'alerts': (stats['alerts'] as num?)?.toInt() ?? 0,
            'messages': (stats['messages'] as num?)?.toInt() ?? 0,
          };
          _loading = false;
        });
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _loading = false;
        });
      }
    }
  }

  void _openPatient(Map<String, dynamic> patient) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DoctorPatienteDetail(
          patientId: '${patient['id']}',
          patientName:
              '${patient['first_name']} ${patient['last_name']}'.trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      _buildDashboardHome(),
      PatientsListTab(patients: _patients, onSelect: _openPatient),
      const DoctorAlertsCenter(),
      const DoctorMessagesList(),
      const DoctorProfileScreen(),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: _currentIndex == 0
            ? AppBar(
                backgroundColor: Colors.white,
                elevation: 0,
                automaticallyImplyLeading: false,
                title: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tableau de bord',
                      style: TextStyle(
                        color: burgundy,
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                    ),
                    Text(
                      'Suivi médical actif',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ],
                ),
                actions: [
                  IconButton(
                    icon: const Icon(
                      Icons.notifications_none,
                      color: burgundy,
                      size: 28,
                    ),
                    onPressed: () =>
                        Navigator.pushNamed(context, '/notifications'),
                  ),
                ],
              )
            : null,
        body: IndexedStack(index: _currentIndex, children: pages),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          selectedItemColor: burgundy,
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Accueil'),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              label: 'Patientes',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.gpp_maybe_outlined),
              label: 'Alertes',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline),
              label: 'Messages',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_circle_outlined),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardHome() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildStatsRow(),
          const SizedBox(height: 30),
          _buildSectionHeader(
            'Alertes IA prioritaires',
            Icons.stars,
            onSeeAll: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DoctorAlertsCenter()),
            ),
          ),
          const SizedBox(height: 12),
          if (_alerts.isEmpty)
            const Text('Aucune alerte IA pour le moment.',
                style: TextStyle(color: Colors.grey))
          else
            ..._alerts.take(3).map(_buildAlertTile),
          const SizedBox(height: 30),
          _buildSectionHeader('Patientes récentes', Icons.people_alt),
          const SizedBox(height: 12),
          if (_patients.isEmpty)
            const Text('Aucune patiente affectée pour le moment.',
                style: TextStyle(color: Colors.grey))
          else
            ..._patients.take(4).map(_buildPatientCard),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    final stats = [
      ('Patientes', '${_stats['patients'] ?? 0}', Icons.person),
      ('Alertes IA', '${_stats['alerts'] ?? 0}', Icons.notifications_active),
      ('Messages', '${_stats['messages'] ?? 0}', Icons.chat_bubble_outline),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: stats
          .map((s) => _buildStatCard(s.$1, s.$2, s.$3))
          .toList(),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    final width = (MediaQuery.of(context).size.width - 40 - 24) / 3;
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        children: [
          Icon(icon, color: burgundy, size: 24),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: burgundy,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    String title,
    IconData icon, {
    VoidCallback? onSeeAll,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: burgundy, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        if (onSeeAll != null)
          InkWell(
            onTap: onSeeAll,
            child: const Text(
              'Voir tout >',
              style: TextStyle(
                color: burgundy,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Color _severityColor(String? severity) {
    switch (severity) {
      case 'critical':
        return const Color(0xFFB3261E);
      case 'warning':
        return const Color(0xFFB54708);
      default:
        return burgundy;
    }
  }

  Widget _buildAlertTile(Map<String, dynamic> alert) {
    final color = _severityColor(alert['severity'] as String?);
    final name = '${alert['first_name']} ${alert['last_name']}'.trim();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(Icons.pregnant_woman, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? 'Patiente' : name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  alert['message'] as String? ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Colors.grey),
            onPressed: () {
              final patientId = '${alert['patient_id']}';
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DoctorPatienteDetail(
                    patientId: patientId,
                    patientName: name,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPatientCard(Map<String, dynamic> patient) {
    final firstName = patient['first_name'] ?? '';
    final lastName = patient['last_name'] ?? '';
    final weeks = patient['pregnancy_weeks'];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openPatient(patient),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: burgundy.withValues(alpha: 0.1),
              child: const Icon(Icons.person, color: burgundy),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$firstName $lastName'.trim().isEmpty
                        ? 'Patiente sans nom'
                        : '$firstName $lastName',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  if (weeks != null)
                    Text(
                      '$weeks semaine${weeks == 1 ? '' : 's'} de grossesse',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}