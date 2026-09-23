import 'package:flutter/material.dart';
import '../shared/app_theme.dart';

class PatientsListTab extends StatelessWidget {
  static const Color burgundy = AppColors.burgundy;

  final List<Map<String, dynamic>> patients;
  final void Function(Map<String, dynamic> patient) onSelect;

  const PatientsListTab({super.key, required this.patients, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Mes patientes',
              style: TextStyle(
                color: burgundy,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            Text(
              'Liste des patientes affectées',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
      body: patients.isEmpty
          ? const Center(
              child: Text(
                'Aucune patiente affectée pour le moment.',
                style: TextStyle(color: Colors.grey),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: patients.map(_buildCard).toList(),
            ),
    );
  }

  Widget _buildCard(Map<String, dynamic> patient) {
    final firstName = patient['first_name'] ?? '';
    final lastName = patient['last_name'] ?? '';
    final weeks = patient['pregnancy_weeks'];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onSelect(patient),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: burgundy.withValues(alpha: 0.1),
              child: const Icon(Icons.person, color: burgundy),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$firstName $lastName'.trim().isEmpty
                        ? 'Patiente sans nom'
                        : '$firstName $lastName',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  if (weeks != null)
                    Text(
                      '$weeks semaine${weeks == 1 ? '' : 's'} de grossesse',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}