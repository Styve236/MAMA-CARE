import 'package:flutter/material.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final Color burgundyColor = const Color(0xFF800020);

  // 0 = Tension

  // 1 = Poids

  // 2 = Glycémie

  int _selectedType = 0;

  // Pour l'instant, aucune donnée ne vient de Supabase

  bool hasData = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        backgroundColor: burgundyColor,

        elevation: 0,
        //Ajout de la fleche de retour personnalisee
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            //redirige directement vers le dashboard patient
            //option 1: si vous utilise les routes nommees
            Navigator.pushReplacementNamed(context, '/patiente/dashboard');
            //option 2: si vous nutilisez pas de route nommees
            /* Navigator.pushAndRemoveUntil(
            context, MaterialPageRoute(builder: (context) => Dashboard()),
            (route) => false,
            ); */
          },
        ),

        title: const Text(
          "Mes Statistiques",

          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),

        centerTitle: true,
      ),

      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),

            // Onglets
            _buildTabSelector(),

            const SizedBox(height: 20),

            // Section statistiques
            _buildChartSection(),

            const SizedBox(height: 30),

            // Analyse IA
            _buildAIAnalysisBox(),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // ============================================================

  // ONGLET TENSION / POIDS / GLYCÉMIE

  // ============================================================

  Widget _buildTabSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),

      padding: const EdgeInsets.all(5),

      decoration: BoxDecoration(
        color: Colors.grey.shade100,

        borderRadius: BorderRadius.circular(15),
      ),

      child: Row(
        children: [
          _buildTabItem(title: "Tension", index: 0),

          _buildTabItem(title: "Poids", index: 1),

          _buildTabItem(title: "Glycémie", index: 2),
        ],
      ),
    );
  }

  // ============================================================

  // ÉLÉMENT D'UN ONGLET

  // ============================================================

  Widget _buildTabItem({required String title, required int index}) {
    final bool isSelected = _selectedType == index;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedType = index;
          });
        },

        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),

          padding: const EdgeInsets.symmetric(vertical: 12),

          decoration: BoxDecoration(
            color: isSelected ? burgundyColor : Colors.transparent,

            borderRadius: BorderRadius.circular(12),
          ),

          child: Text(
            title,

            textAlign: TextAlign.center,

            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey.shade600,

              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================

  // SECTION STATISTIQUES

  // ============================================================

  Widget _buildChartSection() {
    String title;

    if (_selectedType == 0) {
      title = "tension";
    } else if (_selectedType == 1) {
      title = "poids";
    } else {
      title = "glycémie";
    }

    return Container(
      margin: const EdgeInsets.all(20),

      padding: const EdgeInsets.all(20),

      height: 350,

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(20),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),

            blurRadius: 15,

            offset: const Offset(0, 5),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Text(
            "Évolution de la $title",

            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),

          const SizedBox(height: 4),

          const Text(
            "Sur les 7 derniers jours",

            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),

          Expanded(
            child: Center(
              child: hasData
                  ? const Text(
                      "Graphique avec données",

                      style: TextStyle(color: Colors.grey),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,

                      children: [
                        Icon(
                          Icons.show_chart,

                          size: 80,

                          color: Colors.grey.shade200,
                        ),

                        const SizedBox(height: 10),

                        Text(
                          "Aucune donnée enregistrée",

                          style: TextStyle(
                            color: Colors.grey.shade400,

                            fontSize: 14,
                          ),
                        ),

                        const SizedBox(height: 5),

                        Text(
                          "Vos mesures apparaîtront ici.",

                          style: TextStyle(
                            color: Colors.grey.shade400,

                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================

  // ANALYSE IA

  // ============================================================

  Widget _buildAIAnalysisBox() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),

      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(
        color: burgundyColor.withValues(alpha: 0.05),

        borderRadius: BorderRadius.circular(15),
      ),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Icon(Icons.auto_awesome, color: burgundyColor),

          const SizedBox(width: 15),

          Expanded(
            child: Text(
              hasData
                  ? "Analyse de vos tendances..."
                  : "En attente de vos premières mesures pour analyser vos tendances.",

              style: TextStyle(
                color: burgundyColor,

                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
