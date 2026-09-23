import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../shared/chat_bubble.dart';

class DoctorMessaging extends StatefulWidget {
  final String? doctorName;
  final String? doctorSubtitle;
  final String? doctorAvatarUrl;

  const DoctorMessaging({
    super.key,
    this.doctorName,
    this.doctorSubtitle,
    this.doctorAvatarUrl,
  });

  @override
  State<DoctorMessaging> createState() => _DoctorMessagingState();
}

class _DoctorMessagingState extends State<DoctorMessaging> {
  static const Color burgundy = Color(0xFF800020);
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = <Map<String, dynamic>>[];
  Map<String, dynamic>? _doctor;
  bool _loading = true;
  bool _sending = false;
  String? _error;
  Timer? _refreshTimer;

  bool get _doctorAssigned =>
      _doctor != null && (_doctor!['first_name'] != null);

  String get _doctorName {
    if (_doctorAssigned) {
      return '${_doctor!['first_name']} ${_doctor!['last_name'] ?? ''}'
          .trim();
    }
    if (widget.doctorName != null && widget.doctorName!.trim().isNotEmpty) {
      return widget.doctorName!.trim();
    }
    return 'Mon médecin';
  }

  String get _doctorSubtitle {
    if (_doctorAssigned &&
        _doctor!['specialization'] != null &&
        '${_doctor!['specialization']}'.isNotEmpty) {
      return '${_doctor!['specialization']}';
    }
    if (!_doctorAssigned) return 'En attente d’affectation';
    return 'Médecin';
  }

  @override
  void initState() {
    super.initState();
    _loadConversation();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) _refreshSilently();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadConversation() async {
    try {
      final data = await ApiClient.patientMessages();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = null;
        _doctor = data['doctor'] as Map<String, dynamic>?;
        _messages
          ..clear()
          ..addAll((data['messages'] as List).cast<Map<String, dynamic>>());
      });
      _scrollToBottom();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  Future<void> _refreshSilently() async {
    if (!mounted || _loading) return;
    try {
      final data = await ApiClient.patientMessages();
      if (!mounted) return;
      final messages = (data['messages'] as List).cast<Map<String, dynamic>>();
      if (messages.length != _messages.length ||
          '${data['doctor']?['first_name'] ?? ''}' !=
              '${_doctor?['first_name'] ?? ''}') {
        setState(() {
          _doctor = data['doctor'] as Map<String, dynamic>?;
          _messages
            ..clear()
            ..addAll(messages);
        });
        _scrollToBottom();
      }
    } on ApiException {
      // Ignoré pendant le rafraîchissement silencieux.
    }
  }

  Future<void> _sendMessage() async {
    final String text = _messageController.text.trim();
    if (text.isEmpty || _sending) return;
    if (!_doctorAssigned) {
      _showNoDoctorMessage();
      return;
    }
    setState(() => _sending = true);
    try {
      final result = await ApiClient.sendPatientMessage(text);
      if (!mounted) return;
      setState(() {
        _messages.add(result['message'] as Map<String, dynamic>);
        _messageController.clear();
        _sending = false;
      });
      _scrollToBottom();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  void _showNoDoctorMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Aucun médecin n’est encore affecté à votre profil. '
          'La messagerie sera disponible après l’affectation.',
        ),
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(context),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildBody()),
            _buildMessageComposer(),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
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
                  _loadConversation();
                },
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }
    if (_messages.isEmpty) return _buildEmptyState();
    return RefreshIndicator(
      onRefresh: _refreshSilently,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
        itemCount: _messages.length,
        itemBuilder: (context, index) {
          final message = _messages[index];
          final time = message['created_at'] is String
              ? DateTime.tryParse(message['created_at'] as String)
              : null;
          return ChatBubble(
            key: ValueKey(message['id']),
            text: '${message['message_text']}',
            timestamp: time,
            isFromMe: message['is_from_me'] == true,
            outgoingColor: burgundy,
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: burgundy,
      foregroundColor: Colors.white,
      elevation: 0,
      toolbarHeight: 92,
      leading: IconButton(
        tooltip: 'Retour',
        icon: const Icon(Icons.arrow_back, size: 28),
        onPressed: () {
          Navigator.pushReplacementNamed(context, '/patiente/dashboard');
        },
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          _buildDoctorAvatar(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _doctorName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _doctorSubtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: const [
        Padding(
          padding: EdgeInsets.only(right: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, size: 19),
              SizedBox(width: 5),
              Text('Sécurisé', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDoctorAvatar() {
    final String? avatarUrl = widget.doctorAvatarUrl?.trim();
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 25,
        backgroundColor: Colors.white,
        backgroundImage: NetworkImage(avatarUrl),
      );
    }
    return const CircleAvatar(
      radius: 25,
      backgroundColor: Colors.white,
      child: Icon(Icons.person_outline, color: Colors.grey, size: 30),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _doctorAssigned ? Icons.forum_outlined : Icons.person_search_outlined,
              size: 68,
              color: burgundy.withValues(alpha: 0.18),
            ),
            const SizedBox(height: 18),
            Text(
              _doctorAssigned
                  ? 'Aucun message pour le moment.'
                  : 'Votre médecin n’est pas encore affecté.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _doctorAssigned
                  ? 'Votre échange sécurisé apparaîtra ici.'
                  : 'La messagerie sera activée après '
                      'l’affectation par l’administration.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageComposer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Ajouter une pièce jointe',
            onPressed: _doctorAssigned ? () {} : null,
            icon: Icon(
              Icons.add_circle_outline,
              color: _doctorAssigned ? burgundy : Colors.grey.shade400,
              size: 28,
            ),
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              enabled: _doctorAssigned,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
              decoration: InputDecoration(
                hintText: _doctorAssigned
                    ? 'Écrivez votre message...'
                    : 'Messagerie indisponible pour le moment',
                hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 24,
            backgroundColor: _doctorAssigned ? burgundy : Colors.grey.shade300,
            child: IconButton(
              tooltip: 'Envoyer',
              onPressed: _doctorAssigned ? _sendMessage : _showNoDoctorMessage,
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}