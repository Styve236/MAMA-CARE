import 'package:flutter/material.dart';

class DoctorAlertsCenter extends StatefulWidget {
  /// Liste des alertes récupérées depuis Supabase.
  /// Si nulle, l'interface affiche les placeholders génériques.
  final List<Map<String, dynamic>>? alerts;

  const DoctorAlertsCenter({super.key, this.alerts});

  @override
  State<DoctorAlertsCenter> createState() => _DoctorAlertsCenterState();
}

class _DoctorAlertsCenterState extends State<DoctorAlertsCenter> {
  static const Color burgundy = Color(0xFF800020);
  int _selectedFilterIndex = 0;

  final List<String> _filters = ['[Toutes]', '[Critiques]', '[Modérées]'];

  @override
  Widget build(BuildContext context) {
    final hasAlerts = widget.alerts != null && widget.alerts!.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        // FLÈCHE DE RETOUR FONCTIONNELLE VERS LE DASHBOARD MÉDECIN
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: burgundy),
          onPressed: () {
            Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil(
              '/medecin/doctor_dashboard_mobile',
              (route) => false,
            );
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Centre d\'Alertes',
              style: TextStyle(
                color: burgundy,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            Text(
              'Notifications critiques détectées par l\'IA',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // SECTION FILTRES (Critiques, Modérées, etc.)
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _filters.length,
              itemBuilder: (context, index) {
                final isSelected = _selectedFilterIndex == index;
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: FilterChip(
                    label: Text(_filters[index]),
                    selected: isSelected,
                    onSelected: (val) {
                      setState(() => _selectedFilterIndex = index);
                    },
                    selectedColor: burgundy,
                    checkmarkColor: Colors.white,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : burgundy,
                      fontWeight: FontWeight.bold,
                    ),
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: burgundy),
                    ),
                  ),
                );
              },
            ),
          ),

          // LISTE DES ALERTES (Dynamique ou Placeholders)
          Expanded(
            child: hasAlerts
                ? ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: widget.alerts!.length,
                    itemBuilder: (context, index) =>
                        _buildAlertCard(widget.alerts![index]),
                  )
                : const Center(
                    child: Text('Aucune alerte à traiter pour le moment.'),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(Map<String, dynamic> alert) {
    return Container();
  }
}
