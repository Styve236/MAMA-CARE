import 'dart:async';

import 'package:flutter/material.dart';

import 'services/api_client.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const burgundy = Color(0xFF800020);
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;
  String? _error;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) => _loadNotifications());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    try {
      final notifications = await ApiClient.notifications();
      if (mounted) setState(() { _notifications = notifications; _loading = false; });
    } on ApiException catch (error) {
      if (mounted) setState(() { _error = error.message; _loading = false; });
    }
  }

  Future<void> _markAllRead() async {
    await ApiClient.markAllNotificationsRead();
    await _loadNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(color: burgundy)),
        iconTheme: const IconThemeData(color: burgundy),
        actions: [
          if (_notifications.any((item) => item['is_read'] != true))
            TextButton(onPressed: _markAllRead, child: const Text('Tout lire')),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: burgundy))
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center)))
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  child: _notifications.isEmpty
                      ? ListView(children: const [SizedBox(height: 180), Center(child: Text('Aucune notification'))])
                      : ListView.builder(
                          itemCount: _notifications.length,
                          itemBuilder: (context, index) {
                            final notification = _notifications[index];
                            final isRead = notification['is_read'] == true;
                            return ListTile(
                              tileColor: isRead ? null : const Color(0xFFFFF4F6),
                              leading: Icon(isRead ? Icons.notifications_none : Icons.notifications_active, color: burgundy),
                              title: Text(notification['title'] as String? ?? 'MamaCare', style: TextStyle(fontWeight: isRead ? FontWeight.normal : FontWeight.bold)),
                              subtitle: Text(notification['message'] as String? ?? ''),
                              onTap: isRead ? null : () async {
                                await ApiClient.markNotificationRead((notification['id'] as num).toInt());
                                await _loadNotifications();
                              },
                            );
                          },
                        ),
                ),
    );
  }
}
