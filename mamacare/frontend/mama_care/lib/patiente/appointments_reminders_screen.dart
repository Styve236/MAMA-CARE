import 'package:flutter/material.dart';
import 'package:mama_care/services/api_client.dart';

class AppointmentsRemindersScreen extends StatefulWidget {
  final List<Map<String, String>>? appointments;
  final List<Map<String, dynamic>>? reminders;

  const AppointmentsRemindersScreen({
    super.key,
    this.appointments,
    this.reminders,
  });

  @override
  State<AppointmentsRemindersScreen> createState() => _AppointmentsRemindersScreenState();
}

class _AppointmentsRemindersScreenState extends State<AppointmentsRemindersScreen> {
  static const Color burgundy = Color(0xFF800020);
  List<Map<String, String>> _appointments = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _appointments = List<Map<String, String>>.from(widget.appointments ?? const []);
    if (_appointments.isEmpty) {
      _loadAppointments();
    } else {
      _loading = false;
    }
  }

  Future<void> _loadAppointments() async {
    try {
      final rows = await ApiClient.patientAppointments();
      if (!mounted) return;
      setState(() {
        _appointments = rows.map((row) {
          final doctor = '${row['doctor_first_name'] ?? ''} ${row['doctor_last_name'] ?? ''}'.trim();
          return <String, String>{
            'date': '${row['appointment_date'] ?? 'Date inconnue'}',
            'time': '${row['appointment_time'] ?? ''}',
            'doctor': doctor.isEmpty ? 'Médecin non affecté' : doctor,
          };
        }).toList();
        _loading = false;
      });
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasAppointments = _appointments.isNotEmpty;
    final hasReminders = widget.reminders != null && widget.reminders!.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: burgundy, size: 22),
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/patiente/dashboard');
          },
        ),
        title: const Text(
          'Gestion et Rappels',
          style: TextStyle(
            color: burgundy,
            fontWeight: FontWeight.w800,
            fontSize: 22,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: burgundy, size: 28),
            onPressed: () {},
          ),
        ],
      ),
        body: _loading
          ? const Center(child: CircularProgressIndicator(color: burgundy))
          : _error != null
            ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center)))
            : SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // SECTION RENDEZ-VOUS PHYSIQUES
            _buildSectionHeader('Rendez-vous physiques', Icons.calendar_today_outlined),
            const SizedBox(height: 16),
            if (hasAppointments)
              ..._appointments.map((apt) => _buildAppointmentCard(apt))
            else
              Column(
                children: [
                  _buildPlaceholderCard(),
                  _buildPlaceholderCard(),
                  _buildPlaceholderCard(),
                ],
              ),
            
            const SizedBox(height: 35),
            
            // SECTION RAPPELS SMS
            _buildSectionHeader('Rappels SMS', Icons.notifications_active_outlined),
            const SizedBox(height: 16),
            if (hasReminders)
              _buildRemindersList(widget.reminders!)
            else
              _buildGenericRemindersList(),
            
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: burgundy.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: burgundy, size: 24),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: burgundy,
              ),
            ),
          ],
        ),
        const Icon(Icons.add, color: burgundy, size: 28),
      ],
    );
  }

  Widget _buildPlaceholderCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Column(
            children: const [
              Icon(Icons.calendar_today, color: burgundy, size: 20),
              SizedBox(height: 12),
              Icon(Icons.access_time, color: burgundy, size: 20),
              SizedBox(height: 12),
              Icon(Icons.person_outline, color: burgundy, size: 20),
              SizedBox(height: 12),
              Icon(Icons.location_on_outlined, color: burgundy, size: 20),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('[Date du rendez-vous]', style: TextStyle(color: Colors.grey, fontSize: 15)),
                SizedBox(height: 14),
                Text('[Heure]', style: TextStyle(color: Colors.grey, fontSize: 15)),
                SizedBox(height: 14),
                Text('[Nom du médecin]', style: TextStyle(color: Colors.grey, fontSize: 15)),
                SizedBox(height: 14),
                Text('[Lieu]', style: TextStyle(color: Colors.grey, fontSize: 15)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.grey, size: 26),
        ],
      ),
    );
  }

  Widget _buildGenericRemindersList() {
    return Column(
      children: List.generate(3, (index) => _buildReminderRow(
        'Rappel [Type] - Statut : [En attente/Envoyé]',
      )),
    );
  }

  Widget _buildReminderRow(String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          const Icon(Icons.chat_bubble_outline, color: burgundy, size: 22),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: burgundy,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
        ],
      ),
    );
  }

  Widget _buildAppointmentCard(Map<String, String> apt) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: burgundy.withValues(alpha: 0.2)),
      ),
      child: ListTile(
        leading: const Icon(Icons.event_available, color: burgundy),
        title: Text(apt['date'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("${apt['time']} - ${apt['doctor']}"),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

  Widget _buildRemindersList(List<Map<String, dynamic>> reminders) {
    return Column(
      children: reminders.map((r) => _buildReminderRow(r['label'])).toList(),
    );
  }
}