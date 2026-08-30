import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../services/api_service.dart';

class NotificationProvider with ChangeNotifier {
  final ApiService _apiService;

  List<NotificationModel> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;

  List<NotificationModel> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;

  NotificationProvider(this._apiService);

  Future<void> fetchNotifications() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.get('/notifications');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _notifications = data.map((e) => NotificationModel.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint("Error fetching notifications: $e");
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchUnreadCount() async {
    try {
      final response = await _apiService.get('/notifications/unread-count');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _unreadCount = (data['count'] as num?)?.toInt() ?? 0;
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error fetching unread count: $e");
    }
  }

  Future<void> markAllAsRead() async {
    try {
      final response = await _apiService.post('/notifications/mark-read', {});
      if (response.statusCode == 200) {
        _unreadCount = 0;
        for (int i = 0; i < _notifications.length; i++) {
          final n = _notifications[i];
          if (!n.isRead) {
            _notifications[i] = NotificationModel(
              id: n.id,
              title: n.title,
              body: n.body,
              isRead: true,
              createdAt: n.createdAt,
            );
          }
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error marking notifications as read: $e");
    }
  }
}
