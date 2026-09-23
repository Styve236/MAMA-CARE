import 'package:flutter/material.dart';
import 'package:mama_care/services/api_client.dart';
import '../shared/app_theme.dart';

class AdminActivityLogEntry {
  final String id;
  final String action;
  final String actor;
  final String target;
  final DateTime createdAt;

  const AdminActivityLogEntry({
    required this.id,
    required this.action,
    required this.actor,
    required this.target,
    required this.createdAt,
  });
}

class AdminActivityLogScreen extends StatefulWidget {
  final VoidCallback? onBackToDashboard;
  final List<AdminActivityLogEntry> entries;

  const AdminActivityLogScreen({
    super.key,
    this.onBackToDashboard,
    this.entries = const [],
  });

  @override
  State<AdminActivityLogScreen> createState() => _AdminActivityLogScreenState();
}

class _AdminActivityLogScreenState extends State<AdminActivityLogScreen> {
  static const Color burgundy = AppColors.burgundy;
  static const Color lightBurgundy = Color(0xFFF8EDF0);
  static const Color pageBackground = Color(0xFFFCF9FA);
  static const Color softBorder = Color(0xFFF0E7E9);

  String _filter = 'Toutes';
  List<AdminActivityLogEntry> _entries = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _entries = List<AdminActivityLogEntry>.from(widget.entries);
    _fetchEntries();
  }

  List<AdminActivityLogEntry> get _visibleEntries {
    if (_filter == 'Toutes') return _entries;

    final action = switch (_filter) {
      'Création' => 'DOCTOR_CREATION',
      'Validation' => 'DOCTOR_VALIDATION',
      'Attribution' => 'DOCTOR_ASSIGNMENT',
      _ => _filter,
    };
    return _entries
        .where((entry) => entry.action == action)
        .toList();
  }

  Future<void> _fetchEntries() async {
    try {
      final rows = await ApiClient.adminActivityLogs();
      if (!mounted) return;
      setState(() {
        _entries = rows.map(_entryFromJson).toList();
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de charger le journal.')),
      );
    }
  }

  AdminActivityLogEntry _entryFromJson(Map<String, dynamic> json) {
    return AdminActivityLogEntry(
      id: '${json['id'] ?? ''}',
      action: json['action'] as String? ?? '',
      actor: json['actor'] as String? ?? 'Administrateur',
      target: json['target'] as String? ?? '',
      createdAt: DateTime.tryParse('${json['created_at']}') ?? DateTime.now(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: burgundy,
          ),
          onPressed: () {
            if (widget.onBackToDashboard != null) {
              widget.onBackToDashboard!();
            } else {
              Navigator.of(context).maybePop();
            }
          },
        ),
        title: const Text(
          'Journal d’activité',
          style: TextStyle(
            color: burgundy,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = constraints.maxWidth >= 850 ? 32.0 : 18.0;

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: 22,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 950),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildIntro(),
                    const SizedBox(height: 20),
                    _buildFilters(),
                    const SizedBox(height: 18),
                    _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _buildLogContent(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildIntro() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: lightBurgundy,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(
          color: const Color(0xFFF0DDE2),
        ),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.fact_check_outlined,
            color: burgundy,
            size: 36,
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Traçabilité des actions administratives',
                  style: TextStyle(
                    color: burgundy,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Les créations, validations, attributions et modifications seront historisées pour renforcer la sécurité.',
                  style: TextStyle(
                    color: Colors.black54,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    const filters = [
      'Toutes',
      'Création',
      'Validation',
      'Attribution',
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((filter) {
          final selected = _filter == filter;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(filter),
              selected: selected,
              onSelected: (_) {
                setState(() => _filter = filter);
              },
              selectedColor: burgundy,
              backgroundColor: Colors.white,
              labelStyle: TextStyle(
                color: selected ? Colors.white : Colors.black87,
                fontSize: 12,
                fontWeight: selected
                    ? FontWeight.w700
                    : FontWeight.w500,
              ),
              side: BorderSide(
                color: selected ? burgundy : softBorder,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLogContent() {
    if (_visibleEntries.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 46,
        ),
        decoration: _cardDecoration(),
        child: const Column(
          children: [
            Icon(
              Icons.history_toggle_off,
              color: burgundy,
              size: 58,
            ),
            SizedBox(height: 15),
            Text(
              'Aucune activité enregistrée',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: burgundy,
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Les événements administratifs apparaîtront ici après la connexion à Supabase.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _visibleEntries
          .map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildEntryCard(entry),
            ),
          )
          .toList(),
    );
  }

  Widget _buildEntryCard(AdminActivityLogEntry entry) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: _cardDecoration(),
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
            child: Icon(
              _iconForAction(entry.action),
              color: burgundy,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.action,
                  style: const TextStyle(
                    color: burgundy,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Acteur : ${entry.actor}',
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Cible : ${entry.target}',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _formatDate(entry.createdAt),
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForAction(String action) {
    switch (action) {
      case 'DOCTOR_CREATION':
      case 'Création':
        return Icons.add_circle_outline;
      case 'DOCTOR_VALIDATION':
      case 'Validation':
        return Icons.verified_outlined;
      case 'DOCTOR_ASSIGNMENT':
      case 'Attribution':
        return Icons.swap_horiz_rounded;
      default:
        return Icons.info_outline;
    }
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$day/$month/${date.year}\n$hour:$minute';
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(19),
      border: Border.all(color: softBorder),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0B800020),
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ],
    );
  }
}