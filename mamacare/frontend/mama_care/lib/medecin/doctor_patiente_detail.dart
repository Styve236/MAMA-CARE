import 'package:flutter/material.dart';
import 'package:mama_care/medecin/doctor_messages_list.dart';

class DoctorPatienteDetail extends StatefulWidget {
  /// Ces données seront injectées depuis Supabase
  /// lors de la sélection d'une patiente.
  final String? patientName;
  final String? patientAge;
  final String? pregnancyWeek;
  final List<Map<String, dynamic>>? measurements;

  const DoctorPatienteDetail({
    super.key,
    this.patientName,
    this.patientAge,
    this.pregnancyWeek,
    this.measurements,
  });

  @override
  State<DoctorPatienteDetail> createState() => _DoctorPatienteDetailState();
}

class _DoctorPatienteDetailState extends State<DoctorPatienteDetail> {
  static const Color burgundy = Color(0xFF800020);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // ==============================
      // APP BAR
      // ==============================
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: burgundy,
          ),
          onPressed: () {
            // Redirection directe et propre vers le dashboard du médecin
            Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil(
              '/medecin/doctor_dashboard_mobile',
              (route) => false,
            );
          },
        ),
        title: Column(
          children: [
            Text(
              widget.patientName ?? '[Nom de la patiente]',
              style: const TextStyle(
                color: burgundy,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${widget.patientAge ?? '[Âge]'} ans • '
              '${widget.pregnancyWeek ?? '[Semaine]'} semaines de grossesse',
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        centerTitle: true,
      ),
      // ==============================
      // CONTENU
      // ==============================
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==============================
            // 1. RÉSUMÉ DE SANTÉ IA
            // ==============================
            _buildSectionTitle(
              '1',
              'Résumé de santé IA',
            ),
            const SizedBox(height: 12),
            _buildIaAnalysisCard(),
            const SizedBox(height: 25),

            // ==============================
            // 2. GRAPHIQUES
            // ==============================
            _buildSectionTitle(
              '2',
              'Graphiques d\'évolution',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMiniChartCard(
                    'Tension artérielle',
                    Icons.favorite,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMiniChartCard(
                    'Poids',
                    Icons.monitor_weight,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 25),

            // ==============================
            // 3. HISTORIQUE DES MESURES
            // ==============================
            _buildSectionTitle(
              '3',
              'Historique des dernières mesures',
            ),
            const SizedBox(height: 12),
            _buildMeasurementsList(),
            const SizedBox(height: 30),

            // ==============================
            // BOUTON CONTACT
            // ==============================
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DoctorMessagesList(),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.chat_bubble_outline,
                  color: Colors.white,
                ),
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
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TITRE DE SECTION
  // ==========================================
  Widget _buildSectionTitle(
    String number,
    String title,
  ) {
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

  // ==========================================
  // CARTE ANALYSE IA
  // ==========================================
  Widget _buildIaAnalysisCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: burgundy.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: burgundy.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.grey.shade200,
                  ),
                ),
                child: const Icon(
                  Icons.psychology_outlined,
                  color: burgundy,
                  size: 30,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Analyse IA : [Statut]',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: burgundy,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Synthèse intelligente basée sur les données '
                      'de suivi et l’historique de la patiente.',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          const Text(
            'Recommandations IA',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: burgundy,
            ),
          ),
          const SizedBox(height: 8),
          _buildBulletPoint('[Recommandation personnalisée 1]'),
          _buildBulletPoint('[Recommandation personnalisée 2]'),
          _buildBulletPoint('[Recommandation personnalisée 3]'),
        ],
      ),
    );
  }

  // ==========================================
  // POINT DE RECOMMANDATION
  // ==========================================
  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '• ',
            style: TextStyle(
              color: burgundy,
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // CARTE GRAPHIQUE
  // ==========================================
  Widget _buildMiniChartCard(
    String title,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade100,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: burgundy,
                size: 16,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '[Valeur]',
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 11,
            ),
          ),
          Container(
            height: 60,
            width: double.infinity,
            margin: const EdgeInsets.symmetric(
              vertical: 8,
            ),
            child: CustomPaint(
              painter: _PlaceholderChartPainter(),
            ),
          ),
          Center(
            child: Text(
              '[Date]',
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // LISTE DES MESURES
  // ==========================================
  Widget _buildMeasurementsList() {
    final List<Map<String, dynamic>> types = [
      {
        'label': 'Tension',
        'unit': 'mmHg',
        'icon': Icons.favorite_border,
      },
      {
        'label': 'Poids',
        'unit': 'kg',
        'icon': Icons.monitor_weight_outlined,
      },
      {
        'label': 'Glycémie',
        'unit': 'g/L',
        'icon': Icons.water_drop_outlined,
      },
      {
        'label': 'Température',
        'unit': '°C',
        'icon': Icons.thermostat_outlined,
      },
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade100,
        ),
      ),
      child: Column(
        children: types.map((t) {
          return _buildMeasurementRow(
            t['label'] as String,
            t['unit'] as String,
            t['icon'] as IconData,
          );
        }).toList(),
      ),
    );
  }

  // ==========================================
  // LIGNE D'UNE MESURE
  // ==========================================
  Widget _buildMeasurementRow(
    String label,
    String unit,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.shade100,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: burgundy,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            '[Valeur] $unit',
            style: const TextStyle(
              color: burgundy,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.chevron_right,
            color: Colors.grey,
            size: 18,
          ),
        ],
      ),
    );
  }
}

// ==========================================
// PEINTRE DU GRAPHIQUE
// ==========================================
class _PlaceholderChartPainter extends CustomPainter {
  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final Paint paint = Paint()
      ..color = const Color(0xFF800020).withValues(alpha: 0.2)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final Path path = Path();
    path.moveTo(0, size.height * 0.7);
    path.lineTo(size.width * 0.2, size.height * 0.5);
    path.lineTo(size.width * 0.4, size.height * 0.8);
    path.lineTo(size.width * 0.6, size.height * 0.4);
    path.lineTo(size.width * 0.8, size.height * 0.6);
    path.lineTo(size.width, size.height * 0.2);

    canvas.drawPath(path, paint);

    final Paint dotPaint = Paint()..color = const Color(0xFF800020);
    canvas.drawCircle(Offset(0, size.height * 0.7), 3, dotPaint);
    canvas.drawCircle(Offset(size.width * 0.2, size.height * 0.5), 3, dotPaint);
    canvas.drawCircle(Offset(size.width * 0.4, size.height * 0.8), 3, dotPaint);
    canvas.drawCircle(Offset(size.width * 0.6, size.height * 0.4), 3, dotPaint);
    canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.6), 3, dotPaint);
    canvas.drawCircle(Offset(size.width, size.height * 0.2), 3, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}