import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../shared/app_theme.dart';

class DoctorProfileScreen extends StatefulWidget {
  final Map<String, dynamic>? doctorData;

  const DoctorProfileScreen({super.key, this.doctorData});

  @override
  State<DoctorProfileScreen> createState() => _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends State<DoctorProfileScreen> {
  static const Color burgundy = AppColors.burgundy;
  static const Color lightBurgundy = Color(0xFFF9E8EC);

  bool _loading = true;
  bool _saving = false;

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _specializationController = TextEditingController();
  final _hospitalController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _specializationController.dispose();
    _hospitalController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    Map<String, dynamic>? data = widget.doctorData;
    if (data == null) {
      try {
        data = await ApiClient.doctorProfile();
      } catch (_) {
        data = null;
      }
    }
    if (!mounted) return;
    setState(() {
      _firstNameController.text = '${data?['first_name'] ?? ''}';
      _lastNameController.text = '${data?['last_name'] ?? ''}';
      _emailController.text = '${data?['email'] ?? ''}';
      _phoneController.text = '${data?['phone'] ?? ''}';
      _specializationController.text = '${data?['specialization'] ?? ''}';
      _hospitalController.text = '${data?['hospital_affiliation'] ?? ''}';
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ApiClient.updateDoctorProfile(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        specialization: _specializationController.text.trim(),
        hospitalAffiliation: _hospitalController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil mis à jour avec succès'),
          backgroundColor: burgundy,
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _logout() {
    ApiClient.logout();
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: burgundy),
          onPressed: () {
            Navigator.pushReplacementNamed(
              context,
              '/medecin/doctor_dashboard_mobile',
            );
          },
        ),
        title: const Text(
          'Mon Profil',
          style: TextStyle(color: burgundy, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: burgundy))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: CircleAvatar(
                      radius: 60,
                      backgroundColor: lightBurgundy,
                      child:
                          const Icon(Icons.person, size: 60, color: burgundy),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Informations personnelles',
                    style: TextStyle(
                      color: burgundy,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildField('Prénom', _firstNameController),
                  const SizedBox(height: 12),
                  _buildField('Nom', _lastNameController),
                  const SizedBox(height: 12),
                  _buildField('Adresse Email', _emailController,
                      keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 12),
                  _buildField('Numéro de téléphone', _phoneController,
                      keyboardType: TextInputType.phone),
                  const SizedBox(height: 24),
                  const Text(
                    'Informations professionnelles',
                    style: TextStyle(
                      color: burgundy,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildField('Spécialité', _specializationController),
                  const SizedBox(height: 12),
                  _buildField('Centre de santé', _hospitalController),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: burgundy,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 3,
                      ),
                      child: _saving
                          ? const CircularProgressIndicator(
                              color: Colors.white)
                          : const Text(
                              'Enregistrer',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _logout,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: burgundy),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Déconnexion',
                        style: TextStyle(
                          color: burgundy,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
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

  Widget _buildField(
    String label,
    TextEditingController controller, {
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: burgundy),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: burgundy, width: 1.6),
          borderRadius: BorderRadius.circular(10),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: burgundy.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}