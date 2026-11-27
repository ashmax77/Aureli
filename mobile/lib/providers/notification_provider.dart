import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/notification_model.dart';
import '../services/api_service.dart';
import '../services/snapshot_cache_service.dart';

class NotificationProvider with ChangeNotifier {
  final ApiService _apiService;

  static const String _listCacheResource = 'notifications';
  static const String _unreadCacheResource = 'notifications-unread';

  List<NotificationModel> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  int _currentPage = 0;
  bool _hasMore = true;

  // Set once the server has answered, so a slower snapshot read can't overwrite it.
  bool _listFetched = false;
  bool _unreadFetched = false;

  List<NotificationModel> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;

  NotificationProvider(this._apiService) {
    _loadCachedData();
  }

  Future<void> _loadCachedData() async {
    try {
      final userId = _apiService.currentUserId;
      if (userId == null) return;
      final listSnapshot = await SnapshotCacheService.read(
        userId: userId,
        resource: _listCacheResource,
      );
      final unreadSnapshot = await SnapshotCacheService.read(
        userId: userId,
        resource: _unreadCacheResource,
      );

      var changed = false;
      if (!_listFetched &&
          listSnapshot != null &&
          listSnapshot.schemaVersion == SnapshotCacheService.currentSchemaVersion) {
        _notifications = (listSnapshot.data as List)
            .map((e) => NotificationModel.fromJson(e as Map<String, dynamic>))
            .toList();
        // The snapshot is only the first page. Until a refresh fetches page 0 properly,
        // "load more" must not append that page again.
        _hasMore = false;
        changed = true;
      }
      if (!_unreadFetched &&
          unreadSnapshot != null &&
          unreadSnapshot.schemaVersion == SnapshotCacheService.currentSchemaVersion) {
        _unreadCount = ((unreadSnapshot.data as Map<String, dynamic>)['count'] as num?)?.toInt() ?? 0;
        changed = true;
      }
      if (changed) notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint("Error loading cached notifications: $e");
    }
  }

  Future<void> _saveCached(String resource, dynamic data) async {
    try {
      final userId = _apiService.currentUserId;
      if (userId == null) return;
      await SnapshotCacheService.write(userId: userId, resource: resource, data: data);
    } catch (e) {
      if (kDebugMode) debugPrint("Error saving cached notifications: $e");
    }
  }

  Future<void> _saveCachedList() =>
      _saveCached(_listCacheResource, _notifications.map((n) => n.toJson()).toList());

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
        _listFetched = true;

        _hasMore = data['last'] != true;
        _currentPage++;

        // Only the newest page is kept for offline use.
        if (refresh) await _saveCachedList();
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
        _unreadFetched = true;
        notifyListeners();
        await _saveCached(_unreadCacheResource, {'count': _unreadCount});
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
        _unreadFetched = true;
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
        await _saveCached(_unreadCacheResource, {'count': 0});
        // Keep the saved copy in step (an empty list here means nothing has loaded yet,
        // and must not replace a good snapshot).
        if (_notifications.isNotEmpty) await _saveCachedList();
      }
    } catch (e) {
      if (kDebugMode) debugPrint("Error marking notifications as read: $e");
    }
  }
}
