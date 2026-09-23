import 'package:flutter/material.dart';
import 'package:mama_care/notifications_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  /// Cette fonction sera reliée plus tard à Supabase Auth.
  final VoidCallback? onLogout;

  const AdminDashboardScreen({super.key, this.onLogout});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  static const Color burgundy = Color(0xFF800020);
  static const Color lightBurgundy = Color(0xFFF8EDF0);
  static const Color pageBackground = Color(0xFFFCF9FA);

  int _selectedIndex = 0;

  final List<_AdminDestination> _destinations = const [
    _AdminDestination(
      label: 'Accueil',
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
    ),
    _AdminDestination(
      label: 'Comptes',
      icon: Icons.people_outline,
      selectedIcon: Icons.people,
    ),
    _AdminDestination(
      label: 'Validations',
      icon: Icons.verified_user_outlined,
      selectedIcon: Icons.verified_user,
    ),
    _AdminDestination(
      label: 'Statistiques',
      icon: Icons.bar_chart_outlined,
      selectedIcon: Icons.bar_chart,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isDesktop = constraints.maxWidth >= 900;
        return isDesktop ? _buildDesktopLayout() : _buildMobileLayout();
      },
    );
  }

  // =========================
  // VERSION MOBILE
  // =========================

  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: pageBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 20,
        title: Row(
          children: [
            _buildLogo(38),
            const SizedBox(width: 10),
            const Text(
              'Mamacare',
              style: TextStyle(
                color: burgundy,
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: burgundy),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
          ),
        ],
      ),
      body: _buildSelectedPage(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _selectDestination,
        backgroundColor: Colors.white,
        indicatorColor: lightBurgundy,
        height: 72,
        destinations: _destinations
            .map(
              (destination) => NavigationDestination(
                icon: Icon(destination.icon),
                selectedIcon: Icon(destination.selectedIcon),
                label: destination.label,
              ),
            )
            .toList(),
      ),
    );
  }

  // =========================
  // VERSION ORDINATEUR / WEB
  // =========================

  Widget _buildDesktopLayout() {
    return Scaffold(
      backgroundColor: pageBackground,
      body: Row(
        children: [
          _buildDesktopNavigation(),
          Expanded(
            child: Column(
              children: [
                _buildDesktopHeader(),
                Expanded(child: _buildSelectedPage()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopNavigation() {
    return Container(
      width: 250,
      color: Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 20, 34),
              child: Row(
                children: [
                  _buildLogo(44),
                  const SizedBox(width: 12),
                  const Text(
                    'Mamacare',
                    style: TextStyle(
                      color: burgundy,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'ESPACE ADMINISTRATEUR',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const SizedBox(height: 12),
            ...List.generate(
              _destinations.length,
              (index) => _buildNavigationItem(index),
            ),
            const Spacer(),
            const Divider(height: 1),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              leading: const Icon(Icons.logout_outlined, color: burgundy),
              title: const Text(
                'Se déconnecter',
                style: TextStyle(
                  color: burgundy,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () {
                _showLogoutDialog();
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopHeader() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_destinations[_selectedIndex].label, style: const TextStyle(color: burgundy, fontSize: 26, fontWeight: FontWeight.w700)),
              IconButton(
                icon: const Icon(Icons.notifications_none, color: burgundy),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Gestion et supervision de l\'application Mamacare',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationItem(int index) {
    final destination = _destinations[index];
    final bool selected = _selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      child: Material(
        color: selected ? lightBurgundy : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _selectDestination(index),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 13,
            ),
            child: Row(
              children: [
                Icon(
                  selected ? destination.selectedIcon : destination.icon,
                  color: selected ? burgundy : Colors.grey.shade700,
                  size: 21,
                ),
                const SizedBox(width: 13),
                Text(
                  destination.label,
                  style: TextStyle(
                    color: selected ? burgundy : Colors.grey.shade800,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // =========================
  // NAVIGATION DES PAGES
  // =========================

  Widget _buildSelectedPage() {
    switch (_selectedIndex) {
      case 1:
        return _buildEmptySection(
          icon: Icons.people_outline,
          title: 'Gestion des comptes',
          description:
              'Les comptes des patientes et des médecins apparaîtront ici après la connexion à Supabase.',
        );
      case 2:
        return _buildEmptySection(
          icon: Icons.verified_user_outlined,
          title: 'Validation des comptes patientes',
          description:
              'Les demandes de validation en attente apparaîtront ici.',
        );
      case 3:
        return _buildEmptySection(
          icon: Icons.bar_chart_outlined,
          title: 'Statistiques globales',
          description:
              'Les indicateurs et graphiques globaux seront chargés depuis les données réelles.',
        );
      default:
        return _buildDashboardHome();
    }
  }

  // =========================
  // ACCUEIL DU TABLEAU DE BORD
  // =========================

  Widget _buildDashboardHome() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWelcomeBanner(),
              const SizedBox(height: 24),
              const Text(
                'Vue générale',
                style: TextStyle(
                  color: burgundy,
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              _buildSummaryGrid(),
              const SizedBox(height: 28),
              const Text(
                'Actions principales',
                style: TextStyle(
                  color: burgundy,
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              _buildActionList(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: lightBurgundy,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF0DDE2)),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: burgundy,
              borderRadius: BorderRadius.circular(17),
            ),
            child: const Icon(
              Icons.admin_panel_settings_outlined,
              color: Colors.white,
              size: 29,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bienvenue dans votre espace administrateur',
                  style: TextStyle(
                    color: burgundy,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Gérez l\'application Mamacare en toute simplicité.',
                  style: TextStyle(color: Colors.black54, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryGrid() {
    const cards = [
      _SummaryCardData(
        title: 'Comptes utilisateurs',
        value: '—',
        subtitle: 'Patientes et médecins',
        icon: Icons.people_outline,
      ),
      _SummaryCardData(
        title: 'Médecins en attente',
        value: '—',
        subtitle: 'Comptes à traiter',
        icon: Icons.medical_services_outlined,
      ),
      _SummaryCardData(
        title: 'Patientes en attente',
        value: '—',
        subtitle: 'Demandes à valider',
        icon: Icons.fact_check_outlined,
      ),
      _SummaryCardData(
        title: 'Activité globale',
        value: '—',
        subtitle: 'Données disponibles après connexion',
        icon: Icons.insights_outlined,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final int columns = constraints.maxWidth >= 650 ? 2 : 1;

        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: columns == 2 ? 2.05 : 2.4,
          children: cards.map(_buildSummaryCard).toList(),
        );
      },
    );
  }

  Widget _buildSummaryCard(_SummaryCardData data) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF0E7E9)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C800020),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: lightBurgundy,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(data.icon, color: burgundy, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  data.value,
                  style: const TextStyle(
                    color: burgundy,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  data.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================
  // ACTIONS PRINCIPALES
  // =========================

  Widget _buildActionList() {
    return Column(
      children: [
        _buildActionTile(
          icon: Icons.people_outline,
          title: 'Gérer les comptes',
          subtitle: 'Consulter les patientes et les médecins enregistrés',
          onTap: () {
            Navigator.pushNamed(
              context, '/admin/admin_account_management_screen',
            );
          },
        ),
        const SizedBox(height: 12),
        _buildActionTile(
          icon: Icons.medical_services_outlined,
          title: 'Gérer les médecins',
          subtitle:
              'Valider les médecins et attribuer un médecin à une patiente',
          onTap: () {
            Navigator.pushNamed(context,'/admin/admin_doctor_accounts_screen',
            );
          },
          ),
        
        const SizedBox(height: 12),
        _buildActionTile(
          icon: Icons.verified_user_outlined,
          title: 'Valider les comptes patientes',
          subtitle: 'Traiter les demandes en attente de validation',
          onTap: () {
            Navigator.pushNamed(context,'/admin/admin_patient_accounts_screen',

            );
          },
        ),
        const SizedBox(height: 12),
        _buildActionTile(
          icon: Icons.bar_chart_outlined,
          title: 'Consulter les statistiques globales',
          subtitle: 'Visualiser les indicateurs généraux de l\'application',
          onTap: () {
            Navigator.pushNamed(context, '/admin/admin_global_statistics_screen',
            );
          },
        ),
        const SizedBox(height: 12),
        _buildActionTile(
          icon: Icons.fact_check_outlined,
          title: 'Journal d’activité',
          subtitle: 'Consulter les actions réalisées sur l\'application',
          onTap: () {
            Navigator.pushNamed(context, '/admin/admin_activity_log_entry_screen',
            );
          },
          ),
        
        const SizedBox(height: 12),
        _buildActionTile(
          icon: Icons.logout_outlined,
          title: 'Se déconnecter',
          subtitle: 'Fermer la session administrateur sur cet appareil',
          isLogout: true,
          onTap: () {
             _showLogoutDialog() ;
              
            
          },
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isLogout = false,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: const Color(0xFFF0E7E9)),
          ),
          child: Row(
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: lightBurgundy,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: burgundy, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isLogout ? burgundy : Colors.black87,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (!isLogout)
                const Icon(Icons.chevron_right, color: burgundy),
            ],
          ),
        ),
      ),
    );
  }

  // =========================
  // ÉCRANS SECONDAIRES
  // =========================

  Widget _buildEmptySection({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 45),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFF0E7E9)),
            ),
            child: Column(
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: lightBurgundy,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Icon(icon, color: burgundy, size: 34),
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: burgundy,
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // =========================
  // OUTILS ET DÉCONNEXION
  // =========================

  Widget _buildLogo(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: burgundy,
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(
            color: Color(0x22800020),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Icon(
        Icons.favorite_outline,
        color: Colors.white,
        size: size * 0.54,
      ),
    );
  }

  void _selectDestination(int index) {
    setState(() => _selectedIndex = index);
  }

  void showPlannedSection({
    required String title,
    required IconData icon,
    required String description,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminPlaceholderScreen(
          title: title,
          icon: icon,
          description: description,
        ),
      ),
    );
  }

  Future<void> _showLogoutDialog() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Se déconnecter ?'),
          content: const Text(
            'La session administrateur sera fermée sur cet appareil.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'Annuler',
                style: TextStyle(color: burgundy),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: burgundy),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Se déconnecter'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      widget.onLogout?.call();
    }
  }
}

// Écran temporaire propre pour les fonctionnalités qui seront connectées
// à Supabase dans la prochaine étape.
class AdminPlaceholderScreen extends StatelessWidget {
  final String title;
  final IconData icon;
  final String description;

  const AdminPlaceholderScreen({
    super.key,
    required this.title,
    required this.icon,
    required this.description,
  });

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
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: burgundy,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 650),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFF0E7E9)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: lightBurgundy,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Icon(icon, color: burgundy, size: 36),
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: burgundy,
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminDestination {
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  const _AdminDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
}

class _SummaryCardData {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;

  const _SummaryCardData({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
  });
}