import 'package:flutter/material.dart';

enum AdminPatientStatus { pending, active, suspended, disabled }

class AdminPatientAccount {
  final String id;
  final String name;
  final String email;
  final AdminPatientStatus status;

  const AdminPatientAccount({
    required this.id,
    required this.name,
    required this.email,
    required this.status,
  });
}

class AdminPatientAccountsScreen extends StatefulWidget {
  final VoidCallback? onBackToDashboard;
  final List<AdminPatientAccount> patients;
  final ValueChanged<AdminPatientAccount>? onView;
  final ValueChanged<AdminPatientAccount>? onValidate;
  final ValueChanged<AdminPatientAccount>? onActivate;
  final ValueChanged<AdminPatientAccount>? onDisable;
  final ValueChanged<AdminPatientAccount>? onSuspend;
  final ValueChanged<AdminPatientAccount>? onDelete;

  const AdminPatientAccountsScreen({
    super.key,
    this.onBackToDashboard,
    this.patients = const [],
    this.onView,
    this.onValidate,
    this.onActivate,
    this.onDisable,
    this.onSuspend,
    this.onDelete,
  });

  @override
  State<AdminPatientAccountsScreen> createState() =>
      _AdminPatientAccountsScreenState();
}

class _AdminPatientAccountsScreenState
    extends State<AdminPatientAccountsScreen> {
  static const burgundy = Color(0xFF800020);
  static const background = Color(0xFFFCF9FA);
  static const lightBurgundy = Color(0xFFF8EDF0);

  final _searchController = TextEditingController();
  String _filter = 'Toutes';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AdminPatientAccount> get _patients {
    final query = _searchController.text.toLowerCase().trim();

    return widget.patients.where((patient) {
      final searchMatch = query.isEmpty ||
          patient.name.toLowerCase().contains(query) ||
          patient.email.toLowerCase().contains(query);

      final filterMatch = switch (_filter) {
        'En attente' => patient.status == AdminPatientStatus.pending,
        'Actives' => patient.status == AdminPatientStatus.active,
        'Suspendues' => patient.status == AdminPatientStatus.suspended,
        'Désactivées' => patient.status == AdminPatientStatus.disabled,
        _ => true,
      };

      return searchMatch && filterMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: burgundy),
          onPressed: () {
            if (widget.onBackToDashboard != null) {
              widget.onBackToDashboard!();
            } else {
              Navigator.of(context).maybePop();
            }
          },
        ),
        title: const Text(
          'Comptes patientes',
          style: TextStyle(color: burgundy, fontWeight: FontWeight.w700),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final horizontal = constraints.maxWidth >= 850 ? 32.0 : 18.0;

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: horizontal, vertical: 20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _intro(),
                    const SizedBox(height: 18),
                    _search(),
                    const SizedBox(height: 12),
                    _filters(),
                    const SizedBox(height: 15),
                    _actionsGuide(),
                    const SizedBox(height: 22),
                    const Text(
                      'Liste des patientes',
                      style: TextStyle(
                        color: burgundy,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _patients.isEmpty ? _empty() : _patientList(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _intro() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: lightBurgundy,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          children: [
            Icon(Icons.people_outline, color: burgundy, size: 42),
            SizedBox(width: 14),
            Expanded(
              child: Text(
                'Gestion des comptes patientes',
                style: TextStyle(
                  color: burgundy,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _search() => TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Rechercher par nom ou adresse e-mail',
          prefixIcon: const Icon(Icons.search, color: burgundy),
          filled: true,
          fillColor: Colors.white,
          border: _border(),
          enabledBorder: _border(),
          focusedBorder: _border(color: burgundy),
        ),
      );

  Widget _filters() {
    const values = [
      'Toutes',
      'En attente',
      'Actives',
      'Suspendues',
      'Désactivées',
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: values.map((value) {
          final selected = _filter == value;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(value),
              selected: selected,
              onSelected: (_) => setState(() => _filter = value),
              selectedColor: burgundy,
              backgroundColor: Colors.white,
              labelStyle: TextStyle(
                color: selected ? Colors.white : Colors.black87,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _actionsGuide() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF0E7E9)),
        ),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            const Text(
              'Actions administrateur :',
              style: TextStyle(color: burgundy, fontWeight: FontWeight.w700),
            ),
            ActionChip(label: const Text('Consulter'), onPressed: () => _showMessage('Comptes patientes', 'Sélectionnez une patiente dans la liste pour consulter son compte.')),
            ActionChip(label: const Text('Assigner'), onPressed: () => Navigator.pushNamed(context, '/admin/admin_assign_doctor_screen')),
            ActionChip(label: const Text('Valider'), onPressed: () => _showMessage('Validation', 'Sélectionnez une patiente en attente dans la liste.')),
            ActionChip(label: const Text('Activer'), onPressed: () => _showMessage('Activation', 'Sélectionnez une patiente désactivée dans la liste.')),
            ActionChip(label: const Text('Désactiver'), onPressed: () => _showMessage('Désactivation', 'Sélectionnez une patiente active dans la liste.')),
            ActionChip(label: const Text('Suspendre'), onPressed: () => _showMessage('Suspension', 'Sélectionnez une patiente active dans la liste.')),
            ActionChip(label: const Text('Supprimer'), onPressed: () => _showMessage('Suppression', 'Sélectionnez une patiente dans la liste pour confirmer sa suppression.')),
          ],
        ),
      );

  Widget _patientList() => Column(
        children: _patients
            .map(
              (patient) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _patientCard(patient),
              ),
            )
            .toList(),
      );

  Widget _patientCard(AdminPatientAccount patient) {
    final inactive = patient.status == AdminPatientStatus.disabled ||
        patient.status == AdminPatientStatus.suspended;

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFF0E7E9)),
      ),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: lightBurgundy,
          child: Icon(Icons.person_outline, color: burgundy),
        ),
        title: Text(
          patient.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(patient.email),
            Text(_status(patient.status)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _actionButton('Consulter', () => _action('view', patient)),
                _actionButton('Assigner', () => _action('assign', patient)),
                if (inactive)
                  _actionButton('Activer', () => _action('activate', patient)),
                if (!inactive)
                  _actionButton('Désactiver', () => _action('disable', patient)),
                _actionButton('Supprimer', () => _action('delete', patient), destructive: true),
              ],
            ),
          ],
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: burgundy),
          onSelected: (value) => _action(value, patient),
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'view', child: Text('Consulter')),
            if (patient.status == AdminPatientStatus.pending)
              const PopupMenuItem(value: 'validate', child: Text('Valider')),
            if (inactive)
              const PopupMenuItem(value: 'activate', child: Text('Activer')),
            if (!inactive)
              const PopupMenuItem(value: 'disable', child: Text('Désactiver')),
            if (!inactive)
              const PopupMenuItem(value: 'suspend', child: Text('Suspendre')),
            const PopupMenuItem(value: 'delete', child: Text('Supprimer')),
          ],
        ),
      ),
    );
  }

  Widget _empty() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(42),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Column(
          children: [
            Icon(Icons.person_outline, color: burgundy, size: 58),
            SizedBox(height: 14),
            Text(
              'Aucune patiente à afficher',
              style: TextStyle(
                color: burgundy,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Les comptes apparaîtront après leur enregistrement.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );

  void _action(String value, AdminPatientAccount patient) {
    switch (value) {
      case 'view':
        if (widget.onView != null) {
          widget.onView!(patient);
        } else {
          _showMessage('Compte patiente', '${patient.name}\n${patient.email}');
        }
        break;
      case 'validate':
        if (widget.onValidate != null) {
          widget.onValidate!(patient);
        } else {
          _showConfirmation('Valider le compte de ${patient.name} ?');
        }
        break;
      case 'assign':
        Navigator.pushNamed(context, '/admin/admin_assign_doctor_screen');
        break;
      case 'activate':
        if (widget.onActivate != null) {
          widget.onActivate!(patient);
        } else {
          _showConfirmation('Activer le compte de ${patient.name} ?');
        }
        break;
      case 'disable':
        if (widget.onDisable != null) {
          widget.onDisable!(patient);
        } else {
          _showConfirmation('Désactiver le compte de ${patient.name} ?');
        }
        break;
      case 'suspend':
        if (widget.onSuspend != null) {
          widget.onSuspend!(patient);
        } else {
          _showConfirmation('Suspendre le compte de ${patient.name} ?');
        }
        break;
      case 'delete':
        if (widget.onDelete != null) {
          widget.onDelete!(patient);
        } else {
          _showConfirmation('Supprimer le compte de ${patient.name} ?');
        }
        break;
    }
  }

  Widget _actionButton(String label, VoidCallback onPressed, {bool destructive = false}) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: destructive ? Colors.red.shade700 : burgundy,
        side: BorderSide(color: destructive ? Colors.red.shade200 : burgundy),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(label, style: const TextStyle(fontSize: 11)),
    );
  }

  Future<void> _showConfirmation(String message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirmer')),
        ],
      ),
    );
    if (confirmed == true && mounted) _showMessage('Action administrateur', 'Action confirmée.');
  }

  void _showMessage(String title, String message) {
    showDialog<void>(context: context, builder: (context) => AlertDialog(title: Text(title), content: Text(message), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer'))]));
  }

  String _status(AdminPatientStatus status) {
    switch (status) {
      case AdminPatientStatus.pending:
        return 'En attente';
      case AdminPatientStatus.active:
        return 'Active';
      case AdminPatientStatus.suspended:
        return 'Suspendue';
      case AdminPatientStatus.disabled:
        return 'Désactivée';
    }
  }

  OutlineInputBorder _border({Color? color}) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: color ?? const Color(0xFFF0E7E9)),
      );
}