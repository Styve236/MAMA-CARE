import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mama_care/services/api_client.dart';
import 'package:mama_care/medecin/doctor_patiente_detail.dart';
import 'package:mama_care/medecin/doctor_alerts_center.dart';
import 'package:mama_care/medecin/doctor_messages_list.dart';
import 'package:mama_care/medecin/doctor_profile_screen.dart';

class DoctorDashboardMobile extends StatefulWidget {
  final List<Map<String, dynamic>>? alerts;
  final List<Map<String, dynamic>>? patients;
  final Map<String, int>? stats;

  const DoctorDashboardMobile({
    super.key,
    this.alerts,
    this.patients,
    this.stats,
  });

  @override
  State<DoctorDashboardMobile> createState() => _DoctorDashboardMobileState();
}

class _DoctorDashboardMobileState extends State<DoctorDashboardMobile> {
  static const Color burgundy = Color(0xFF800020);
  int _currentIndex = 0;
  List<Map<String, dynamic>> _patients = [];
  bool _loading = true;
  String? _error;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadPatients();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _loadPatients(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPatients() async {
    try {
      final patients = await ApiClient.doctorPatients();
      if (mounted) {
        setState(() {
          _patients = patients;
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

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      _buildDashboardHome(),
      const DoctorPatienteDetail(),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatsRow(),
          const SizedBox(height: 30),
          _buildSectionHeader('Alertes IA prioritaires', Icons.stars),
          const SizedBox(height: 12),
          Column(
            children: [
              if (_patients.isEmpty)
                const Text('Aucune patiente affectée pour le moment.')
              else
                ..._patients
                    .take(3)
                    .map((patient) => _buildPatientCard(patient)),
            ],
          ),
          const SizedBox(height: 30),
          _buildSectionHeader('Patientes récentes', Icons.people_alt),
          const SizedBox(height: 12),
          Column(
            children: [
              if (_patients.isEmpty)
                const Text('Aucune patiente récente.')
              else
                ..._patients.take(3).map(_buildPatientCard),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildStatCard('Patientes', '${_patients.length}', Icons.person),
        _buildStatCard('Alertes', '0', Icons.warning_amber_rounded),
        _buildStatCard('Messages', '0', Icons.chat_bubble_outline),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.28,
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
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
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

  Widget _buildSectionHeader(String title, IconData icon) {
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
        const Text(
          'Voir tout >',
          style: TextStyle(
            color: burgundy,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildPatientCard(Map<String, dynamic> patient) {
    final firstName = patient['first_name'] ?? '';
    final lastName = patient['last_name'] ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: burgundy.withValues(alpha: 0.1),
            child: const Icon(Icons.person, color: burgundy),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              '$firstName $lastName'.trim().isEmpty
                  ? 'Patiente sans nom'
                  : '$firstName $lastName',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.grey),
        ],
      ),
    );
  }
}
