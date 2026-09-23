import 'package:flutter/material.dart';
import 'package:mama_care/services/api_client.dart';
import '../shared/app_theme.dart';

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

  @override
  void dispose() {
    _systoleController.dispose();
    _diastoleController.dispose();
    _tempController.dispose();
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
    final glycemia = double.tryParse(
      _glycemiaController.text.trim().replaceAll(',', '.'),
    );
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
            _buildField(_glycemiaController, "Glycémie", "g/L"),
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
