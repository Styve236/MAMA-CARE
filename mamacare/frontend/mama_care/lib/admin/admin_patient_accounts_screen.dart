import 'package:flutter/material.dart';
import '../services/api_client.dart';

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
  const AdminPatientAccountsScreen({super.key});

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
  List<AdminPatientAccount> _allPatients = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await ApiClient.adminPatients();
      if (!mounted) return;
      setState(() {
        _allPatients = rows
            .map((json) {
              final first = '${json['first_name'] ?? ''}'.trim();
              final last = '${json['last_name'] ?? ''}'.trim();
              final name = '$first $last'.trim();
              return AdminPatientAccount(
                id: '${json['user_id'] ?? json['id'] ?? ''}',
                name: name.isEmpty ? (json['email'] as String? ?? '—') : name,
                email: (json['email'] as String? ?? '—'),
                status: _parseStatus(json['status']),
              );
            })
            .toList();
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showMessage('Erreur', error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showMessage('Erreur', 'Impossible de charger les comptes patientes.');
    }
  }

  AdminPatientStatus _parseStatus(Object? value) {
    switch ('$value') {
      case 'pending':
        return AdminPatientStatus.pending;
      case 'active':
        return AdminPatientStatus.active;
      case 'suspended':
        return AdminPatientStatus.suspended;
      case 'disabled':
        return AdminPatientStatus.disabled;
      default:
        return AdminPatientStatus.active;
    }
  }

  List<AdminPatientAccount> get _patients {
    final query = _searchController.text.toLowerCase().trim();

    return _allPatients.where((patient) {
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
          onPressed: () => Navigator.of(context).maybePop(),
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
                    _search(),
                    const SizedBox(height: 12),
                    _filters(),
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
                    if (_loading && _allPatients.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: CircularProgressIndicator(color: burgundy),
                        ),
                      )
                    else if (_patients.isEmpty)
                      _empty()
                    else
                      _patientList(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

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

  Widget _patientList() => Column(
        children: _patients
            .map((patient) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _patientCard(patient),
                ))
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
                  _actionButton(
                      'Désactiver', () => _action('disable', patient)),
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
              const PopupMenuItem(
                  value: 'disable', child: Text('Désactiver')),
            if (!inactive)
              const PopupMenuItem(
                  value: 'suspend', child: Text('Suspendre')),
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

  Future<void> _action(String value, AdminPatientAccount patient) async {
    switch (value) {
      case 'view':
        _showMessage(
            'Compte patiente',
            '${patient.name}\n${patient.email}\n${_status(patient.status)}');
        break;
      case 'validate':
      case 'activate':
        _confirmAndApply(patient, 'active');
        break;
      case 'disable':
        _confirmAndApply(patient, 'disabled');
        break;
      case 'suspend':
        _confirmAndApply(patient, 'suspended');
        break;
      case 'assign':
        final result = await Navigator.pushNamed(
          context,
          '/admin/admin_assign_doctor_screen',
          arguments: {'initialPatientId': patient.id},
        );
        if (result == true) {
          _load();
        }
        break;
    }
  }

  Widget _actionButton(String label, VoidCallback onPressed,
      {bool destructive = false}) {
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

  Future<void> _confirmAndApply(
      AdminPatientAccount patient, String status) async {
    final label = switch (status) {
      'active' => 'Valider/Activer le compte de',
      'disabled' => 'Désactiver le compte de',
      _ => 'Suspendre le compte de',
    };
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text('$label ${patient.name} ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ApiClient.updatePatientStatus(userId: patient.id, status: status);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Compte de ${patient.name} mis à jour'),
          backgroundColor: burgundy,
        ),
      );
      _load();
    } on ApiException catch (error) {
      if (mounted) _showMessage('Erreur', error.message);
    }
  }

  void _showMessage(String title, String message) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
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