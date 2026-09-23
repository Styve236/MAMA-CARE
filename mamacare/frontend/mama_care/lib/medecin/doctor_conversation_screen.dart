import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../shared/chat_bubble.dart';

class DoctorConversationScreen extends StatefulWidget {
  final Map<String, dynamic> thread;

  const DoctorConversationScreen({super.key, required this.thread});

  @override
  State<DoctorConversationScreen> createState() =>
      _DoctorConversationScreenState();
}

class _DoctorConversationScreenState extends State<DoctorConversationScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;
  String? _error;
  String? _patientName;
  Timer? _refreshTimer;

  String get _patientUserId => '${widget.thread['patient_user_id']}';

  @override
  void initState() {
    super.initState();
    _patientName =
        '${widget.thread['first_name']} ${widget.thread['last_name']}'.trim();
    _loadConversation();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _refreshSilently();
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
      ApiClient.markDoctorThreadRead(_patientUserId);
      final data = await ApiClient.doctorMessageThread(_patientUserId);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = null;
        _messages
          ..clear()
          ..addAll((data['messages'] as List).cast<Map<String, dynamic>>());
        final patient = data['patient'];
        if (patient is Map<String, dynamic>) {
          _patientName =
              '${patient['first_name']} ${patient['last_name']}'.trim();
        }
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
    if (!mounted) return;
    try {
      final data = await ApiClient.doctorMessageThread(_patientUserId);
      if (!mounted) return;
      final messages = (data['messages'] as List).cast<Map<String, dynamic>>();
      if (messages.length != _messages.length) {
        setState(() {
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

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final result = await ApiClient.sendDoctorMessage(
        patientUserId: _patientUserId,
        message: text,
      );
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUnread = (widget.thread['unread_count'] as num?)?.toInt() ?? 0;
    return Scaffold(
      appBar: AppBar(
        title: Text(_patientName ?? 'Conversation'),
        actions: [
          if (isUnread > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text('$isUnread non lu(s)',
                    style: const TextStyle(fontSize: 13)),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildBody()),
          _buildInputBar(),
        ],
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
    if (_messages.isEmpty) {
      return const Center(
        child: Text(
          'Aucun message. Commencez la conversation !',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
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
        );
      },
    );
  }

  Widget _buildInputBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE8E3E3))),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Écrire un message…',
                  isDense: true,
                  filled: true,
                  fillColor: Color(0xFFF6F4F3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(24)),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _sending ? null : _sendMessage,
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }
}