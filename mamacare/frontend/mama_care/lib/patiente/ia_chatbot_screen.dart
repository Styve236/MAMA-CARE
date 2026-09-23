import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../shared/app_theme.dart';

class IAChatbotScreen extends StatefulWidget {
  const IAChatbotScreen({super.key});
  @override
  State<IAChatbotScreen> createState() => _IAChatbotScreenState();
}

class _IAChatbotScreenState extends State<IAChatbotScreen> {
  final Color burgundyColor = AppColors.burgundy;
  final TextEditingController _messageController = TextEditingController();

  final List<Map<String, dynamic>> _messages = [];

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    _messageController.clear();
    setState(() {
      _messages.add({"text": text, "isMe": true});
      _messages.add({"text": "", "isMe": false, "isLoading": true});
    });

    try {
      final reply = await ApiClient.sendChatMessage(text);
      _replaceLoading(reply);
    } on ApiException catch (error) {
      _replaceLoading('Erreur : ${error.message}');
    } catch (_) {
      _replaceLoading("Une erreur est survenue. Réessayez plus tard.");
    }
  }

  void _replaceLoading(String reply) {
    if (!mounted) return;
    setState(() {
      final index = _messages.indexWhere((m) => m["isLoading"] == true);
      if (index != -1) {
        _messages[index] = {"text": reply, "isMe": false};
      } else {
        _messages.add({"text": reply, "isMe": false});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: burgundyColor,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/patiente/dashboard');
          },
        ),
        title: Column(
          children: [
            Text(
              "Mamacare AI",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 5),
                Text(
                  "En ligne",
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: EdgeInsets.all(20),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) =>
                        _buildChatBubble(_messages[index]),
                  ),
          ),
          _buildSuggestionChips(),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 80,
            color: Colors.grey.shade200,
          ),
          SizedBox(height: 20),
          Text(
            "Posez votre première question à Mamacare AI",
            style: TextStyle(color: Colors.grey.shade400, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildChatBubble(Map<String, dynamic> message) {
    bool isMe = message["isMe"];
    final isLoading = message["isLoading"] == true;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: 15),
        padding: EdgeInsets.all(15),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        decoration: BoxDecoration(
          color: isMe ? burgundyColor : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(15),
        ),
        child: isLoading
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    "Mamacare AI réfléchit...",
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
              )
            : Text(
                message["text"],
                style: TextStyle(color: isMe ? Colors.white : Colors.black87),
              ),
      ),
    );
  }

  Widget _buildSuggestionChips() {
    return SizedBox(
      height: 60,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 10),
        children: ["Conseils nutrition", "Ma tension", "Urgence"]
            .map(
              (label) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: ActionChip(
                  label: Text(
                    label,
                    style: TextStyle(color: burgundyColor, fontSize: 12),
                  ),
                  backgroundColor: burgundyColor.withValues(alpha: 0.05),
                  onPressed: () {
                    _messageController.text = label;
                    _sendMessage();
                  },
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: EdgeInsets.fromLTRB(15, 10, 15, 30),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5)],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: "Écrivez votre message...",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: EdgeInsets.symmetric(horizontal: 20),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          SizedBox(width: 10),
          CircleAvatar(
            backgroundColor: burgundyColor,
            child: IconButton(
              icon: Icon(Icons.send, color: Colors.white),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }
}
