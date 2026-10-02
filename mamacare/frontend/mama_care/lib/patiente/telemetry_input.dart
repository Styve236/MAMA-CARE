import 'package:flutter/material.dart';
import 'package:mama_care/services/api_client.dart';
import '../shared/app_theme.dart';
import '../shared/glucose.dart';

class TelemetryInput extends StatefulWidget {
  const TelemetryInput({super.key});
  @override
  State<TelemetryInput> createState() => _TelemetryInputState();
}

class _TelemetryInputState extends State<TelemetryInput> {
  final Color burgundyColor = AppColors.burgundy;

  // Contrôleurs pour récupérer les saisies
  final _systoleController = TextEditingController();
  final _diastoleController = TextEditingController();
  final _tempController = TextEditingController();
  final _glycemiaController = TextEditingController();
  final _weightController = TextEditingController();
  bool _isLoading = false;

  GlucoseStatus? _glucoseStatus;
  bool _glucoseTypedMgDl = false;

  @override
  void initState() {
    super.initState();
    _glycemiaController.addListener(_onGlycemiaChanged);
  }

  /// La patiente saisit en mmol/L : on l'informe en direct si sa valeur est
  /// sous la normale, normale ou trop elevee, et on affiche l'equivalent
  /// en mg/dL de son appareil. Aucune saisie n'est refusee ici.
  void _onGlycemiaChanged() {
    final typed = double.tryParse(
      _glycemiaController.text.trim().replaceAll(',', '.'),
    );
    if (typed == null || typed <= 0) {
      if (_glucoseStatus != null) {
        setState(() {
          _glucoseStatus = null;
          _glucoseTypedMgDl = false;
        });
      }
      return;
    }
    // Une saisie au-dessus du seuil est lue en mg/dL puis ramenee en
    // mmol/L, qui reste l'unite du systeme.
    final mmol = normalizeGlucoseInput(typed);
    final status = glucoseStatus(mmol);
    final asMgDl = glucoseTypedInMgDl(typed);
    if (status != _glucoseStatus || asMgDl != _glucoseTypedMgDl) {
      setState(() {
        _glucoseStatus = status;
        _glucoseTypedMgDl = asMgDl;
      });
    }
  }

  @override
  void dispose() {
    _systoleController.dispose();
    _diastoleController.dispose();
    _tempController.dispose();
    _glycemiaController.removeListener(_onGlycemiaChanged);
    _glycemiaController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _saveTelemetry() async {
    final systole = int.tryParse(_systoleController.text.trim());
    final diastole = int.tryParse(_diastoleController.text.trim());
    final temperature = double.tryParse(
      _tempController.text.trim().replaceAll(',', '.'),
    );
    final glycemiaTyped = double.tryParse(
      _glycemiaController.text.trim().replaceAll(',', '.'),
    );
    // L'API et l'IA travaillent en mmol/L : on y ramene la saisie.
    final glycemia =
        glycemiaTyped == null ? null : normalizeGlucoseInput(glycemiaTyped);
    final weight = double.tryParse(
      _weightController.text.trim().replaceAll(',', '.'),
    );

    if (systole == null ||
        diastole == null ||
        temperature == null ||
        glycemia == null ||
        weight == null ||
        systole <= 0 ||
        diastole <= 0 ||
        temperature <= 0 ||
        glycemia <= 0 ||
        weight <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez saisir des mesures valides.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ApiClient.createPatientTelemetry(
        weight: weight,
        bloodPressureSystolic: systole,
        bloodPressureDiastolic: diastole,
        temperature: temperature,
        bloodGlucose: glycemia,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Mesures enregistrées.')));
      Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: burgundyColor,
        title: Text(
          "Ajouter mes mesures",
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle("1. TENSION"),
            Row(
              children: [
                Expanded(
                  child: _buildField(_systoleController, "Systole", "mmHg"),
                ),
                SizedBox(width: 15),
                Expanded(
                  child: _buildField(_diastoleController, "Diastole", "mmHg"),
                ),
              ],
            ),
            SizedBox(height: 25),
            _buildSectionTitle("2. TEMPÉRATURE"),
            _buildField(_tempController, "Température", "°C"),
            SizedBox(height: 25),
            _buildSectionTitle("3. GLYCÉMIE"),
            _buildGlycemiaField(),
            SizedBox(height: 25),
            _buildSectionTitle("4. POIDS"),
            _buildField(_weightController, "Poids", "kg"),
            SizedBox(height: 40),

            // Info IA
            Container(
              padding: EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: burgundyColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, color: burgundyColor),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "L'IA analysera vos données après l'enregistrement.",
                      style: TextStyle(color: burgundyColor),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 30),

            // Bouton Enregistrer
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveTelemetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: burgundyColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : const Text(
                        "Enregistrer",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlycemiaField() {
    final status = _glucoseStatus;
    final typed = double.tryParse(
      _glycemiaController.text.trim().replaceAll(',', '.'),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildField(_glycemiaController, "Glycémie", "mmol/L"),
        if (_glucoseTypedMgDl) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.swap_horiz, size: 18, color: Colors.blueGrey),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Lue en mg/dL : $typed mg/dL = '
                  '${_trimmed(normalizeGlucoseInput(typed!))} mmol/L',
                  style: const TextStyle(
                    color: Colors.blueGrey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
        if (status != null) ...[
          SizedBox(height: 8),
          Row(
            children: [
              Icon(_glucoseIcon(status), size: 18, color: _glucoseColor(status)),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${glucoseStatusLabel(status)} · '
                  '${glucoseToMgDl(normalizeGlucoseInput(typed!)).round()} mg/dL',
                  style: TextStyle(
                    color: _glucoseColor(status),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }


  String _trimmed(double value) =>
      value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1).replaceAll('.', ',');

  Color _glucoseColor(GlucoseStatus status) {
    switch (status) {
      case GlucoseStatus.veryLow:
      case GlucoseStatus.veryHigh:
        return Colors.red;
      case GlucoseStatus.low:
      case GlucoseStatus.high:
        return Colors.orange;
      case GlucoseStatus.normal:
        return Colors.green;
    }
  }

  IconData _glucoseIcon(GlucoseStatus status) {
    switch (status) {
      case GlucoseStatus.veryLow:
      case GlucoseStatus.veryHigh:
        return Icons.error_outline;
      case GlucoseStatus.low:
      case GlucoseStatus.high:
        return Icons.warning_amber_rounded;
      case GlucoseStatus.normal:
        return Icons.check_circle_outline;
    }
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: burgundyColor,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildField(
    TextEditingController controller,
    String hint,
    String unit,
  ) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number, // Ouvre le clavier numérique
      decoration: InputDecoration(
        hintText: hint,
        suffixText: unit,
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(10),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: burgundyColor),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}
