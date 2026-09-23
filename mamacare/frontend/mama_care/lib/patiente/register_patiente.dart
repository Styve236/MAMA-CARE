import 'package:flutter/material.dart';
import 'package:mama_care/patiente/profil_config.dart';
import 'package:mama_care/services/api_client.dart';
import '../shared/app_theme.dart';

class RegisterPatiente extends StatefulWidget {
  const RegisterPatiente({super.key});
  @override
  State<RegisterPatiente> createState() => _RegisterPatienteState();
}

class _RegisterPatienteState extends State<RegisterPatiente> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  // Controllers pour l'étape 1
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _addressController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Variable pour l'étape 2
  bool? _isAlreadyFollowed;
  bool _isLoading = false;

  final Color burgundyColor = AppColors.burgundy;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: burgundyColor),
          onPressed: () {
            if (_currentStep > 0) {
              _pageController.previousPage(
                duration: Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          "Étape ${_currentStep + 1} sur 2",
          style: TextStyle(color: burgundyColor, fontSize: 16),
        ),
        centerTitle: true,
      ),
      body: PageView(
        controller: _pageController,
        physics: NeverScrollableScrollPhysics(), // Empêche le swipe manuel
        onPageChanged: (int page) {
          setState(() {
            _currentStep = page;
          });
        },
        children: [_buildStep1(), _buildStep2()],
      ),
    );
  }

  // --- ÉTAPE 1 : INFORMATIONS PERSONNELLES ---
  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(30),
      child: Column(
        children: [
          Image.asset('assets/images/logo_mamacare.png', height: 80),
          SizedBox(height: 20),
          Text(
            "Créer votre compte",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: burgundyColor,
            ),
          ),
          SizedBox(height: 30),
          _buildTextField(_nameController, "Nom complet", Icons.person_outline),
          SizedBox(height: 15),
          _buildTextField(
            _ageController,
            "Âge",
            Icons.cake_outlined,
            keyboardType: TextInputType.number,
          ),
          SizedBox(height: 15),
          _buildTextField(
            _addressController,
            "Localisation (Adresse)",
            Icons.location_on_outlined,
          ),
          SizedBox(height: 15),
          _buildTextField(_emailController, "Email", Icons.email_outlined),
          SizedBox(height: 15),
          _buildTextField(
            _passwordController,
            "Mot de passe",
            Icons.lock_outline,
            isPassword: true,
          ),
          SizedBox(height: 40),
          _buildButton("Continuer", () {
            _pageController.nextPage(
              duration: Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }),
        ],
      ),
    );
  }

  // --- ÉTAPE 2 : SITUATION MÉDICALE ---
  Widget _buildStep2() {
    return Padding(
      padding: EdgeInsets.all(30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "Êtes-vous déjà suivie par un médecin dans un autre centre de santé ?",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: burgundyColor,
            ),
          ),
          SizedBox(height: 40),
          _buildSelectionCard(
            "Oui",
            Icons.medical_services_outlined,
            _isAlreadyFollowed == true,
            () {
              setState(() => _isAlreadyFollowed = true);
            },
          ),
          SizedBox(height: 20),
          _buildSelectionCard(
            "Non",
            Icons.close_rounded,
            _isAlreadyFollowed == false,
            () {
              setState(() => _isAlreadyFollowed = false);
            },
          ),
          Spacer(),
          _buildButton("Terminer l'inscription", _register),
        ],
      ),
    );
  }

  // --- COMPOSANTS UI RÉUTILISABLES ---

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
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

  Widget _buildSelectionCard(
    String title,
    IconData icon,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected
              ? burgundyColor.withValues(alpha: 0.1)
              : Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isSelected ? burgundyColor : Colors.grey.shade300,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 40, color: burgundyColor),
            SizedBox(width: 20),
            Text(
              title,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: burgundyColor,
              ),
            ),
            Spacer(),
            if (isSelected) Icon(Icons.check_circle, color: burgundyColor),
          ],
        ),
      ),
    );
  }

  Widget _buildButton(String text, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: burgundyColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Inscription réussie"),
        content: Text(
          "Votre compte a été créé. Un administrateur va valider votre profil et vous affecter un médecin prochainement.",
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const ProfilConfig()),
              );
            },
            child: Text("D'accord", style: TextStyle(color: burgundyColor)),
          ),
        ],
      ),
    );
  }

  Future<void> _register() async {
    if (_isAlreadyFollowed == null ||
        _emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty ||
        _nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez remplir les champs obligatoires.'),
        ),
      );
      return;
    }
    final nameParts = _nameController.text.trim().split(RegExp(r'\s+'));
    setState(() => _isLoading = true);
    try {
      await ApiClient.register(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        firstName: nameParts.first,
        lastName: nameParts.length > 1 ? nameParts.sublist(1).join(' ') : null,
      );
      if (mounted) _showSuccessDialog();
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
}
