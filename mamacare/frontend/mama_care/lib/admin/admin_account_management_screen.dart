import 'package:flutter/material.dart';

class AdminAccountManagementScreen extends StatelessWidget {

  const AdminAccountManagementScreen({super.key});

  static const Color burgundy = Color(0xFF800020);

  static const Color lightBurgundy = Color(0xFFF8EDF0);

  @override

  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: const Color(0xFFFCF9FA),

      appBar: AppBar(

        backgroundColor: Colors.white,

        elevation: 0,

        leading: IconButton(

          icon: const Icon(Icons.arrow_back, color: burgundy),

          onPressed: () => Navigator.pop(context),

        ),

        title: const Text(

          'Gestion des comptes',

          style: TextStyle(

            color: burgundy,

            fontWeight: FontWeight.w700,

          ),

        ),

      ),

      body: Padding(

        padding: const EdgeInsets.all(24),

        child: Column(

          children: [

            _accountOption(

              context,

              icon: Icons.person_outline,

              title: 'Gérer les patientes',

              description: 'Consulter et gérer les comptes patientes',

              route: '/admin/admin_patient_accounts_screen',

            ),

            const SizedBox(height: 16),

            _accountOption(

              context,

              icon: Icons.medical_services_outlined,

              title: 'Gérer les médecins',

              description: 'Consulter et gérer les comptes médecins',

              route: '/admin/admin_doctor_accounts_screen',

            ),

          ],

        ),

      ),

    );

  }

  Widget _accountOption(

    BuildContext context, {

    required IconData icon,

    required String title,

    required String description,

    required String route,

  }) {

    return Card(

      elevation: 0,

      color: Colors.white,

      shape: RoundedRectangleBorder(

        borderRadius: BorderRadius.circular(18),

        side: const BorderSide(

          color: Color(0xFFF0E7E9),

        ),

      ),

      child: ListTile(

        contentPadding: const EdgeInsets.all(18),

        leading: Container(

          width: 50,

          height: 50,

          decoration: BoxDecoration(

            color: lightBurgundy,

            borderRadius: BorderRadius.circular(15),

          ),

          child: Icon(

            icon,

            color: burgundy,

            size: 26,

          ),

        ),

        title: Text(

          title,

          style: const TextStyle(

            color: burgundy,

            fontWeight: FontWeight.w700,

          ),

        ),

        subtitle: Padding(

          padding: const EdgeInsets.only(top: 5),

          child: Text(description),

        ),

        trailing: const Icon(

          Icons.chevron_right,

          color: burgundy,

        ),

        onTap: () {

          Navigator.pushNamed(context, route);

        },

      ),

    );

  }

}