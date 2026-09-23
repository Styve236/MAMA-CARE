import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mama_care/services/api_client.dart';

class AdminGlobalStatisticsScreen extends StatefulWidget {
  const AdminGlobalStatisticsScreen({super.key});

  @override
  State<AdminGlobalStatisticsScreen> createState() => _AdminGlobalStatisticsScreenState();
}

class _AdminGlobalStatisticsScreenState extends State<AdminGlobalStatisticsScreen> {
  static const burgundy = Color(0xFF800020);
  static const background = Color(0xFFFCF9FA);
  Map<String, dynamic>? _stats;
  String? _error;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadStats();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) => _loadStats());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadStats() async {
    try {
      final stats = await ApiClient.adminStats();
      if (mounted) setState(() => _stats = stats);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: burgundy), onPressed: () => Navigator.of(context).maybePop()),
        title: const Text('Statistiques globales', style: TextStyle(color: burgundy, fontWeight: FontWeight.w700)),
      ),
      body: _error != null
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center)))
          : _stats == null
              ? const Center(child: CircularProgressIndicator(color: burgundy))
              : RefreshIndicator(
                  onRefresh: _loadStats,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      const Text('Vue globale de la plateforme', style: TextStyle(color: burgundy, fontSize: 21, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 18),
                      _buildStat('Patientes inscrites', 'total_patients', Icons.people_outline),
                      _buildStat('Médecins actifs', 'total_doctors', Icons.medical_services_outlined),
                      _buildStat('Alertes à traiter', 'total_alerts', Icons.warning_amber_outlined),
                      _buildStat('Rendez-vous planifiés', 'total_appointments', Icons.event_available_outlined),
                      _buildStat('Rendez-vous terminés', 'completed_appointments', Icons.task_alt),
                    ],
                  ),
                ),
    );
  }

  Widget _buildStat(String label, String key, IconData icon) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: const Color(0xFFF8EDF0), child: Icon(icon, color: burgundy)),
        title: Text(label),
        trailing: Text('${_stats![key] ?? 0}', style: const TextStyle(color: burgundy, fontSize: 22, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
