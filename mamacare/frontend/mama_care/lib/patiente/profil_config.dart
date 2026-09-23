import 'package:flutter/material.dart';
import 'package:mama_care/patiente/dashboard.dart';

class ProfilConfig extends StatefulWidget {
  const ProfilConfig({super.key});
  @override
  State<ProfilConfig> createState() => _ProfilConfigState();
}

class _ProfilConfigState extends State<ProfilConfig> {
  final Color burgundyColor = Color(0xFF800020);

  // Contrôleurs et variables d'état
  DateTime? _dueDate;
  final _weightController = TextEditingController();
  final _historyController = TextEditingController();
  final _emergencyNameController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();

  // Fonction pour sélectionner la date d'accouchement
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(Duration(days: 30)),
      firstDate: DateTime.now().subtract(Duration(days: 30)),
      lastDate: DateTime.now().add(Duration(days: 300)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: burgundyColor, // Couleur des boutons et sélection
              onPrimary: Colors.white,
              onSurface: burgundyColor, // Couleur du texte
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _dueDate) {
      setState(() {
        _dueDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: burgundyColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Finaliser mon profil",
          style: TextStyle(color: burgundyColor, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Center(
              child: Image.asset(
                'assets/images/logo_mamacare.png',
                height: 80,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 20),
            // SECTION : MA GROSSESSE
            _buildSectionTitle("Ma Grossesse", Icons.pregnant_woman),
            _buildDatePickerField(),
            SizedBox(height: 25),

            // SECTION : MA SANTÉ
            _buildSectionTitle("Ma Santé", Icons.favorite_border),
            _buildTextField(
              _weightController,
              "Poids avant la grossesse (kg)",
              Icons.monitor_weight_outlined,
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 15),
            _buildTextField(
              _historyController,
              "Antécédents médicaux",
              Icons.history,
              maxLines: 3,
            ),
            SizedBox(height: 25),

            // SECTION : CONTACT D'URGENCE
            _buildSectionTitle("Contact d'Urgence", Icons.emergency_share),
            _buildTextField(
              _emergencyNameController,
              "Nom et prénom",
              Icons.person_outline,
            ),
            SizedBox(height: 15),
            _buildTextField(
              _emergencyPhoneController,
              "Numéro de téléphone",
              Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),

            SizedBox(height: 40),

            // BOUTON DE VALIDATION
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  // Widget pour les titres de section
  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15.0),
      child: Row(
        children: [
          Icon(icon, color: burgundyColor, size: 28),
          SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: burgundyColor,
            ),
          ),
        ],
      ),
    );
  }

  // Widget pour le sélecteur de date
  Widget _buildDatePickerField() {
    return InkWell(
      onTap: () => _selectDate(context),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 15, vertical: 18),
        decoration: BoxDecoration(
          border: Border.all(color: burgundyColor.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, color: burgundyColor),
            SizedBox(width: 15),
            Text(
              _dueDate == null
                  ? "Date prévue d'accouchement"
                  : "<LaTex>{_dueDate!.day}/</LaTex>{_dueDate!.month}/${_dueDate!.year}",
              style: TextStyle(
                color: _dueDate == null ? Colors.grey[600] : Colors.black,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget pour les champs de texte
  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: burgundyColor.withValues(alpha: 0.7)),
        prefixIcon: Icon(icon, color: burgundyColor),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: burgundyColor.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: burgundyColor, width: 2),
        ),
      ),
    );
  }

  // Widget pour le bouton de validation
  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: () {
          // Logique d'enregistrement et redirection
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const Dashboard()),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: burgundyColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(
          "Terminer l'inscription",
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
