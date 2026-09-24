import 'package:flutter/material.dart';
import 'package:mama_care/services/api_client.dart';
import '../shared/app_theme.dart';
import '../shared/date_utils.dart';

class DoctorAppointmentsScreen extends StatefulWidget {
  const DoctorAppointmentsScreen({super.key});

  @override
  State<DoctorAppointmentsScreen> createState() =>
      _DoctorAppointmentsScreenState();
}

class _DoctorAppointmentsScreenState extends State<DoctorAppointmentsScreen> {
  static const Color burgundy = AppColors.burgundy;
  List<Map<String, dynamic>> _appointments = [];
  bool _loading = true;
  String? _error;
  int _filter = 0;
  bool _busy = false;

  static const List<String> _filters = ['En attente', 'Confirmés', 'Historique'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await ApiClient.doctorAppointmentRequests();
      if (!mounted) return;
      setState(() {
        _appointments = rows;
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

  List<Map<String, dynamic>> _filtered() {
    return _appointments.where((a) {
      final st = '${a['status'] ?? ''}';
      switch (_filter) {
        case 1:
          return st == 'confirmed';
        case 2:
          return st != 'pending' && st != 'rescheduled';
        default:
          return st == 'pending' || st == 'rescheduled';
      }
    }).toList();
  }

  String _pickLabel(Map<String, dynamic> a) =>
      '${a['first_name'] ?? ''} ${a['last_name'] ?? ''}'.trim();

  Future<void> _runAction(
    String key,
    Future<Map<String, dynamic>> Function() action, {
    String? success,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(success ?? 'Action effectuée')));
      await _load();
      setState(() => _busy = false);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _accept(Map<String, dynamic> a) {
    return _runAction(
      'accept',
      () => ApiClient.doctorAcceptAppointment((a['id'] as num).toInt()),
      success: 'Rendez-vous confirmé. La patiente a été notifiée.',
    );
  }

  Future<void> _showRejectDialog(Map<String, dynamic> a) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Refuser le rendez-vous'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Motif (facultatif)',
            hintText: 'Plage horaire déjà complète, consultation reportée…',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Refuser'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _runAction(
      'reject',
      () => ApiClient.doctorRejectAppointment(
        (a['id'] as num).toInt(),
        reason: controller.text.trim(),
      ),
      success: 'Rendez-vous refusé. La patiente a été notifiée.',
    );
  }

  Future<void> _showRescheduleDialog(Map<String, dynamic> a) async {
    DateTime date = DateTime.now().add(const Duration(hours: 24));
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Proposer une autre date'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Nouvelle date et heure'),
                subtitle: Text(formatFullDate(date)),
                trailing: const Icon(Icons.edit_calendar_outlined),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: date,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                  );
                  if (picked == null) return;
                  if (!context.mounted) return;
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(date),
                  );
                  if (time == null) return;
                  setDialogState(() => date = DateTime(
                      picked.year, picked.month, picked.day, time.hour, time.minute));
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: reasonController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Message à la patiente (facultatif)',
                  hintText: 'Je suis déjà occupé(e) à cette heure…',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Proposer'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    await _runAction(
      'reschedule',
      () => ApiClient.doctorRescheduleAppointment(
        (a['id'] as num).toInt(),
        date,
        reason: reasonController.text.trim(),
      ),
      success: 'Nouvelle date envoyée à la patiente.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _loading ? <Map<String, dynamic>>[] : _filtered();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Rendez-vous',
          style: TextStyle(
            color: burgundy,
            fontWeight: FontWeight.w800,
            fontSize: 22,
          ),
        ),
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
                    ),
                  ),
                )
              : Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Wrap(
                        spacing: 8,
                        children: [
                          for (var i = 0; i < _filters.length; i++)
                            ChoiceChip(
                              label: Text(_filters[i]),
                              selected: _filter == i,
                              selectedColor: burgundy,
                              labelStyle: TextStyle(
                                color: _filter == i ? Colors.white : Colors.black87,
                                fontSize: 12,
                              ),
                              onSelected: (_) => setState(() => _filter = i),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _load,
                        child: ListView(
                          padding: const EdgeInsets.all(20),
                          children: [
                            if (items.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 40),
                                child: Center(
                                  child: Text(
                                    _filter == 0
                                        ? 'Aucune demande de rendez-vous en attente.'
                                        : 'Aucun rendez-vous dans cette catégorie.',
                                    style: TextStyle(color: Colors.grey.shade500),
                                  ),
                                ),
                              )
                            else
                              ...items.map(_buildCard),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildCard(Map<String, dynamic> a) {
    final status = '${a['status'] ?? ''}';
    final isPending = status == 'pending';
    final isRescheduled = status == 'rescheduled';
    final name = _pickLabel(a);
    final phone = '${a['patient_phone'] ?? ''}';
    final weeks = a['pregnancy_weeks'];
    final notes = '${a['notes'] ?? ''}';
    final createdAt = timeAgo(a['created_at']);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: burgundy.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name.isEmpty ? 'Patiente' : name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              _statusChip(status),
            ],
          ),
          const SizedBox(height: 8),
          if (phone.isNotEmpty)
            Text('📞 $phone',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          const SizedBox(height: 4),
          Text(
            isRescheduled ? 'Proposition : ${formatFullDate(a['appointment_date'])}'
                : formatFullDate(a['appointment_date']),
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          if (weeks != null)
            Text('$weeks semaine${weeks == 1 ? '' : 's'} de grossesse',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          if (notes.isNotEmpty && notes != 'null')
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('“$notes”',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            ),
          if (createdAt.isNotEmpty && (isPending || isRescheduled))
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Demande reçue $createdAt',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
            ),
          if (isPending) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                    ),
                    onPressed: _busy ? null : () => _accept(a),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Accepter'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                    onPressed: _busy ? null : () => _showRejectDialog(a),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Refuser'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: burgundy,
                  side: BorderSide(color: burgundy.withValues(alpha: 0.4)),
                ),
                onPressed: _busy ? null : () => _showRescheduleDialog(a),
                icon: const Icon(Icons.date_range, size: 18),
                label: const Text('Je suis occupé — proposer une autre date'),
              ),
            ),
          ] else if (isRescheduled)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                children: [
                  Icon(Icons.hourglass_top,
                      color: Colors.orange.shade700, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'En attente de l\'acceptation de la patiente.',
                      style: TextStyle(
                        color: Colors.orange.shade800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    final (label, color) = switch (status) {
      'pending' => ('En attente', Colors.orange),
      'confirmed' => ('Confirmé', const Color(0xFF2E7D32)),
      'rejected' => ('Refusé', Colors.red),
      'rescheduled' => ('Nouvelle date proposée', burgundy),
      _ => (status, Colors.grey),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}