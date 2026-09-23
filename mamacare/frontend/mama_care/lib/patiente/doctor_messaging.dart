import 'package:flutter/material.dart';

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

  State<DoctorMessaging> createState() =>

      _DoctorMessagingState();

}

class _DoctorMessagingState extends State<DoctorMessaging> {

  static const Color burgundy = Color(0xFF800020);

  final TextEditingController _messageController =

      TextEditingController();

  final ScrollController _scrollController =

      ScrollController();

  final List<DoctorMessage> _messages = <DoctorMessage>[];

  bool get _doctorAssigned =>

      widget.doctorName != null &&

      widget.doctorName!.trim().isNotEmpty;

  String get _doctorName {

    if (_doctorAssigned) {

      return widget.doctorName!.trim();

    }

    return 'Mon médecin';

  }

  String get _doctorSubtitle {

    if (widget.doctorSubtitle != null &&

        widget.doctorSubtitle!.trim().isNotEmpty) {

      return widget.doctorSubtitle!.trim();

    }

    return 'En attente d’affectation';

  }

  @override

  void dispose() {

    _messageController.dispose();

    _scrollController.dispose();

    super.dispose();

  }

  void _sendMessage() {

    final String text = _messageController.text.trim();

    if (text.isEmpty) {

      return;

    }

    if (!_doctorAssigned) {

      _showNoDoctorMessage();

      return;

    }

    setState(() {

      _messages.add(

        DoctorMessage(

          id: DateTime.now().microsecondsSinceEpoch.toString(),

          content: text,

          sentAt: DateTime.now(),

          isFromPatient: true,

        ),

      );

      _messageController.clear();

    });

    _scrollToBottom();

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

      if (!_scrollController.hasClients) {

        return;

      }

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

            Expanded(

              child: _messages.isEmpty

                  ? _buildEmptyState()

                  : ListView.builder(

                      controller: _scrollController,

                      padding: const EdgeInsets.fromLTRB(

                        16,

                        20,

                        16,

                        12,

                      ),

                      itemCount: _messages.length,

                      itemBuilder: (context, index) {

                        return _MessageBubble(

                          message: _messages[index],

                        );

                      },

                    ),

            ),

            _buildMessageComposer(),

          ],

        ),

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

        icon: const Icon(

          Icons.arrow_back,

          size: 28,

        ),

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

              Icon(

                Icons.lock_outline,

                size: 19,

              ),

              SizedBox(width: 5),

              Text(

                'Sécurisé',

                style: TextStyle(

                  fontSize: 12,

                ),

              ),

            ],

          ),

        ),

      ],

    );

  }

  Widget _buildDoctorAvatar() {

    final String? avatarUrl =

        widget.doctorAvatarUrl?.trim();

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

      child: Icon(

        Icons.person_outline,

        color: Colors.grey,

        size: 30,

      ),

    );

  }

  Widget _buildEmptyState() {

    return Center(

      child: Padding(

        padding: const EdgeInsets.symmetric(

          horizontal: 32,

        ),

        child: Column(

          mainAxisAlignment: MainAxisAlignment.center,

          children: [

            Icon(

              _doctorAssigned

                  ? Icons.forum_outlined

                  : Icons.person_search_outlined,

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

      padding: const EdgeInsets.fromLTRB(

        10,

        10,

        10,

        16,

      ),

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

            onPressed: _doctorAssigned

                ? () {}

                : null,

            icon: Icon(

              Icons.add_circle_outline,

              color: _doctorAssigned

                  ? burgundy

                  : Colors.grey.shade400,

              size: 28,

            ),

          ),

          Expanded(

            child: TextField(

              controller: _messageController,

              enabled: _doctorAssigned,

              textInputAction: TextInputAction.send,

              onSubmitted: (_) {

                _sendMessage();

              },

              decoration: InputDecoration(

                hintText: _doctorAssigned

                    ? 'Écrivez votre message...'

                    : 'Messagerie indisponible pour le moment',

                hintStyle: TextStyle(

                  color: Colors.grey.shade500,

                  fontSize: 14,

                ),

                filled: true,

                fillColor: Colors.grey.shade100,

                contentPadding:

                    const EdgeInsets.symmetric(

                  horizontal: 18,

                  vertical: 14,

                ),

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

            backgroundColor: _doctorAssigned

                ? burgundy

                : Colors.grey.shade300,

            child: IconButton(

              tooltip: 'Envoyer',

              onPressed: _doctorAssigned

                  ? _sendMessage

                  : _showNoDoctorMessage,

              icon: const Icon(

                Icons.send,

                color: Colors.white,

                size: 20,

              ),

            ),

          ),

        ],

      ),

    );

  }

}

class DoctorMessage {

  final String id;

  final String content;

  final DateTime sentAt;

  final bool isFromPatient;

  const DoctorMessage({

    required this.id,

    required this.content,

    required this.sentAt,

    required this.isFromPatient,

  });

}

class _MessageBubble extends StatelessWidget {

  final DoctorMessage message;

  const _MessageBubble({

    required this.message,

  });

  @override

  Widget build(BuildContext context) {

    const Color burgundy = Color(0xFF800020);

    // CORRECTION PRINCIPALE :

    // Il ne faut pas utiliser <LaTex>...</LaTex> ici.

    final String time =

        '${message.sentAt.hour.toString().padLeft(2, '0')}:'

        '${message.sentAt.minute.toString().padLeft(2, '0')}';

    return Align(

      alignment: message.isFromPatient

          ? Alignment.centerRight

          : Alignment.centerLeft,

      child: Container(

        constraints: BoxConstraints(

          maxWidth:

              MediaQuery.of(context).size.width * 0.76,

        ),

        margin: const EdgeInsets.only(

          bottom: 12,

        ),

        padding: const EdgeInsets.fromLTRB(

          14,

          11,

          14,

          8,

        ),

        decoration: BoxDecoration(

          color: message.isFromPatient

              ? burgundy

              : Colors.grey.shade100,

          borderRadius: BorderRadius.only(

            topLeft: const Radius.circular(16),

            topRight: const Radius.circular(16),

            bottomLeft: Radius.circular(

              message.isFromPatient ? 16 : 2,

            ),

            bottomRight: Radius.circular(

              message.isFromPatient ? 2 : 16,

            ),

          ),

        ),

        child: Column(

          crossAxisAlignment:

              CrossAxisAlignment.end,

          children: [

            Align(

              alignment: Alignment.centerLeft,

              child: Text(

                message.content,

                style: TextStyle(

                  color: message.isFromPatient

                      ? Colors.white

                      : Colors.black87,

                  fontSize: 15,

                ),

              ),

            ),

            const SizedBox(height: 4),

            Text(

              time,

              style: TextStyle(

                color: message.isFromPatient

                    ? Colors.white70

                    : Colors.black45,

                fontSize: 10,

              ),

            ),

          ],

        ),

      ),

    );

  }

}