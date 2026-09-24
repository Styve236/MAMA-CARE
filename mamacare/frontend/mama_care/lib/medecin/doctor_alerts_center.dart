import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mama_care/services/api_client.dart';
import 'package:mama_care/medecin/doctor_patiente_detail.dart';
import '../shared/app_theme.dart';
import '../shared/date_utils.dart';

class DoctorAlertsCenter extends StatefulWidget {
  const DoctorAlertsCenter({super.key});

  @override
  State<DoctorAlertsCenter> createState() => _DoctorAlertsCenterState();
}

class _DoctorAlertsCenterState extends State<DoctorAlertsCenter> {
  static const Color burgundy = AppColors.burgundy;
  int _selectedFilterIndex = 0;
  List<Map<String, dynamic>> _alerts = [];
  bool _loading = true;
  String? _error;

  static const List<String> _filters = ['Toutes', 'Critiques', 'Modérées'];

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    setState(() => _loading = true);
    try {
      final alerts = await ApiClient.doctorAlerts();
      if (mounted) {
        setState(() {
          _alerts = alerts;
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

  List<Map<String, dynamic>> get _filtered {
    switch (_selectedFilterIndex) {
      case 1:
        return _alerts.where((a) => a['severity'] == 'critical').toList();
      case 2:
        return _alerts.where((a) => a['severity'] == 'warning').toList();
      default:
        return _alerts;
    }
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

  String _severityLabel(String? severity) {
    switch (severity) {
      case 'critical':
        return 'CRITIQUE';
      case 'warning':
        return 'MODÉRÉE';
      default:
        return 'INFORMATION';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Centre d\'Alertes',
              style: TextStyle(
                color: burgundy,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            Text(
              'Analyses IA des constantes patientes',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: burgundy),
            onPressed: _loadAlerts,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _filters.length,
              itemBuilder: (context, index) {
                final isSelected = _selectedFilterIndex == index;
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: FilterChip(
                    label: Text(_filters[index]),
                    selected: isSelected,
                    onSelected: (val) {
                      setState(() => _selectedFilterIndex = index);
                    },
                    selectedColor: burgundy,
                    checkmarkColor: Colors.white,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : burgundy,
                      fontWeight: FontWeight.bold,
                    ),
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: burgundy),
                    ),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!))
                    : _filtered.isEmpty
                        ? const Center(
                            child: Text(
                              'Aucune alerte à traiter pour le moment.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadAlerts,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(20),
                              itemCount: _filtered.length,
                              itemBuilder: (context, index) =>
                                  _buildAlertCard(_filtered[index]),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  String _formatDate(Object? value) {
    return formatFullDate(value);
  }

  Map<String, dynamic> _parseDetails(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is String && value.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      } on FormatException {
        // ignore
      }
    }
    return const {};
  }

  List<String> _telemetryChips(Map<dynamic, dynamic> t) {
    String v(Object? value) {
      final n = num.tryParse('$value');
      if (n == null) return '—';
      return n == n.roundToDouble() ? '${n.toInt()}' : n.toStringAsFixed(1);
    }

    return [
      if (t['blood_pressure_systolic'] != null &&
          t['blood_pressure_diastolic'] != null)
        'TA ${v(t['blood_pressure_systolic'])}/${v(t['blood_pressure_diastolic'])}',
      if (t['weight'] != null) 'Poids ${v(t['weight'])} kg',
      if (t['blood_glucose'] != null) 'Glycémie ${v(t['blood_glucose'])}',
      if (t['temperature'] != null) 'Temp ${v(t['temperature'])} °C',
      if (t['heart_rate'] != null) 'Pouls ${v(t['heart_rate'])} bpm',
    ];
  }

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF4ECEE),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, color: Color(0xFF4A3A3D)),
      ),
    );
  }

  Widget _buildAlertCard(Map<String, dynamic> alert) {
    final isRead = alert['is_read'] == true;
    final severity = alert['severity'] as String?;
    final color = _severityColor(severity);
    final firstName = alert['first_name'] ?? '';
    final lastName = alert['last_name'] ?? '';
    final weeks = alert['pregnancy_weeks'];
    final details = _parseDetails(alert['details']);
    final recommendations = (details['recommendations'] as List? ?? [])
        .whereType<String>()
        .toList();
    final patientId = '${alert['patient_id']}';
    final phone = '${alert['patient_phone'] ?? ''}';
    final telemetry = details['telemetry'];
    final t = telemetry is Map ? telemetry : const {};

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isRead ? Colors.white : color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          if (!isRead) {
            try {
              await ApiClient.markDoctorAlertRead(alert['id'] as int);
            } on ApiException {
              // silencieux : rafraîchi au retour
            }
          }
          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DoctorPatienteDetail(
                patientId: patientId,
                patientName: '$firstName $lastName'.trim(),
              ),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (!isRead) ...[
                  Container(
                    width: 10,
                    height: 10,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  _severityLabel(severity),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 0.8,
                  ),
                ),
                const Spacer(),
                Text(
                  _formatDate(alert['created_at']),
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '$firstName $lastName'.trim().isEmpty
                  ? 'Patiente'
                  : '$firstName $lastName',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            if (phone.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    const Icon(Icons.phone, size: 14, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text(
                      phone,
                      style: const TextStyle(
                        color: burgundy,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            if (weeks != null)
              Text(
                '$weeks semaine${weeks == 1 ? '' : 's'} de grossesse',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            if (t.isNotEmpty && _telemetryChips(t).isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final chip in _telemetryChips(t)) _chip(chip),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Text(
              alert['message'] as String? ?? '',
              style: const TextStyle(fontSize: 13, height: 1.35),
            ),
            if (recommendations.isNotEmpty) ...[
              const Divider(height: 20),
              for (final rec in recommendations)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '• ',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Expanded(
                        child: Text(
                          rec,
                          style: const TextStyle(fontSize: 12, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}