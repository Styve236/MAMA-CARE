import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../shared/app_theme.dart';
import 'doctor_conversation_screen.dart';

class DoctorMessagesList extends StatefulWidget {
  /// Si nulle, l'interface récupère les threads depuis l'API.
  final List<Map<String, dynamic>>? conversations;

  const DoctorMessagesList({super.key, this.conversations});

  @override
  State<DoctorMessagesList> createState() => _DoctorMessagesListState();
}

class _DoctorMessagesListState extends State<DoctorMessagesList> {
  static const Color burgundy = AppColors.burgundy;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _threads = [];
  bool _loading = true;
  String? _error;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    if (widget.conversations != null) {
      _threads = List.from(widget.conversations!);
      _loading = false;
    } else {
      _loadThreads();
      _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        if (mounted) _loadThreads(silent: true);
      });
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadThreads({bool silent = false}) async {
    if (silent && _error != null) return;
    try {
      final threads = await ApiClient.doctorMessageThreads();
      if (!mounted) return;
      setState(() {
        _threads = threads;
        _loading = false;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  Future<void> _openConversation(Map<String, dynamic> thread) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DoctorConversationScreen(thread: thread),
      ),
    );
    _loadThreads(silent: true);
  }

  List<Map<String, dynamic>> get _filteredThreads {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _threads;
    return _threads
        .where((t) =>
            '${t['first_name']} ${t['last_name']}'
                .toLowerCase()
                .contains(query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: burgundy),
          onPressed: () {
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
            icon: const Icon(Icons.refresh, color: burgundy, size: 28),
            onPressed: () {
              setState(() {
                _loading = true;
                _error = null;
              });
              _loadThreads();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Rechercher une patiente...',
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
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _buildList() {
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
                  _loadThreads();
                },
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }
    final threads = _filteredThreads;
    if (threads.isEmpty) {
      return Center(
        child: Text(
          _threads.isEmpty
              ? 'Aucune conversation pour le moment.'
              : 'Aucune patiente ne correspond à la recherche.',
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _loadThreads(silent: true),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 10),
        itemCount: threads.length,
        itemBuilder: (context, index) =>
            _buildConversationTile(threads[index]),
      ),
    );
  }

  Widget _buildConversationTile(Map<String, dynamic> conv) {
    final name =
        '${conv['first_name'] ?? ''} ${conv['last_name'] ?? ''}'.trim();
    final message = conv['last_message'] == null
        ? 'Envoyez le premier message'
        : '${conv['last_message']}';
    final unread = (conv['unread_count'] as num?)?.toInt() ?? 0;
    final lastMessageAt = conv['last_message_at'] is String
        ? DateTime.tryParse(conv['last_message_at'] as String)
        : null;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: unread > 0 ? burgundy : Colors.grey.shade300,
        child: Icon(
          Icons.person,
          color: unread > 0 ? Colors.white : Colors.grey.shade600,
        ),
      ),
      title: Text(
        name.isEmpty ? 'Patiente' : name,
        style: TextStyle(
          fontWeight: unread > 0 ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: Text(
        message,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: unread > 0 ? Colors.black87 : Colors.grey,
          fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      trailing: unread > 0
          ? _UnreadBadge(unread)
          : (lastMessageAt != null
              ? Text(
                  '${lastMessageAt.toLocal().hour.toString().padLeft(2, '0')}:'
                  '${lastMessageAt.toLocal().minute.toString().padLeft(2, '0')}',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                )
              : null),
      onTap: () => _openConversation(conv),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  final int count;

  const _UnreadBadge(this.count);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.burgundy,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$count',
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }
}