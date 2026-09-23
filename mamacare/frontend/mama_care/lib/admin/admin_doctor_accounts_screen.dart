import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:mama_care/services/api_client.dart';

enum AdminDoctorStatus { active, pending, disabled }

class AdminDoctorAccount {
  final String id;
  final String name;
  final String email;
  final String healthCenter;
  final int patientCount;
  final AdminDoctorStatus status;

  const AdminDoctorAccount({
    required this.id,
    required this.name,
    required this.email,
    required this.healthCenter,
    required this.patientCount,
    required this.status,
  });
}

class _DoctorFormValues {
  final String name;
  final String email;
  final String password;

  const _DoctorFormValues({
    required this.name,
    required this.email,
    required this.password,
  });
}

class _DoctorCreationDialog extends StatefulWidget {
  const _DoctorCreationDialog();

  @override
  State<_DoctorCreationDialog> createState() => _DoctorCreationDialogState();
}

class _DoctorCreationDialogState extends State<_DoctorCreationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      _DoctorFormValues(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Créer un compte médecin'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nom complet'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Le nom est obligatoire'
                  : null,
            ),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Adresse e-mail'),
              keyboardType: TextInputType.emailAddress,
              validator: (value) => value == null || !value.contains('@')
                  ? 'E-mail invalide'
                  : null,
            ),
            TextFormField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Mot de passe'),
              obscureText: true,
              validator: (value) => value == null || value.length < 6
                  ? '6 caractères minimum'
                  : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Créer')),
      ],
    );
  }
}

class AdminDoctorAccountsScreen extends StatefulWidget {
  final VoidCallback? onBackToDashboard;
  final VoidCallback? onCreateDoctor;
  final List<AdminDoctorAccount> doctors;
  final ValueChanged<AdminDoctorAccount>? onView;
  final ValueChanged<AdminDoctorAccount>? onActivate;
  final ValueChanged<AdminDoctorAccount>? onDisable;
  final ValueChanged<AdminDoctorAccount>? onDelete;

  const AdminDoctorAccountsScreen({
    super.key,
    this.onBackToDashboard,
    this.onCreateDoctor,
    this.doctors = const [],
    this.onView,
    this.onActivate,
    this.onDisable,
    this.onDelete,
  });

  @override
  State<AdminDoctorAccountsScreen> createState() =>
      _AdminDoctorAccountsScreenState();
}

class _AdminDoctorAccountsScreenState extends State<AdminDoctorAccountsScreen> {
  static const burgundy = Color(0xFF800020);
  static const background = Color(0xFFFCF9FA);
  static const lightBurgundy = Color(0xFFF8EDF0);

  final _searchController = TextEditingController();
  String _filter = 'Tous';
  List<AdminDoctorAccount> _doctorsList = [];
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _doctorsList = List<AdminDoctorAccount>.from(widget.doctors);
    _searchController.addListener(() => setState(() {}));
    fetchDoctors();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AdminDoctorAccount> get _doctors {
    final query = _searchController.text.toLowerCase().trim();

    return _doctorsList.where((doctor) {
      final searchMatch =
          query.isEmpty ||
          doctor.name.toLowerCase().contains(query) ||
          doctor.email.toLowerCase().contains(query) ||
          doctor.healthCenter.toLowerCase().contains(query);

      final filterMatch = switch (_filter) {
        'Actifs' => doctor.status == AdminDoctorStatus.active,
        'En attente' => doctor.status == AdminDoctorStatus.pending,
        'Désactivés' => doctor.status == AdminDoctorStatus.disabled,
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
          'Comptes médecins',
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
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _submitting ? null : _createDoctor,
                        icon: const Icon(Icons.person_add_alt_1_outlined),
                        label: const Text('Créer un compte médecin'),
                        style: FilledButton.styleFrom(
                          backgroundColor: burgundy,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _search(),
                    const SizedBox(height: 12),
                    _filters(),
                    const SizedBox(height: 15),
                    _actionsGuide(),
                    const SizedBox(height: 22),
                    const Text(
                      'Liste des médecins',
                      style: TextStyle(
                        color: burgundy,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _loading
                        ? const Center(child: CircularProgressIndicator())
                        : _doctors.isEmpty
                        ? _empty()
                        : _doctorList(),
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
        Icon(Icons.medical_services_outlined, color: burgundy, size: 42),
        SizedBox(width: 14),
        Expanded(
          child: Text(
            'Gestion des comptes médecins',
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
      hintText: 'Rechercher par nom, e-mail ou centre de santé',
      prefixIcon: const Icon(Icons.search, color: burgundy),
      filled: true,
      fillColor: Colors.white,
      border: _border(),
      enabledBorder: _border(),
      focusedBorder: _border(color: burgundy),
    ),
  );

  Widget _filters() {
    const values = ['Tous', 'Actifs', 'En attente', 'Désactivés'];

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
        ActionChip(
          label: const Text('Créer un compte'),
          onPressed: _submitting ? null : _createDoctor,
        ),
        ActionChip(
          label: const Text('Assigner'),
          onPressed: () =>
              Navigator.pushNamed(context, '/admin/admin_assign_doctor_screen'),
        ),
        ActionChip(
          label: const Text('Générer une clé temporaire'),
          onPressed: () => _showMessage(
            'Clé temporaire',
            'Sélectionnez un médecin dans la liste pour générer une clé.',
          ),
        ),
        ActionChip(
          label: const Text('Consulter la charge'),
          onPressed: () => _showMessage(
            'Charge des médecins',
            'Sélectionnez un médecin dans la liste pour consulter sa charge.',
          ),
        ),
      ],
    ),
  );

  Widget _doctorList() => Column(
    children: _doctors
        .map(
          (doctor) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _doctorCard(doctor),
          ),
        )
        .toList(),
  );

  Widget _doctorCard(AdminDoctorAccount doctor) {
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
          doctor.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(doctor.healthCenter),
            Text('Patientes suivies : ${doctor.patientCount}'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _actionButton('Consulter', () => _action('view', doctor)),
                _actionButton('Assigner', () => _action('assign', doctor)),
                if (doctor.status == AdminDoctorStatus.disabled)
                  _actionButton('Activer', () => _action('activate', doctor)),
                if (doctor.status != AdminDoctorStatus.disabled)
                  _actionButton('Désactiver', () => _action('disable', doctor)),
                _actionButton(
                  'Supprimer',
                  () => _action('delete', doctor),
                  destructive: true,
                ),
              ],
            ),
          ],
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: burgundy),
          onSelected: (value) => _action(value, doctor),
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'view', child: Text('Consulter')),
            const PopupMenuItem(value: 'assign', child: Text('Assigner')),
            const PopupMenuItem(
              value: 'temporary_key',
              child: Text('Générer une clé temporaire'),
            ),
            const PopupMenuItem(
              value: 'load',
              child: Text('Consulter la charge'),
            ),
            if (doctor.status == AdminDoctorStatus.disabled)
              const PopupMenuItem(value: 'activate', child: Text('Activer')),
            if (doctor.status != AdminDoctorStatus.disabled)
              const PopupMenuItem(value: 'disable', child: Text('Désactiver')),
            const PopupMenuItem(value: 'delete', child: Text('Supprimer')),
          ],
        ),
      ),
    );
  }

  Widget _actionButton(
    String label,
    VoidCallback onPressed, {
    bool destructive = false,
  }) {
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

  Widget _empty() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(42),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
    ),
    child: const Column(
      children: [
        Icon(Icons.medical_services_outlined, color: burgundy, size: 58),
        SizedBox(height: 14),
        Text(
          'Aucun médecin à afficher',
          style: TextStyle(
            color: burgundy,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Les comptes médecins apparaîtront après leur création.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      ],
    ),
  );

  void _action(String value, AdminDoctorAccount doctor) {
    switch (value) {
      case 'view':
        if (widget.onView != null) {
          widget.onView!(doctor);
        } else {
          _showMessage('Compte médecin', '${doctor.name}\n${doctor.email}');
        }
        break;
      case 'assign':
        Navigator.pushNamed(context, '/admin/admin_assign_doctor_screen');
        break;
      case 'activate':
        _changeDoctorStatus(doctor, 'active');
        break;
      case 'disable':
        _changeDoctorStatus(doctor, 'disabled');
        break;
      case 'delete':
        if (widget.onDelete != null) {
          widget.onDelete!(doctor);
        } else {
          _showConfirmation('Supprimer le compte de ${doctor.name} ?');
        }
        break;
      case 'temporary_key':
        _showMessage(
          'Clé temporaire',
          'TMP-${DateTime.now().millisecondsSinceEpoch}',
        );
        break;
      case 'load':
        _showMessage(
          'Charge de ${doctor.name}',
          '${doctor.patientCount} patiente(s) suivie(s).',
        );
        break;
    }
  }

  Future<void> _createDoctor() async {
    if (widget.onCreateDoctor != null) {
      widget.onCreateDoctor!();
      return;
    }
    final values = await showDialog<_DoctorFormValues>(
      context: context,
      builder: (_) => const _DoctorCreationDialog(),
    );
    if (values == null || !mounted) {
      return;
    }

    final nameParts = values.name.split(RegExp(r'\s+'));
    final firstName = nameParts.first;
    final lastName = nameParts.length > 1
        ? nameParts.sublist(1).join(' ')
        : null;
    setState(() => _submitting = true);
    try {
      await ApiClient.createDoctor(
        email: values.email,
        password: values.password,
        firstName: firstName,
        lastName: lastName,
      );
      if (!mounted) return;
      await fetchDoctors();
      if (!mounted) return;
      _showMessage(
        'Compte médecin',
        'Le compte médecin a été créé avec succès.',
      );
    } on ApiException catch (error) {
      developer.log('Erreur création médecin: ${error.message}', level: 1000);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (error) {
      developer.log('Erreur création médecin: $error', level: 1000);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible de créer le compte médecin.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _changeDoctorStatus(
    AdminDoctorAccount doctor,
    String status,
  ) async {
    final action = status == 'disabled' ? 'Désactiver' : 'Activer';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text('$action le compte de ${doctor.name} ?'),
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

    setState(() => _submitting = true);
    try {
      await ApiClient.updateDoctorStatus(userId: doctor.id, status: status);
      await fetchDoctors();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> fetchDoctors() async {
    try {
      final doctors = await ApiClient.adminDoctors();
      if (!mounted) return;
      setState(() {
        _doctorsList = doctors.map(_doctorFromJson).toList();
        _loading = false;
      });
    } on ApiException catch (error) {
      developer.log(
        'Erreur chargement médecins: ${error.message}',
        level: 1000,
      );
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (error) {
      developer.log('Erreur chargement médecins: $error', level: 1000);
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de charger les médecins.')),
        );
      }
    }
  }

  AdminDoctorAccount _doctorFromJson(Map<String, dynamic> json) {
    final status = switch (json['status'] as String?) {
      'disabled' => AdminDoctorStatus.disabled,
      'pending' => AdminDoctorStatus.pending,
      _ => AdminDoctorStatus.active,
    };
    final firstName = json['first_name'] as String? ?? '';
    final lastName = json['last_name'] as String? ?? '';
    return AdminDoctorAccount(
      id: '${json['user_id']}',
      name: '$firstName $lastName'.trim(),
      email: json['email'] as String? ?? '',
      healthCenter:
          json['hospital_affiliation'] as String? ?? 'Centre non renseigné',
      patientCount: (json['patient_count'] as num?)?.toInt() ?? 0,
      status: status,
    );
  }

  Future<void> _showConfirmation(String message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(message),
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
    if (confirmed == true && mounted) {
      _showMessage('Action administrateur', 'Action confirmée.');
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

  OutlineInputBorder _border({Color? color}) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(15),
    borderSide: BorderSide(color: color ?? const Color(0xFFF0E7E9)),
  );
}
