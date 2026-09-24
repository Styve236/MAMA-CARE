import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mama_care/services/api_client.dart';

import '../shared/app_theme.dart';
import '../shared/dashboard_charts.dart';

class AdminGlobalStatisticsScreen extends StatefulWidget {
  const AdminGlobalStatisticsScreen({super.key});

  @override
  State<AdminGlobalStatisticsScreen> createState() =>
      _AdminGlobalStatisticsScreenState();
}

class _AdminGlobalStatisticsScreenState
    extends State<AdminGlobalStatisticsScreen> {
  static const burgundy = AppColors.burgundy;
  static const background = Color(0xFFFCF9FA);
  Map<String, dynamic>? _stats;
  String? _error;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadStats();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _loadStats(),
    );
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

  List<Map<String, dynamic>> _list(String key) =>
      (_stats?[key] as List? ?? []).cast<Map<String, dynamic>>();

  Color _colorSeverity(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return colorCritical;
      case 'warning':
        return colorWarning;
      case 'normal':
        return colorOk;
      default:
        return colorInfo;
    }
  }

  String _labelStatus(String status) {
    switch (status.toLowerCase()) {
      case 'verified':
        return 'Vérifiées';
      case 'pending':
        return 'En attente';
      case 'blocked':
        return 'Bloquées';
      case 'suspended':
        return 'Suspendues';
      case 'scheduled':
        return 'Planifiés';
      case 'completed':
        return 'Terminés';
      case 'cancelled':
        return 'Annulés';
      default:
        return status;
    }
  }

  String _labelSeverity(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return 'Critiques';
      case 'warning':
        return 'Modérées';
      case 'normal':
        return 'Normales';
      default:
        return 'Info';
    }
  }

  Color _colorStatus(String status) {
    switch (status.toLowerCase()) {
      case 'verified':
      case 'completed':
        return colorOk;
      case 'pending':
      case 'scheduled':
        return colorInfo;
      case 'cancelled':
      case 'blocked':
      case 'suspended':
        return colorCritical;
      default:
        return burgundy;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: burgundy),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'Statistiques globales',
          style: TextStyle(color: burgundy, fontWeight: FontWeight.w700),
        ),
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            )
          : _stats == null
              ? const Center(child: CircularProgressIndicator(color: burgundy))
              : RefreshIndicator(
                  onRefresh: _loadStats,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      const Text(
                        'Vue globale de la plateforme',
                        style: TextStyle(
                          color: burgundy,
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Vos indicateurs mis à jour en temps réel.',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                      const SizedBox(height: 18),
                      _buildKpiGrid(),
                      const SizedBox(height: 18),
                      _buildRegistrationsCard(),
                      const SizedBox(height: 18),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildSeverityDonut()),
                          const SizedBox(width: 12),
                          Expanded(child: _buildAppointmentsDonut()),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _buildPatientsStatusCard(),
                      const SizedBox(height: 18),
                      _buildDoctorsRankCard(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildKpiGrid() {
    final items = [
      ('Patientes inscrites', 'total_patients', Icons.people_outline),
      ('Médecins actifs', 'total_doctors', Icons.medical_services_outlined),
      ('Alertes à traiter', 'total_alerts', Icons.warning_amber_outlined),
      ('Rendez-vous', 'total_appointments', Icons.event_available_outlined),
      ('Comptes au total', 'total_users', Icons.trending_up),
      ('RDV terminés', 'completed_appointments', Icons.task_alt),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.35,
      children: [
        for (final it in items)
          KpiCard(
            icon: it.$3,
            label: it.$1,
            value: '${_stats![it.$2] ?? 0}',
          ),
      ],
    );
  }

  Widget _buildRegistrationsCard() {
    final trend = _list('registrations_trend');
    final points = [
      for (final row in trend)
        ChartPoint(
          row['date'] ?? '',
          (row['count'] as num?)?.toDouble(),
        ),
    ];
    return ChartCardShell(
      title: 'Inscriptions — 14 derniers jours',
      subtitle: 'Nouvelles patientes et médecins sur la plateforme.',
      child: TrendLineChart(points: points, color: burgundy, unit: 'inscription(s)'),
    );
  }

  Widget _buildSeverityDonut() {
    return ChartCardShell(
      title: 'Alertes par sévérité',
      child: DonutChart(
        slices: [
          for (final row in _list('alerts_by_severity'))
            ChartSlice(
              _labelSeverity('${row['severity'] ?? 'info'}'),
              (row['count'] as num?)?.toInt() ?? 0,
              color: _colorSeverity('${row['severity'] ?? 'info'}'),
            ),
        ],
      ),
    );
  }

  Widget _buildAppointmentsDonut() {
    return ChartCardShell(
      title: 'RDV par statut',
      child: DonutChart(
        slices: [
          for (final row in _list('appointments_by_status'))
            ChartSlice(
              _labelStatus('${row['status'] ?? 'scheduled'}'),
              (row['count'] as num?)?.toInt() ?? 0,
              color: _colorStatus('${row['status'] ?? 'scheduled'}'),
            ),
        ],
      ),
    );
  }

  Widget _buildPatientsStatusCard() {
    return ChartCardShell(
      title: 'Patientes par statut du compte',
      child: DonutChart(
        slices: [
          for (final row in _list('patients_by_status'))
            ChartSlice(
              _labelStatus('${row['status'] ?? 'pending'}'),
              (row['count'] as num?)?.toInt() ?? 0,
              color: _colorStatus('${row['status'] ?? 'pending'}'),
            ),
        ],
      ),
    );
  }

  Widget _buildDoctorsRankCard() {
    return ChartCardShell(
      title: 'Classement des médecins',
      subtitle: 'Top ${_list('doctors_rank').length} par nombre de patientes suivies.',
      child: HorizontalBarList(
        slices: [
          for (final row in _list('doctors_rank'))
            ChartSlice(
              '${row['first_name'] ?? ''} ${row['last_name'] ?? ''}'
                  .trim()
                  .isEmpty
                  ? 'Médecin'
                  : '${row['first_name'] ?? ''} ${row['last_name'] ?? ''}',
              (row['patients'] as num?)?.toInt() ?? 0,
              color: burgundy,
            ),
        ],
      ),
    );
  }
}