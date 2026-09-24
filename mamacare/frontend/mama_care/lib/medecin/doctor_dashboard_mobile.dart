import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mama_care/services/api_client.dart';
import 'package:mama_care/medecin/doctor_patiente_detail.dart';
import 'package:mama_care/medecin/doctor_alerts_center.dart';
import 'package:mama_care/medecin/doctor_messages_list.dart';
import 'package:mama_care/medecin/doctor_profile_screen.dart';
import 'package:mama_care/medecin/widgets_patient_list_tab.dart';
import 'package:mama_care/medecin/doctor_appointments_screen.dart';
import '../shared/app_theme.dart';
import '../shared/dashboard_charts.dart';
import '../shared/date_utils.dart';

class DoctorDashboardMobile extends StatefulWidget {
  const DoctorDashboardMobile({super.key});

  @override
  State<DoctorDashboardMobile> createState() => _DoctorDashboardMobileState();
}

class _DoctorDashboardMobileState extends State<DoctorDashboardMobile> {
  static const Color burgundy = AppColors.burgundy;
  int _currentIndex = 0;
  List<Map<String, dynamic>> _patients = [];
  List<Map<String, dynamic>> _alerts = [];
  Map<String, int> _stats = const {'patients': 0, 'alerts': 0, 'messages': 0};
  List<Map<String, dynamic>> _alertsBySeverity = [];
  List<Map<String, dynamic>> _alertsTrend = [];
  List<Map<String, dynamic>> _patientsByWeeks = [];
  List<Map<String, dynamic>> _appointmentRequests = [];
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
        ApiClient.doctorAppointmentRequests(),
      ]);
      if (mounted) {
        final stats = results[2] as Map<String, dynamic>;
        setState(() {
          _patients = (results[0] as List).cast<Map<String, dynamic>>();
          _alerts = (results[1] as List).cast<Map<String, dynamic>>();
          _appointmentRequests =
              (results[3] as List).cast<Map<String, dynamic>>();
          _stats = {
            'patients': (stats['patients'] as num?)?.toInt() ?? _patients.length,
            'alerts': (stats['alerts'] as num?)?.toInt() ?? 0,
            'messages': (stats['messages'] as num?)?.toInt() ?? 0,
          };
          _alertsBySeverity = (stats['alerts_by_severity'] as List? ?? [])
              .cast<Map<String, dynamic>>();
          _alertsTrend = (stats['alerts_trend'] as List? ?? [])
              .cast<Map<String, dynamic>>();
          _patientsByWeeks = (stats['patients_by_weeks'] as List? ?? [])
              .cast<Map<String, dynamic>>();
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
          items: [
            const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Accueil'),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              label: 'Patientes',
            ),
            BottomNavigationBarItem(
              icon: Badge(
                isLabelVisible: (_stats['alerts'] ?? 0) > 0,
                label: Text('${_stats['alerts'] ?? 0}'),
                child: const Icon(Icons.gpp_maybe_outlined),
              ),
              label: 'Alertes',
            ),
            BottomNavigationBarItem(
              icon: Badge(
                isLabelVisible: (_stats['messages'] ?? 0) > 0,
                label: Text('${_stats['messages'] ?? 0}'),
                child: const Icon(Icons.chat_bubble_outline),
              ),
              label: 'Messages',
            ),
            const BottomNavigationBarItem(
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
          const Text(
            'Vue d’ensemble',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: Color(0xFF4A3A3D)),
          ),
          const SizedBox(height: 16),
          _buildStatsRow(),
          const SizedBox(height: 16),
          if (_pendingRequests().isNotEmpty) ...[
            _buildSectionHeader(
              'Demandes de rendez-vous',
              Icons.event_available,
              onSeeAll: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DoctorAppointmentsScreen(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ..._pendingRequests().take(3).map(_buildRequestCard),
            const SizedBox(height: 8),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildSeverityDonutCard()),
              const SizedBox(width: 12),
              Expanded(child: _buildWeeksCard()),
            ],
          ),
          const SizedBox(height: 18),
          _buildAlertTrendCard(),
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: KpiCard(
            icon: Icons.people_outline,
            label: 'Patientes suivies',
            value: '${_stats['patients'] ?? 0}',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: KpiCard(
            icon: Icons.notifications_active_outlined,
            label: 'Alertes non lues',
            value: '${_stats['alerts'] ?? 0}',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: KpiCard(
            icon: Icons.chat_bubble_outline,
            label: 'Messages non lus',
            value: '${_stats['messages'] ?? 0}',
          ),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _pendingRequests() {
    return _appointmentRequests
        .where((a) =>
            '${a['status'] ?? ''}' == 'pending' ||
            '${a['status'] ?? ''}' == 'rescheduled')
        .toList();
  }

  Future<void> _refreshRequests() async {
    try {
      final rows = await ApiClient.doctorAppointmentRequests();
      if (mounted) {
        setState(() {
          _appointmentRequests = rows.cast<Map<String, dynamic>>();
        });
      }
    } on ApiException {
      // Silencieux : le prochain rafraîchissement périodique retentera.
    }
  }

  Future<void> _handleRequestAction(
    Map<String, dynamic> a,
    Function() action,
  ) async {
    await action();
    await _refreshRequests();
  }

  Widget _buildRequestCard(Map<String, dynamic> a) {
    final status = '${a['status'] ?? ''}';
    final name =
        '${a['first_name'] ?? ''} ${a['last_name'] ?? ''}'.trim();
    final phone = '${a['patient_phone'] ?? ''}';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: burgundy.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.event_available, color: burgundy, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? 'Patiente' : name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (phone.isNotEmpty)
                      Text('📞 $phone',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          )),
                    Text(
                      status == 'rescheduled'
                          ? 'Proposition : ${formatFullDate(a['appointment_date'])}'
                          : formatFullDate(a['appointment_date']),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF2E7D32),
                  ),
                  onPressed: () => _handleRequestAction(
                    a,
                    () => ApiClient.doctorAcceptAppointment(
                        (a['id'] as num).toInt()),
                  ),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Accepter'),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  style:
                      TextButton.styleFrom(foregroundColor: Colors.red),
                  onPressed: () => _handleRequestAction(
                    a,
                    () => ApiClient.doctorRejectAppointment(
                        (a['id'] as num).toInt()),
                  ),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Refuser'),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: burgundy,
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DoctorAppointmentsScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.date_range, size: 18),
                  label: const Text('Reprogrammer'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<ChartSlice> _severitySlices() {
    return _alertsBySeverity
        .map((row) {
          final severity = '${row['severity'] ?? 'info'}'.toLowerCase();
          final count = (row['count'] as num?)?.toInt() ?? 0;
          return ChartSlice(
            _labelSeverity(severity),
            count,
            color: _colorSeverity(severity),
          );
        })
        .toList();
  }

  String _labelSeverity(String severity) {
    switch (severity) {
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

  Color _colorSeverity(String severity) {
    switch (severity) {
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

  Widget _buildSeverityDonutCard() {
    return ChartCardShell(
      title: 'Alertes par sévérité',
      child: DonutChart(slices: _severitySlices()),
    );
  }

  Widget _buildWeeksCard() {
    return ChartCardShell(
      title: 'Patientes par trimestre',
      child: HorizontalBarList(
        slices: _patientsByWeeks
            .map((row) => ChartSlice(
                  '${row['bracket'] ?? 'Non défini'}',
                  (row['count'] as num?)?.toInt() ?? 0,
                  color: burgundy,
                ))
            .toList(),
      ),
    );
  }

  Widget _buildAlertTrendCard() {
    final points = [
      for (final row in _alertsTrend)
        ChartPoint(
          '${row['date'] ?? ''}',
          (row['count'] as num?)?.toDouble(),
        ),
    ];
    return ChartCardShell(
      title: 'Alertes — 14 derniers jours',
      subtitle: 'Activité de pré-alerte IA générée par vos patientes.',
      child: TrendLineChart(
        points: points,
        color: burgundy,
        unit: 'alerte(s)',
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