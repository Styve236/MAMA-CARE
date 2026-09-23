import 'package:flutter/material.dart';
import 'package:mama_care/services/api_client.dart';

final List<String> _weekdays = const [
  'Lundi',
  'Mardi',
  'Mercredi',
  'Jeudi',
  'Vendredi',
  'Samedi',
  'Dimanche',
];
final List<String> _months = const [
  'janvier',
  'février',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'août',
  'septembre',
  'octobre',
  'novembre',
  'décembre',
];

String _formatDateTime(DateTime d) {
  final local = d.toLocal();
  final day = _weekdays[local.weekday - 1];
  final month = _months[local.month - 1];
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return '$day ${local.day} $month ${local.year} à $hh:$mm';
}

String _formatShortDateTime(DateTime d) {
  final local = d.toLocal();
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return '${local.day.toString().padLeft(2, '0')}/'
      '${local.month.toString().padLeft(2, '0')}/${local.year} à $hh:$mm';
}

String _formatTimeOnly(DateTime d) {
  final local = d.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

class AppointmentsRemindersScreen extends StatefulWidget {
  final List<Map<String, String>>? appointments;
  final List<Map<String, dynamic>>? reminders;

  const AppointmentsRemindersScreen({
    super.key,
    this.appointments,
    this.reminders,
  });

  @override
  State<AppointmentsRemindersScreen> createState() =>
      _AppointmentsRemindersScreenState();
}

class _AppointmentsRemindersScreenState
    extends State<AppointmentsRemindersScreen> {
  static const Color burgundy = Color(0xFF800020);
  List<Map<String, String>> _appointments = [];
  List<Map<String, dynamic>> _reminders = [];
  bool _loading = true;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _appointments = List<Map<String, String>>.from(widget.appointments ?? const []);
    _reminders = List<Map<String, dynamic>>.from(widget.reminders ?? const []);
    if (_appointments.isEmpty) {
      _load();
    } else {
      _loading = false;
    }
  }

  Future<void> _load() async {
    try {
      final rows = await ApiClient.patientAppointments();
      final reminders = await ApiClient.patientReminders();
      if (!mounted) return;
      setState(() {
        _appointments = rows.map(_formatAppointment).toList();
        _reminders = reminders;
        _loading = false;
        _error = null;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  Map<String, String> _formatAppointment(Map<String, dynamic> row) {
    final rawDate = row['appointment_date'];
    final parsed = rawDate is String
        ? DateTime.tryParse(rawDate)
        : (rawDate is DateTime ? rawDate : null);
    final dateLabel = parsed == null
        ? '${rawDate ?? 'Date inconnue'}'
        : _formatDateTime(parsed);
    final timeLabel = parsed == null ? '' : _formatTimeOnly(parsed);
    final doctor =
        '${row['doctor_first_name'] ?? ''} ${row['doctor_last_name'] ?? ''}'
            .trim();
    return <String, String>{
      'date': dateLabel,
      'time': timeLabel,
      'doctor': doctor.isEmpty ? 'Médecin non affecté' : doctor,
    };
  }

  Future<void> _openCreateAppointment() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (time == null || !mounted) return;
    final dateTime = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute);
    await _saveAppointment(dateTime);
  }

  Future<void> _saveAppointment(DateTime dateTime) async {
    setState(() => _saving = true);
    try {
      await ApiClient.createPatientAppointment(
        appointmentDate: dateTime,
        durationMinutes: 30,
      );
      if (!mounted) return;
      setState(() => _saving = false);
      final rows = await ApiClient.patientAppointments();
      if (!mounted) return;
      setState(() => _appointments = rows.map(_formatAppointment).toList());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rendez-vous enregistré')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _openCreateReminder() async {
    final titleController = TextEditingController();
    DateTime dateTime = DateTime.now();
    final form = await showDialog<DateTime>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Nouveau rappel'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Titre du rappel',
                    hintText: 'Prendre les vitamines…',
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    dateTime.month == DateTime.now().month &&
                            dateTime.day == DateTime.now().day &&
                            dateTime.year == DateTime.now().year
                        ? 'Aujourd’hui'
                        : _formatDateTime(dateTime),
                  ),
                  trailing: const Icon(Icons.edit_calendar_outlined),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: dateTime,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                    );
                    if (picked == null) return;
                    setDialogState(
                      () => dateTime = DateTime(
                        picked.year,
                        picked.month,
                        picked.day,
                        dateTime.hour,
                        dateTime.minute,
                      ),
                    );
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_formatTimeOnly(dateTime)),
                  trailing: const Icon(Icons.access_time),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(dateTime),
                    );
                    if (picked == null) return;
                    setDialogState(
                      () => dateTime = DateTime(
                        dateTime.year,
                        dateTime.month,
                        dateTime.day,
                        picked.hour,
                        picked.minute,
                      ),
                    );
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.pop(dialogContext, dateTime),
                child: const Text('Enregistrer'),
              ),
            ],
          ),
        );
      },
    );
    final title = titleController.text.trim();
    if (form == null || title.isEmpty || !mounted) return;
    await _saveReminder(title, form);
  }

  Future<void> _saveReminder(String title, DateTime dateTime) async {
    setState(() => _saving = true);
    try {
      await ApiClient.createPatientReminder(title: title, reminderDate: dateTime);
      if (!mounted) return;
      setState(() => _saving = false);
      final reminders = await ApiClient.patientReminders();
      if (!mounted) return;
      setState(() => _reminders = reminders);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _toggleReminder(Map<String, dynamic> reminder, bool isDone) async {
    final id = (reminder['id'] as num).toInt();
    try {
      await ApiClient.setPatientReminderDone(id, isDone);
      if (!mounted) return;
      setState(() {
        reminder['is_done'] = isDone;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _deleteReminder(Map<String, dynamic> reminder) async {
    final id = (reminder['id'] as num).toInt();
    setState(() => _saving = true);
    try {
      await ApiClient.deletePatientReminder(id);
      if (!mounted) return;
      setState(() {
        _reminders.removeWhere((r) => r['id'] == id);
        _saving = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasAppointments = _appointments.isNotEmpty;
    final hasReminders = _reminders.isNotEmpty;

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
        actions: const [
          Icon(
            Icons.notifications_none,
            color: burgundy,
            size: 28,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: burgundy))
          : _error != null
              ? Center(
                  child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: _load,
                            child: const Text('Réessayer'),
                          ),
                        ],
                      )),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader(
                          'Rendez-vous physiques',
                          Icons.calendar_today_outlined,
                          onAdd: _saving ? null : _openCreateAppointment,
                        ),
                        const SizedBox(height: 16),
                        if (hasAppointments)
                          ..._appointments.map(_buildAppointmentCard)
                        else
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Text(
                              'Aucun rendez-vous pris pour le moment.',
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                          ),
                        const SizedBox(height: 35),
                        _buildSectionHeader(
                          'Rappels',
                          Icons.notifications_active_outlined,
                          onAdd: _saving ? null : _openCreateReminder,
                        ),
                        const SizedBox(height: 16),
                        if (hasReminders)
                          ..._reminders.map(_buildReminderTile)
                        else
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Text(
                              'Aucun rappel pour le moment. '
                              'Ajoutez votre premier rappel.',
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                          ),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildSectionHeader(
    String title,
    IconData icon, {
    VoidCallback? onAdd,
  }) {
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
        IconButton(
          onPressed: onAdd,
          icon: const Icon(Icons.add, color: burgundy, size: 28),
        ),
      ],
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
      child: Row(
        children: [
          const Icon(Icons.event_available, color: burgundy),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(apt['date'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                if ((apt['time'] ?? '').isNotEmpty)
                  Text('${apt['time']} - ${apt['doctor']}',
                      style: TextStyle(color: Colors.grey.shade600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderTile(Map<String, dynamic> reminder) {
    final isDone = reminder['is_done'] == true;
    final rawDate = reminder['reminder_date'];
    final parsed = rawDate is String
        ? DateTime.tryParse(rawDate)
        : (rawDate is DateTime ? rawDate : null);
    final formatted = parsed == null
        ? '${rawDate ?? ''}'
        : _formatShortDateTime(parsed);
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
          Checkbox(
            value: isDone,
            activeColor: burgundy,
            onChanged: (value) => _toggleReminder(reminder, value ?? false),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${reminder['title']}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDone ? Colors.grey : Colors.black87,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formatted,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Supprimer',
            onPressed: _saving ? null : () => _deleteReminder(reminder),
            icon: Icon(Icons.delete_outline, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }
}