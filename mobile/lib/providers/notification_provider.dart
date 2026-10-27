import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/notification_model.dart';
import '../services/api_service.dart';

class NotificationProvider with ChangeNotifier {
  final ApiService _apiService;

  List<NotificationModel> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  int _currentPage = 0;
  bool _hasMore = true;

  List<NotificationModel> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;

  NotificationProvider(this._apiService);

  Future<void> fetchNotifications({bool refresh = true}) async {
    if (_isLoading || (!refresh && !_hasMore)) return;

    if (refresh) {
      _currentPage = 0;
      _hasMore = true;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.get(
        '/notifications',
        queryParams: {
          'page': _currentPage.toString(),
          'size': '25',
          'sort': 'createdAt,desc',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final content = (data['content'] as List<dynamic>? ?? [])
            .map((e) => NotificationModel.fromJson(e as Map<String, dynamic>))
            .toList();

        if (refresh) {
          _notifications = content;
        } else {
          _notifications.addAll(content);
        }

        _hasMore = data['last'] != true;
        _currentPage++;
      }
    } catch (e) {
      if (kDebugMode) debugPrint("Error fetching notifications: $e");
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
      if (kDebugMode) debugPrint("Error fetching unread count: $e");
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
      if (kDebugMode) debugPrint("Error marking notifications as read: $e");
    }
  }
}
