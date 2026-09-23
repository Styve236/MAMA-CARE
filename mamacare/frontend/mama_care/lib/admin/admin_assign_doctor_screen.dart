import 'package:flutter/material.dart';
import '../services/api_client.dart';

class AdminPatientOption {
  final String id;
  final String displayName;
  final String city;

  const AdminPatientOption({
    required this.id,
    required this.displayName,
    required this.city,
  });
}

class AdminDoctorLoad {
  final String id;
  final String displayName;
  final String healthCenter;
  final int patientCount;

  const AdminDoctorLoad({
    required this.id,
    required this.displayName,
    required this.healthCenter,
    required this.patientCount,
  });
}

class AdminAssignmentData {
  final String patientId;
  final String doctorId;

  const AdminAssignmentData({
    required this.patientId,
    required this.doctorId,
  });
}

class AdminAssignDoctorScreen extends StatefulWidget {
  final VoidCallback? onBackToDashboard;
  final List<AdminPatientOption> patients;
  final List<AdminDoctorLoad> doctors;
  final ValueChanged<AdminAssignmentData>? onAssignmentConfirmed;
  final String? initialPatientId;
  final String? initialDoctorId;

  const AdminAssignDoctorScreen({
    super.key,
    this.onBackToDashboard,
    this.patients = const [],
    this.doctors = const [],
    this.onAssignmentConfirmed,
    this.initialPatientId,
    this.initialDoctorId,
  });

  @override
  State<AdminAssignDoctorScreen> createState() =>
      _AdminAssignDoctorScreenState();
}

class _AdminAssignDoctorScreenState extends State<AdminAssignDoctorScreen> {
  static const Color burgundy = Color(0xFF800020);
  static const Color background = Color(0xFFFCF9FA);
  static const Color lightBurgundy = Color(0xFFF8EDF0);
  static const Color borderColor = Color(0xFFE9DFE2);

  List<AdminPatientOption> _patients = [];
  List<AdminDoctorLoad> _doctors = [];
  bool _loading = true;
  String? _error;
  bool _saving = false;

  AdminPatientOption? _selectedPatient;
  AdminDoctorLoad? _selectedDoctor;

  AdminDoctorLoad? get _recommendedDoctor {
    if (_doctors.isEmpty) return null;
    final sorted = [..._doctors]
      ..sort((a, b) => a.patientCount.compareTo(b.patientCount));
    return sorted.first;
  }

  @override
  void initState() {
    super.initState();
    _patients = List.from(widget.patients);
    _doctors = List.from(widget.doctors);
    if (_patients.isEmpty || _doctors.isEmpty) {
      _load();
    } else {
      _loading = false;
      _applyInitialSelection();
    }
  }

  Future<void> _load() async {
    try {
      final patientRows = await ApiClient.adminPatients();
      final doctorRows = await ApiClient.adminDoctors();
      if (!mounted) return;
      setState(() {
        _patients = patientRows.map((json) {
          final first = '${json['first_name'] ?? ''}'.trim();
          final last = '${json['last_name'] ?? ''}'.trim();
          final name = '$first $last'.trim();
          return AdminPatientOption(
            id: '${json['user_id'] ?? json['id'] ?? ''}',
            displayName: name.isEmpty ? '${json['email'] ?? ''}' : name,
            city: '',
          );
        }).toList();
        _doctors = doctorRows.map((json) {
          final first = '${json['first_name'] ?? ''}'.trim();
          final last = '${json['last_name'] ?? ''}'.trim();
          final specialization = '${json['specialization'] ?? ''}'.trim();
          return AdminDoctorLoad(
            id: '${json['doctor_id'] ?? json['id'] ?? ''}',
            displayName:
                'Dr $first $last${specialization.isEmpty ? '' : ' — $specialization'}'
                    .trim(),
            healthCenter: '${json['hospital_affiliation'] ?? ''}',
            patientCount: (json['patient_count'] as num?)?.toInt() ?? 0,
          );
        }).toList();
        _loading = false;
        _error = null;
        _applyInitialSelection();
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  void _applyInitialSelection() {
    if (widget.initialPatientId != null) {
      final matches = _patients.where((p) => p.id == widget.initialPatientId);
      if (matches.isNotEmpty) {
        _selectedPatient = matches.first;
        _selectedDoctor = _recommendedDoctor;
        return;
      }
    }
    if (_patients.isNotEmpty) {
      _selectedPatient = _patients.first;
      _selectedDoctor = _recommendedDoctor;
    }
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
          'Attribution',
          style: TextStyle(
            color: burgundy,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = constraints.maxWidth >= 850 ? 32.0 : 18.0;

          if (_loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_error != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _loading = true;
                          _error = null;
                        });
                        _load();
                      },
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
            );
          }

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: 22,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeaderCard(),
                    const SizedBox(height: 26),
                    _buildSectionTitle('Sélectionner la patiente'),
                    const SizedBox(height: 10),
                    _buildPatientSelector(),
                    const SizedBox(height: 20),
                    _buildSectionTitle('Sélectionner le médecin'),
                    const SizedBox(height: 10),
                    _buildDoctorSelector(),
                    const SizedBox(height: 20),
                    _buildRuleCard(),
                    const SizedBox(height: 25),
                    _buildSectionTitle('Charge des médecins'),
                    const SizedBox(height: 10),
                    _buildDoctorLoads(),
                    const SizedBox(height: 25),
                    _buildSectionTitle('Recommandation automatique'),
                    const SizedBox(height: 10),
                    _buildRecommendation(),
                    const SizedBox(height: 20),
                    _buildConfirmButton(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: lightBurgundy,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFEBDDE1)),
      ),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: const Color(0xFFF6E2E7),
              borderRadius: BorderRadius.circular(31),
            ),
            child: const Icon(
              Icons.medical_services_outlined,
              color: burgundy,
              size: 34,
            ),
          ),
          const SizedBox(width: 18),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Attribution médecin-patiente',
                  style: TextStyle(
                    color: burgundy,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 7),
                Text(
                  'Attribuez une patiente à un médecin en fonction de la charge de suivi.',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: burgundy,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildPatientSelector() {
    final hasPatients = _patients.isNotEmpty;

    return DropdownButtonFormField<AdminPatientOption>(
      initialValue: _selectedPatient,
      isExpanded: true,
      hint: const Text(
        'Sélectionner une patiente',
        style: TextStyle(color: Colors.grey),
      ),
      onChanged: hasPatients
          ? (patient) {
              setState(() {
                _selectedPatient = patient;
                _selectedDoctor = _recommendedDoctor;
              });
            }
          : null,
      items: _patients.map((patient) {
        return DropdownMenuItem<AdminPatientOption>(
          value: patient,
          child: Text(patient.displayName),
        );
      }).toList(),
      decoration: _inputDecoration(Icons.person_outline),
    );
  }

  Widget _buildDoctorSelector() {
    final hasDoctors = _doctors.isNotEmpty;

    return DropdownButtonFormField<AdminDoctorLoad>(
      initialValue: _selectedDoctor,
      isExpanded: true,
      hint: const Text(
        'Sélectionner un médecin',
        style: TextStyle(color: Colors.grey),
      ),
      onChanged: hasDoctors
          ? (doctor) {
              setState(() => _selectedDoctor = doctor);
            }
          : null,
      items: _doctors.map((doctor) {
        return DropdownMenuItem<AdminDoctorLoad>(
          value: doctor,
          child: Text(doctor.displayName),
        );
      }).toList(),
      decoration: _inputDecoration(Icons.medical_services_outlined),
    );
  }

  Widget _buildRuleCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF0E2BA)),
      ),
      child: const Row(
        children: [
          Icon(Icons.balance_outlined, color: Color(0xFF805B1A), size: 36),
          SizedBox(width: 14),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Règle d’attribution :\n',
                    style: TextStyle(
                      color: Color(0xFF684A1A),
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  TextSpan(
                    text: 'recommander le médecin qui suit le moins de patientes.',
                    style: TextStyle(
                      color: Color(0xFF684A1A),
                      fontSize: 15,
                      height: 1.4,
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

  Widget _buildDoctorLoads() {
    if (_doctors.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: const Text(
          'Aucun médecin disponible.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    final recommended = _recommendedDoctor;

    return Column(
      children: _doctors.map((doctor) {
        final isRecommended = recommended?.id == doctor.id;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _buildDoctorCard(doctor, isRecommended),
        );
      }).toList(),
    );
  }

  Widget _buildDoctorCard(
    AdminDoctorLoad doctor,
    bool isRecommended,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isRecommended ? lightBurgundy : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRecommended ? burgundy : borderColor,
          width: isRecommended ? 1.4 : 1,
        ),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: lightBurgundy,
            child: Icon(Icons.medical_services_outlined, color: burgundy),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doctor.displayName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Patientes suivies : ${doctor.patientCount}',
                  style: const TextStyle(color: Colors.grey),
                ),
                if (doctor.healthCenter.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    doctor.healthCenter.trim(),
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
                if (isRecommended) ...[
                  const SizedBox(height: 5),
                  const Text(
                    'Médecin recommandé',
                    style: TextStyle(
                      color: burgundy,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _buildRecommendation() {
    final doctor = _selectedDoctor ?? _recommendedDoctor;

    if (_selectedPatient == null || doctor == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: const Row(
          children: [
            Icon(Icons.auto_awesome, color: burgundy),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Les données apparaîtront après la sélection d’une patiente et d’un médecin.',
                style: TextStyle(color: Colors.grey, height: 1.4),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: lightBurgundy,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8CBD3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, color: burgundy),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${doctor.displayName} est recommandé avec ${doctor.patientCount} patiente(s) suivie(s).',
              style: const TextStyle(
                color: burgundy,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmButton() {
    final enabled =
        _selectedPatient != null && _selectedDoctor != null && !_saving;

    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: enabled ? _confirmAssignment : null,
        style: FilledButton.styleFrom(
          backgroundColor: burgundy,
          disabledBackgroundColor: const Color(0xFFD8A1AA),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
        child: _saving
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text(
                'Confirmer l’attribution',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
      ),
    );
  }

  Future<void> _confirmAssignment() async {
    final patient = _selectedPatient;
    final doctor = _selectedDoctor;
    if (patient == null || doctor == null) return;

    final doctorId = int.tryParse(doctor.id);
    if (doctorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Médecin invalide.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await ApiClient.adminAssignDoctor(userId: patient.id, doctorId: doctorId);
      if (!mounted) return;
      setState(() => _saving = false);
      widget.onAssignmentConfirmed?.call(
        AdminAssignmentData(patientId: patient.id, doctorId: doctor.id),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attribution enregistrée.')),
      );
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  InputDecoration _inputDecoration(IconData icon) {
    return InputDecoration(
      prefixIcon: Icon(icon, color: burgundy),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 17,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: burgundy, width: 1.4),
      ),
    );
  }
}