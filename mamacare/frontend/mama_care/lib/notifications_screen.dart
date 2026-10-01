import 'dart:async';

import 'package:flutter/material.dart';

import 'services/api_client.dart';
import 'services/push_notifications.dart';
import 'shared/app_theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const burgundy = AppColors.burgundy;
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;
  String? _error;
  Timer? _refreshTimer;
  bool _pushSupported = false;
  bool _pushActive = false;
  bool _pushBusy = false;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _loadPushState();
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

  Future<void> _loadPushState() async {
    final supported = PushNotifications.isSupported;
    final active = supported ? await PushNotifications.isActive() : false;
    if (!mounted) return;
    setState(() {
      _pushSupported = supported;
      _pushActive = active;
    });
  }

  Future<void> _togglePush(bool enable) async {
    setState(() => _pushBusy = true);
    try {
      if (enable) {
        await PushNotifications.enable();
      } else {
        await PushNotifications.disable();
      }
      if (!mounted) return;
      setState(() {
        _pushActive = enable;
        _pushBusy = false;
      });
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            enable
                ? 'Notifications de rappel activées sur cet appareil.'
                : 'Notifications de rappel désactivées sur cet appareil.',
          ),
        ),
      );
    } on PushException catch (error) {
      if (!mounted) return;
      setState(() => _pushBusy = false);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(error.message)),
      );
      await _loadPushState();
    }
  }

  Widget _pushCard() {
    if (!_pushSupported) {
      return const Card(
        margin: EdgeInsets.fromLTRB(12, 12, 12, 4),
        child: ListTile(
          leading: Icon(Icons.notifications_off_outlined),
          title: Text('Rappels hors application'),
          subtitle: Text(
            "Les notifications push nécessitent un navigateur compatible.",
          ),
        ),
      );
    }
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: SwitchListTile(
        value: _pushActive,
        onChanged: _pushBusy ? null : _togglePush,
        secondary: const Icon(Icons.notifications_active_outlined),
        title: const Text('Rappels hors application'),
        subtitle: Text(
          _pushActive
              ? "Vous serez prévenue même si l'application est fermée."
              : "Activez pour être prévenue même si l'application est fermée.",
        ),
      ),
    );
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
                      ? ListView(children: [const SizedBox(height: 24), _pushCard(), const SizedBox(height: 140), const Center(child: Text('Aucune notification'))])
                      : ListView.builder(
                          itemCount: _notifications.length + 1,
                          itemBuilder: (context, index) {
                            if (index == 0) return _pushCard();
                            final notification = _notifications[index - 1];
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
