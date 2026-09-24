import 'package:flutter/material.dart';
import 'package:mama_care/services/api_client.dart';

import '../shared/app_theme.dart';
import '../shared/dashboard_charts.dart';

class _MetricDefinition {
  final String label;
  final String unit;
  final Color color;
  final String? Function(Map<String, dynamic> t) valueOf;
  final String? Function(Map<String, dynamic> t)? secondaryOf;

  _MetricDefinition({
    required this.label,
    required this.unit,
    required this.color,
    required this.valueOf,
    this.secondaryOf,
  });
}

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final Color burgundyColor = AppColors.burgundy;

  static final List<_MetricDefinition> _metrics = [
    _MetricDefinition(
      label: 'Tension',
      unit: 'mmHg',
      color: burgundy,
      valueOf: (t) => '${t['blood_pressure_systolic']}',
      secondaryOf: (t) => '${t['blood_pressure_diastolic']}',
    ),
    _MetricDefinition(
      label: 'Poids',
      unit: 'kg',
      color: colorOk,
      valueOf: (t) => '${t['weight']}',
    ),
    _MetricDefinition(
      label: 'Glycémie',
      unit: 'mmol/L',
      color: colorCritical,
      valueOf: (t) => '${t['blood_glucose']}',
    ),
    _MetricDefinition(
      label: 'Température',
      unit: '°C',
      color: colorWarning,
      valueOf: (t) => '${t['temperature']}',
    ),
    _MetricDefinition(
      label: 'Fréquence',
      unit: 'bpm',
      color: colorInfo,
      valueOf: (t) => '${t['heart_rate']}',
    ),
  ];

  int _selectedType = 0;
  List<Map<String, dynamic>> _telemetry = [];
  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> get _chronological =>
      _telemetry.reversed.toList();

  @override
  void initState() {
    super.initState();
    _loadTelemetry();
  }

  Future<void> _loadTelemetry() async {
    try {
      final telemetry = await ApiClient.patientTelemetry();
      if (mounted) {
        setState(() {
          _telemetry = telemetry;
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

  _MetricDefinition get _current => _metrics[_selectedType];

  String _fmt(Object? v) {
    final n = num.tryParse('$v');
    if (n == null) return '—';
    if (n == n.roundToDouble()) return '${n.toInt()}';
    return n.toStringAsFixed(1);
  }

  String _shortDate(Object? value) {
    final parsed = DateTime.tryParse('$value');
    if (parsed == null) return '';
    final local = parsed.toLocal();
    return '${local.day}/${local.month}';
  }

  List<ChartPoint> _points(_MetricDefinition m, bool secondary) {
    return [
      for (final t in _chronological)
        ChartPoint(
          _shortDate(t['recorded_at']),
          num.tryParse(
            '${secondary ? m.secondaryOf?.call(t) : m.valueOf(t)}',
          )?.toDouble(),
        ),
    ];
  }

  Color? _trendColor(double? prev, double? last) {
    if (prev == null || last == null) return null;
    return last >= prev ? colorCritical : colorOk;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: burgundyColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/patiente/dashboard');
          },
        ),
        title: const Text(
          'Mes Statistiques',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!, textAlign: TextAlign.center),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadTelemetry,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
                    children: [
                      _buildMetricSelector(),
                      const SizedBox(height: 20),
                      _buildKpiRow(),
                      const SizedBox(height: 20),
                      _buildTrendCard(),
                      const SizedBox(height: 20),
                      _buildAIAnalysisBox(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildMetricSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          for (var i = 0; i < _metrics.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedType = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    color: _selectedType == i
                        ? burgundyColor
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _metrics[i].label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _selectedType == i
                          ? Colors.white
                          : Colors.grey.shade600,
                      fontWeight: _selectedType == i
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildKpiRow() {
    final chrono = _chronological;
    final current = _current;
    final last = num.tryParse('${current.valueOf(chrono.last)}');
    final prev = chrono.length > 1
        ? num.tryParse('${current.valueOf(chrono[chrono.length - 2])}')
        : null;
    final lastSec = num.tryParse('${current.secondaryOf?.call(chrono.last)}');
    final trendColor = _trendColor(prev?.toDouble(), last?.toDouble());
    final arrow = trendColor == null
        ? null
        : trendColor == colorOk
            ? Icons.arrow_downward
            : Icons.arrow_upward;

    return Row(
      children: [
        Expanded(
          child: KpiCard(
            icon: Icons.speed,
            label: '${current.label} actuelle',
            value: last == null
                ? '—'
                : '${_fmt(last)} ${current.unit}',
            subtitle: arrow == null || prev == null
                ? null
                : 'Hier : ${_fmt(prev)} ${current.unit}',
          ),
        ),
        const SizedBox(width: 12),
        if (lastSec != null && current.secondaryOf != null)
          Expanded(
            child: KpiCard(
              icon: Icons.favorite_outline,
              label: 'Valeur basse',
              value: '${_fmt(lastSec)} ${current.unit}',
              subtitle: 'Limite inférieure',
            ),
          ),
      ],
    );
  }

  Widget _buildTrendCard() {
    final m = _current;
    final points = _points(m, false);
    final secondary = m.secondaryOf == null
        ? null
        : _points(m, true);
    return ChartCardShell(
      title: 'Évolution de la ${m.label.toLowerCase()}',
      subtitle:
          '${_chronological.length} mesure${_chronological.length > 1 ? 's' : ''} enregistrée${_chronological.length > 1 ? 's' : ''}',
      child: TrendLineChart(
        points: points,
        unit: m.unit,
        color: m.color,
        secondaryPoints: secondary,
        secondaryLegend: m.secondaryOf == null ? null : '${m.label} min',
      ),
    );
  }

  Widget _buildAIAnalysisBox() {
    final hasData = _telemetry.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: burgundyColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome, color: burgundyColor),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              hasData
                  ? '${_telemetry.length} mesure${_telemetry.length > 1 ? 's' : ''} analysée${_telemetry.length > 1 ? 's' : ''} par l\'IA. '
                      'Les constantes sont traitées avant transmission à votre médecin.'
                  : 'En attente de vos premières mesures pour analyser vos tendances.',
              style: TextStyle(
                color: burgundyColor,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}