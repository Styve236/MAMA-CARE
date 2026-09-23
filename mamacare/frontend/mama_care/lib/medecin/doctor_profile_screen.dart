import 'package:flutter/material.dart';

class DoctorProfileScreen extends StatefulWidget {
  /// Données du médecin récupérées depuis Supabase
  final Map<String, dynamic>? doctorData;

  const DoctorProfileScreen({super.key, this.doctorData});

  @override
  State<DoctorProfileScreen> createState() => _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends State<DoctorProfileScreen> {
  static const Color burgundy = Color(0xFF800020);

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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // SECTION PHOTO DE PROFIL
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: burgundy.withValues(alpha: 0.1),
                    child: const Icon(Icons.person, size: 60, color: burgundy),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: burgundy,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '[Nom du Docteur]',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const Text(
              '[Spécialité / Gynécologue]',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 30),

            // INFORMATIONS PROFESSIONNELLES
            _buildProfileItem(
              icon: Icons.local_hospital,
              title: 'Centre de santé',
              subtitle: '[Nom de l\'établissement]',
            ),
            _buildProfileItem(
              icon: Icons.phone,
              title: 'Numéro de téléphone',
              subtitle: '[+237 6xx xxx xxx]',
              onTap: () {
                // Logique pour modifier le téléphone
              },
            ),
            _buildProfileItem(
              icon: Icons.email,
              title: 'Adresse Email',
              subtitle: '[docteur@email.com]',
            ),

            const Divider(height: 40),

            // SÉCURITÉ ET PARAMÈTRES
            _buildProfileItem(
              icon: Icons.lock_outline,
              title: 'Modifier le mot de passe',
              subtitle: 'Sécurisez votre compte',
              onTap: () {
                // Logique pour changer le mot de passe
              },
            ),
            _buildProfileItem(
              icon: Icons.notifications_active_outlined,
              title: 'Notifications',
              subtitle: 'Gérer les alertes IA',
              onTap: () {},
            ),

            const SizedBox(height: 40),

            // BOUTON DÉCONNEXION
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // Logique de déconnexion
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: burgundy),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Déconnexion',
                  style: TextStyle(
                    color: burgundy,
                    fontWeight: FontWeight.bold,
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

  Widget _buildProfileItem({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: burgundy.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: burgundy),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: Colors.grey, fontSize: 13),
      ),
      trailing: onTap != null
          ? const Icon(Icons.chevron_right, color: Colors.grey)
          : null,
      onTap: onTap,
    );
  }
}
