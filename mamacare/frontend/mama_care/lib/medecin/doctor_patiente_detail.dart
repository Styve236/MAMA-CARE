import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mama_care/services/api_client.dart';

class DoctorPatienteDetail extends StatefulWidget {
  final String? patientId;
  final String? patientName;

  const DoctorPatienteDetail({
    super.key,
    this.patientId,
    this.patientName,
  });

  @override
  State<DoctorPatienteDetail> createState() => _DoctorPatienteDetailState();
}

class _DoctorPatienteDetailState extends State<DoctorPatienteDetail> {
  static const Color burgundy = Color(0xFF800020);
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = widget.patientId;
    if (id == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    try {
      final data = await ApiClient.doctorPatientDetail(id);
      if (mounted) setState(() => _data = data);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _num(Object? value) {
    if (value == null) return '—';
    final n = num.tryParse('$value');
    if (n == null) return '$value';
    if (n == n.roundToDouble()) return '${n.toInt()}';
    return n.toStringAsFixed(1);
  }

  String _formatDate(Object? value) {
    if (value == null) return '';
    final parsed = DateTime.tryParse('$value');
    if (parsed == null) return '$value';
    return '${parsed.day.toString().padLeft(2, '0')}/'
        '${parsed.month.toString().padLeft(2, '0')}  '
        '${parsed.hour.toString().padLeft(2, '0')}:'
        '${parsed.minute.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> _parseDetails(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is String && value.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } on FormatException {
        // ignore
      }
    }
    return const {};
  }

  Color _severityColor(String? severity) {
    switch (severity) {
      case 'critical':
        return const Color(0xFFB3261E);
      case 'warning':
        return const Color(0xFFB54708);
      default:
        return const Color(0xFF2E7D32);
    }
  }

  List<Map<String, dynamic>> get _telemetry {
    final raw = _data?['telemetry'];
    if (raw is List) {
      return raw.whereType<Map<String, dynamic>>().toList();
    }
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    final patient =
        _data?['patient'] is Map<String, dynamic>
            ? (_data!['patient'] as Map<String, dynamic>)
            : <String, dynamic>{};
    final analysis =
        _data?['analysis'] is Map<String, dynamic>
            ? (_data!['analysis'] as Map<String, dynamic>)
            : null;
    final firstName = widget.patientName ?? patient['first_name'] ?? '';
    final lastName = patient['last_name'] ?? '';

    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: _appBar(firstName, lastName),
        body: Center(child: Text(_error!)),
      );
    }

    if (widget.patientId == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.pregnant_woman, size: 72, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              const Text(
                'Sélectionnez une patiente depuis le tableau de bord',
                style: TextStyle(color: Colors.grey, fontSize: 15),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final telemetry = _telemetry;
    final latest = telemetry.isEmpty ? null : telemetry.first;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _appBar(firstName, lastName),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (analysis != null) ...[
              _buildSectionTitle('1', 'Résumé de santé IA'),
              const SizedBox(height: 12),
              _buildIaAnalysisCard(analysis),
              const SizedBox(height: 25),
            ],
            _buildSectionTitle('2', 'Dernières mesures'),
            const SizedBox(height: 12),
            _buildLatestMeasures(latest),
            const SizedBox(height: 25),
            _buildSectionTitle('3', 'Évolution du poids'),
            const SizedBox(height: 12),
            _buildWeightChart(),
            const SizedBox(height: 25),
            _buildSectionTitle('4', 'Historique des constantes'),
            const SizedBox(height: 12),
            _buildHistory(telemetry),
            if (widget.patientId != null) ...[
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Messagerie médecin bientôt disponible'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.chat_bubble_outline,
                      color: Colors.white),
                  label: const Text(
                    'Contacter la patiente',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: burgundy,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  AppBar _appBar(String firstName, String lastName) {
    final patient = _data?['patient'] is Map<String, dynamic>
        ? (_data!['patient'] as Map<String, dynamic>)
        : <String, dynamic>{};
    final weeks = patient['pregnancy_weeks'];
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      automaticallyImplyLeading:
          ModalRoute.of(context)?.settings.name == '/medecin/doctor_dashboard_mobile'
              ? false
              : true,
      leading: ModalRoute.of(context)?.settings.name ==
              '/medecin/doctor_dashboard_mobile'
          ? null
          : IconButton(
              icon: const Icon(Icons.arrow_back, color: burgundy),
              onPressed: () => Navigator.of(context).pop(),
            ),
      title: Column(
        children: [
          Text(
            '$firstName $lastName'.trim().isEmpty
                ? 'Patiente'
                : '$firstName $lastName',
            style: const TextStyle(
              color: burgundy,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          if (weeks != null) ...[
            const SizedBox(height: 3),
            Text(
              '$weeks semaine${weeks == 1 ? '' : 's'} de grossesse',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ],
      ),
      centerTitle: true,
    );
  }

  Widget _buildSectionTitle(String number, String title) {
    return Row(
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: burgundy,
          child: Text(
            number,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildIaAnalysisCard(Map<String, dynamic> analysis) {
    final severity = analysis['severity'] as String?;
    final color = _severityColor(severity);
    final details = _parseDetails(analysis['details']);
    final recommendations =
        (details['recommendations'] as List? ?? [])
            .whereType<String>()
            .map((e) => e.toString())
            .toList();
    final label = switch (severity) {
      'critical' => 'CRITIQUE — action rapide recommandée',
      'warning' => 'MODÉRÉ — surveillance renforcée',
      _ => 'NORMAL — situation stable',
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            analysis['message'] as String? ?? 'Aucune synthèse.',
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
          if (recommendations.isNotEmpty) ...[
            const Divider(height: 24),
            const Text(
              'Recommandations IA',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: burgundy),
            ),
            const SizedBox(height: 8),
            for (final rec in recommendations)
              _buildBulletPoint(rec),
          ],
        ],
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '• ',
            style: TextStyle(color: burgundy, fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLatestMeasures(Map<String, dynamic>? latest) {
    if (latest == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text('Aucune constante enregistrée pour le moment.',
            style: TextStyle(color: Colors.grey)),
      );
    }
    final items = [
      ('Tension', '${_num(latest['blood_pressure_systolic'])}/${_num(latest['blood_pressure_diastolic'])} mmHg', Icons.favorite),
      ('Poids', '${_num(latest['weight'])} kg', Icons.monitor_weight_outlined),
      ('Fréquence cardiaque', '${_num(latest['heart_rate'])} bpm', Icons.favorite_border),
      ('Glycémie', _num(latest['blood_glucose']), Icons.water_drop_outlined),
      ('Température', '${_num(latest['temperature'])} °C', Icons.thermostat_outlined),
    ];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        children: [
          for (final (label, value, icon) in items) ...[
            if (label != items.first.$1) const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Row(
                children: [
                  Icon(icon, color: burgundy, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(label,
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      color: burgundy,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWeightChart() {
    final weights = _telemetry
        .where((t) => t['weight'] != null)
        .map((t) => num.tryParse('${t['weight']}'))
        .whereType<num>()
        .toList()
        .reversed
        .toList();
    if (weights.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text('Pas encore de données de poids.',
            style: TextStyle(color: Colors.grey)),
      );
    }
    return Container(
      height: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dernière valeur : ${_num(weights.last)} kg',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: CustomPaint(
              size: Size.infinite,
              painter: _WeightChartPainter(weights, burgundy),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistory(List<Map<String, dynamic>> telemetry) {
    if (telemetry.isEmpty) {
      return const Text('Aucun historique.',
          style: TextStyle(color: Colors.grey));
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        children: [
          for (final t in telemetry.take(5)) ...[
            if (telemetry.indexOf(t) > 0) const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _formatDate(t['recorded_at']),
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '${_num(t['blood_pressure_systolic'])}/${_num(t['blood_pressure_diastolic'])} mmHg  •  '
                    '${_num(t['weight'])} kg',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WeightChartPainter extends CustomPainter {
  final List<num> values;
  final Color color;

  _WeightChartPainter(this.values, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.25)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final dotPaint = Paint()..color = color;

    double minV = values.reduce((a, b) => a < b ? a : b) - 0.5;
    double maxV = values.reduce((a, b) => a > b ? a : b) + 0.5;
    if (maxV == minV) maxV = minV + 1;

    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final y =
          size.height - (size.height * (values[i].toDouble() - minV) / (maxV - minV));
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
    for (var i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final y =
          size.height - (size.height * (values[i].toDouble() - minV) / (maxV - minV));
      canvas.drawCircle(Offset(x, y), 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WeightChartPainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.color != color;
  }
}