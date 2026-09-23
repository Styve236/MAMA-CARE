import 'package:flutter/material.dart';

class ChatBubble extends StatelessWidget {
  final String text;
  final DateTime? timestamp;
  final bool isFromMe;
  final Color outgoingColor;
  final Color incomingColor;

  const ChatBubble({
    super.key,
    required this.text,
    this.timestamp,
    required this.isFromMe,
    this.outgoingColor = const Color(0xFF7A1B2B),
    this.incomingColor = const Color(0xFFF0EEED),
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isFromMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: isFromMe ? outgoingColor : incomingColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isFromMe ? 16 : 4),
            bottomRight: Radius.circular(isFromMe ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              style: TextStyle(
                fontSize: 15,
                height: 1.35,
                color: isFromMe ? Colors.white : const Color(0xFF2B2626),
              ),
            ),
            if (timestamp != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _formatTime(timestamp!),
                  style: TextStyle(
                    fontSize: 11,
                    color: isFromMe
                        ? Colors.white.withValues(alpha: 0.8)
                        : const Color(0xFF8A8383),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _formatTime(DateTime time) {
    final local = time.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}