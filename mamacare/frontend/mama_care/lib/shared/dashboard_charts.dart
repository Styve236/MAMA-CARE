import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'app_theme.dart';

const burgundy = AppColors.burgundy;
const colorCritical = Color(0xFFB3261E);
const colorWarning = Color(0xFFB54708);
const colorOk = Color(0xFF2E7D32);
const colorInfo = Color(0xFF1E6FB3);
const colorMuted = Color(0xFF9E9497);

const _cardRadius = BorderRadius.all(Radius.circular(20));
const _softShadow = [
  BoxShadow(
    color: Color(0x0D000000),
    blurRadius: 15,
    offset: Offset(0, 5),
  ),
];

class KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  final IconData icon;

  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: _cardRadius,
        boxShadow: _softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: burgundy, size: 22),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: burgundy,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF6B5B5E),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: const TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}

class ChartCardShell extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const ChartCardShell({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: _cardRadius,
        boxShadow: _softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: Color(0xFF4A3A3D),
            ),
          ),
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              subtitle!,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class EmptyChart extends StatelessWidget {
  final String message;

  const EmptyChart({super.key, this.message = 'Aucune donnée disponible.'});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: Center(
        child: Text(
          message,
          style: const TextStyle(color: Colors.grey, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// Courbe d'évolution (chronologique).
class TrendLineChart extends StatelessWidget {
  final List<ChartPoint> points;
  final String unit;
  final Color color;
  final List<ChartPoint>? secondaryPoints;
  final String? secondaryLegend;

  const TrendLineChart({
    super.key,
    required this.points,
    this.unit = '',
    this.color = burgundy,
    this.secondaryPoints,
    this.secondaryLegend,
  });

  double? _minY() {
    var min = points
        .map((p) => p.value)
        .whereType<double>()
        .fold<double?>(null, (a, b) => a == null ? b : a < b ? a : b);
    final others = secondaryPoints
        ?.map((p) => p.value)
        .whereType<double>();
    if (others != null) {
      for (final v in others) {
        min = min == null ? v : (v < min ? v : min);
      }
    }
    if (min == null) return null;
    final flo = min.floorToDouble();
    return flo == min ? flo - 1 : flo;
  }

  double? _maxY() {
    var max = points
        .map((p) => p.value)
        .whereType<double>()
        .fold<double?>(null, (a, b) => a == null ? b : a > b ? a : b);
    final others = secondaryPoints
        ?.map((p) => p.value)
        .whereType<double>();
    if (others != null) {
      for (final v in others) {
        max = max == null ? v : (v > max ? v : max);
      }
    }
    if (max == null) return null;
    final ceil = max.ceilToDouble();
    return ceil == max ? ceil + 1 : ceil;
  }

  Widget _bottomLabel(double value, TitleMeta meta) {
    final i = value.round();
    if (i < 0 || i >= points.length) return const SizedBox.shrink();
    final label = points[i].label;
    final maxTicks = 7;
    if (points.length > maxTicks &&
        i % (points.length ~/ maxTicks) != 0 &&
        i != points.length - 1) {
      return const SizedBox.shrink();
    }
    return SideTitleWidget(
      meta: meta,
      child: Text(
        label,
        style: const TextStyle(color: Colors.grey, fontSize: 10),
      ),
    );
  }

  Widget _leftLabel(double value, TitleMeta meta) {
    if (value == meta.max) return const SizedBox.shrink();
    return Text(
      '${value.round()}',
      style: const TextStyle(color: Colors.grey, fontSize: 10),
      textAlign: TextAlign.right,
    );
  }

  @override
  Widget build(BuildContext context) {
    final minY = _minY();
    final maxY = _maxY();
    if (minY == null || maxY == null) {
      return const EmptyChart();
    }
    final n = points.length;
    final spots = <FlSpot>[
      for (var i = 0; i < n; i++)
        if (points[i].value != null) FlSpot(i.toDouble(), points[i].value!),
    ];
    if (n < 2 || spots.length < 2) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Text(
            '${points[0].value?.toStringAsFixed(1) ?? '—'} $unit',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
      );
    }
    final maxX = (n - 1).toDouble();
    final sec = secondaryPoints;
    final secSpots = sec == null
        ? <FlSpot>[]
        : <FlSpot>[
            for (var i = 0; i < sec.length; i++)
              if (sec[i].value != null) FlSpot(i.toDouble(), sec[i].value!),
          ];
    final suffix = unit.isEmpty ? unit : ' $unit';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (secondaryLegend != null) ...[
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              const Text('Valeur', style: TextStyle(fontSize: 11, color: Colors.grey)),
              if (secondaryLegend != null) ...[
                const SizedBox(width: 14),
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: colorInfo,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(secondaryLegend!,
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ],
          ),
          const SizedBox(height: 8),
        ],
        SizedBox(
          height: 220,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: maxX,
              minY: minY,
              maxY: maxY,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 1,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: const Color(0xFFF0E7E9),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 26,
                    interval: 1,
                    getTitlesWidget: _bottomLabel,
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 34,
                    interval: 1,
                    getTitlesWidget: _leftLabel,
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (touchedSpots) => touchedSpots.map((s) {
                    final i = s.x.round();
                    final label = i >= 0 && i < points.length
                        ? points[i].label
                        : '';
                    return LineTooltipItem(
                      '$label\n${s.y.toStringAsFixed(1)}$suffix',
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  }).toList(),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: color,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, _, _, _) => FlDotCirclePainter(
                      radius: 3.5,
                      color: color,
                      strokeWidth: 1.5,
                      strokeColor: Colors.white,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        color.withValues(alpha: 0.22),
                        color.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
                if (secSpots.isNotEmpty) ...[
                  LineChartBarData(
                    spots: secSpots,
                    isCurved: true,
                    color: colorInfo,
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class ChartPoint {
  final String label;
  final double? value;

  const ChartPoint(this.label, this.value);
}

class ChartSlice {
  final String label;
  final int value;
  final Color color;

  ChartSlice(this.label, this.value, {Color? color})
      : color = color ?? burgundy;
}

/// Diagramme en anneau avec légende.
class DonutChart extends StatelessWidget {
  final List<ChartSlice> slices;

  const DonutChart({super.key, required this.slices});

  @override
  Widget build(BuildContext context) {
    final total = slices.fold<int>(0, (sum, s) => sum + s.value);
    if (slices.isEmpty || total == 0) return const EmptyChart();
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 170,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 42,
                startDegreeOffset: -90,
                sections: [
                  for (final s in slices)
                    PieChartSectionData(
                      value: s.value.toDouble(),
                      color: s.color,
                      radius: 26,
                      title: '${s.value}',
                      titleStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final s in slices) _legendRow(s, total),
            ],
          ),
        ),
      ],
    );
  }

  Widget _legendRow(ChartSlice slice, int total) {
    final pct = total == 0 ? 0 : (slice.value * 100 / total).round();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: slice.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              slice.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: Color(0xFF4A3A3D)),
            ),
          ),
          Text(
            '$pct%',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: burgundy,
            ),
          ),
        ],
      ),
    );
  }
}

/// Barres verticales.
class VerticalBarChart extends StatelessWidget {
  final List<ChartSlice> slices;
  final bool showCountAbove;

  const VerticalBarChart({
    super.key,
    required this.slices,
    this.showCountAbove = true,
  });

  @override
  Widget build(BuildContext context) {
    if (slices.isEmpty ||
        slices.every((s) => s.value == 0)) {
      return const EmptyChart();
    }
    final max = slices.fold<int>(1, (a, s) => s.value > a ? s.value : a);
    final unsignedMax = (max * 1.2).ceilToDouble();
    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: unsignedMax,
          gridData: const FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 1,
          ),
          borderData: FlBorderData(show: false),
          titlesData: const FlTitlesData(
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: _bottomBarLabel,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: false,
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < slices.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: slices[i].value.toDouble(),
                    color: slices[i].color,
                    width: slices.isNotEmpty && slices.length <= 8 ? 20 : 10,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(6),
                    ),
                    backDrawRodData: BackgroundBarChartRodData(
                      show: true,
                      toY: unsignedMax,
                      color: const Color(0x0A800020),
                    ),
                  ),
                ],
                showingTooltipIndicators:
                    showCountAbove ? [0] : const [],
              ),
          ],
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => burgundy,
              getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                '${slices[group.x].label} : ${rod.toY.round()}',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _bottomBarLabel(double value, TitleMeta meta) {
    return const SizedBox.shrink();
  }
}

/// Barres horizontales pour classements (médecins…).
class HorizontalBarList extends StatelessWidget {
  final List<ChartSlice> slices;

  const HorizontalBarList({super.key, required this.slices});

  @override
  Widget build(BuildContext context) {
    if (slices.isEmpty || slices.every((s) => s.value == 0)) {
      return const EmptyChart();
    }
    final max = slices.fold<int>(1, (a, s) => s.value > a ? s.value : a);
    return Column(
      children: [
        for (final s in slices)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 110,
                  child: Text(
                    s.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF4A3A3D),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: max == 0 ? 0 : s.value / max,
                      minHeight: 12,
                      backgroundColor: const Color(0xFFF0E7E9),
                      valueColor: AlwaysStoppedAnimation<Color>(s.color),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 36,
                  child: Text(
                    '${s.value}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: burgundy,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}