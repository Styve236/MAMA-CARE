import 'package:flutter/material.dart';

class DoctorMessagesList extends StatefulWidget {
  /// Liste des conversations récupérées depuis Supabase.
  /// Si nulle, l'interface affiche les placeholders génériques [Nom], [Heure], [Nb].
  final List<Map<String, dynamic>>? conversations;

  const DoctorMessagesList({super.key, this.conversations});

  @override
  State<DoctorMessagesList> createState() => _DoctorMessagesListState();
}

class _DoctorMessagesListState extends State<DoctorMessagesList> {
  static const Color burgundy = Color(0xFF800020);
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasConversations =
        widget.conversations != null && widget.conversations!.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: burgundy, // Couleur visible sur fond blanc
          ),
          onPressed: () {
            // Force le retour propre au dashboard médecin
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
              'Messages',
              style: TextStyle(
                color: burgundy,
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
            Text(
              'Échanges sécurisés avec vos patientes',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: burgundy, size: 28),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // BARRE DE RECHERCHE GÉNÉRIQUE
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '[Rechercher une patiente...]',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
                filled: true,
                fillColor: Colors.grey.shade50,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // LISTE DES CONVERSATIONS
          Expanded(
            child: hasConversations
                ? ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    itemCount: widget.conversations!.length,
                    itemBuilder: (context, index) =>
                        _buildConversationTile(widget.conversations![index]),
                  )
                : const Center(
                    child: Text('Aucune conversation pour le moment.'),
                  ),
          ),
        ],
      ),
      // bottomNavigationBar supprimé pour éviter le doublon
    );
  }

  Widget _buildConversationTile(Map<String, dynamic> conv) {
    final name = conv['patient_name'] ?? 'Patiente';
    final message = conv['message_text'] ?? 'Aucun message';
    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.person)),
      title: Text('$name'),
      subtitle: Text('$message', maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: () {},
    );
  }
}
