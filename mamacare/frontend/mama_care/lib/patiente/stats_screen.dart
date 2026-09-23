import 'package:flutter/material.dart';
import 'package:mama_care/services/api_client.dart';
import '../shared/app_theme.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final Color burgundyColor = AppColors.burgundy;

  int _selectedType = 0;
  List<Map<String, dynamic>> _telemetry = [];
  bool _loading = true;
  String? _error;

  static const List<String> _titles = ['tension', 'poids', 'glycémie'];

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

  bool get _hasData => _telemetry.isNotEmpty;

  List<num> get _values {
    final list = _telemetry.reversed.toList();
    switch (_selectedType) {
      case 1:
        return list
            .map((t) => num.tryParse('${t['weight']}'))
            .whereType<num>()
            .toList();
      case 2:
        return list
            .map((t) => num.tryParse('${t['blood_glucose']}'))
            .whereType<num>()
            .toList();
      default:
        return list
            .map((t) => num.tryParse('${t['blood_pressure_systolic']}'))
            .whereType<num>()
            .toList();
    }
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
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _loadTelemetry,
                  child: ListView(
                    children: [
                      const SizedBox(height: 20),
                      _buildTabSelector(),
                      const SizedBox(height: 20),
                      _buildChartSection(),
                      const SizedBox(height: 30),
                      _buildAIAnalysisBox(),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
    );
  }

  Widget _buildTabSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          _buildTabItem(title: 'Tension', index: 0),
          _buildTabItem(title: 'Poids', index: 1),
          _buildTabItem(title: 'Glycémie', index: 2),
        ],
      ),
    );
  }

  Widget _buildTabItem({required String title, required int index}) {
    final bool isSelected = _selectedType == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedType = index;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? burgundyColor : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey.shade600,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChartSection() {
    final values = _values;
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      height: 300,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Évolution de la ${_titles[_selectedType]}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            '${_telemetry.length} mesure${_telemetry.length > 1 ? 's' : ''} enregistrée${_telemetry.length > 1 ? 's' : ''}',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          Expanded(
            child: values.isEmpty
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.show_chart,
                        size: 80,
                        color: Colors.grey.shade200,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Aucune donnée enregistrée',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Vos mesures apparaîtront ici.',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  )
                : values.length == 1
                    ? Center(
                        child: Text(
                          '${values.first}',
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                            color: burgundyColor,
                          ),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: CustomPaint(
                          size: const Size.fromHeight(200),
                          painter: _ChartPainter(values, burgundyColor),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIAnalysisBox() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
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
              _hasData
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

class _ChartPainter extends CustomPainter {
  final List<num> values;
  final Color color;

  _ChartPainter(this.values, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0.25),
          color.withValues(alpha: 0.0),
        ],
      ).createShader(Offset.zero & size);
    final dotPaint = Paint()..color = color;

    double minV = values.reduce((a, b) => a < b ? a : b).toDouble();
    double maxV = values.reduce((a, b) => a > b ? a : b).toDouble();
    if (maxV == minV) maxV = minV + 1;
    final margin = (maxV - minV) * 0.12;

    final points = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final y =
          size.height - (size.height * (values[i].toDouble() - (minV - margin)) / (maxV + margin - (minV - margin)));
      points.add(Offset(x, y.clamp(0.0, size.height)));
    }

    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      line.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(line, linePaint);

    final fill = Path.from(line)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();
    canvas.drawPath(fill, fillPaint);

    for (final p in points) {
      canvas.drawCircle(p, 3.5, dotPaint);
      canvas.drawCircle(
        p,
        6,
        Paint()..color = color.withValues(alpha: 0.2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ChartPainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.color != color;
  }
}