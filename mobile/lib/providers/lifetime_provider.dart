import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/lifetime_stats_model.dart';
import '../models/achievement_model.dart';
import '../services/api_service.dart';
import '../services/snapshot_cache_service.dart';

class LifetimeProvider with ChangeNotifier {
  final ApiService _apiService;

  static const String _achievementsCacheResource = 'lifetime-achievements';

  /// One snapshot per view ("all time" or a single year), so switching years offline
  /// still shows what was last seen for that year.
  static String _statsCacheResource(int? year) => 'lifetime-stats-${year ?? 'all'}';

  LifetimeStatsModel? _stats;
  List<AchievementModel> _achievements = [];
  bool _isLoading = false;
  String? _errorMessage;

  int? _selectedYear; // null means 'All Time'

  LifetimeStatsModel? get stats => _stats;
  List<AchievementModel> get achievements => _achievements;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int? get selectedYear => _selectedYear;

  LifetimeProvider(this._apiService) {
    _loadCachedData();
  }

  Future<void> _loadCachedData() async {
    try {
      final userId = _apiService.currentUserId;
      if (userId == null) return;
      final year = _selectedYear;
      final cachedStats = await _readCachedStats(userId, year);
      final achievementsSnapshot = await SnapshotCacheService.read(
        userId: userId,
        resource: _achievementsCacheResource,
      );

      // Anything a fetch has already delivered is newer than the snapshot.
      var changed = false;
      if (cachedStats != null && _stats == null && _selectedYear == year) {
        _stats = cachedStats;
        changed = true;
      }
      if (achievementsSnapshot != null &&
          achievementsSnapshot.schemaVersion == SnapshotCacheService.currentSchemaVersion &&
          _achievements.isEmpty) {
        _achievements = (achievementsSnapshot.data as List)
            .map((e) => AchievementModel.fromJson(e as Map<String, dynamic>))
            .toList();
        changed = true;
      }
      if (changed) notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint("Error loading cached lifetime data: $e");
    }
  }

  Future<LifetimeStatsModel?> _readCachedStats(String userId, int? year) async {
    final snapshot = await SnapshotCacheService.read(
      userId: userId,
      resource: _statsCacheResource(year),
    );
    if (snapshot == null ||
        snapshot.schemaVersion != SnapshotCacheService.currentSchemaVersion) {
      return null;
    }
    return LifetimeStatsModel.fromJson(snapshot.data as Map<String, dynamic>);
  }

  Future<void> _saveCached(String resource, dynamic data) async {
    try {
      final userId = _apiService.currentUserId;
      if (userId == null) return;
      await SnapshotCacheService.write(userId: userId, resource: resource, data: data);
    } catch (e) {
      if (kDebugMode) debugPrint("Error saving cached lifetime data: $e");
    }
  }

  /// When the server can't be reached, show what was last seen for this view instead of
  /// nothing (or another year's numbers).
  Future<void> _useCachedStats(int? year) async {
    try {
      final userId = _apiService.currentUserId;
      if (userId == null) return;
      final cached = await _readCachedStats(userId, year);
      if (cached != null) _stats = cached;
    } catch (e) {
      if (kDebugMode) debugPrint("Error reading cached lifetime stats: $e");
    }
  }

  Future<void> fetchLifetimeData({int? year}) async {
    _selectedYear = year;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    var gotFreshStats = false;
    try {
      String path = '/lifetime/stats';
      if (year != null) {
        path += '?year=$year';
      }

      final statsResponse = await _apiService.get(path);
      
      if (statsResponse.statusCode == 200) {
        _stats = LifetimeStatsModel.fromJson(jsonDecode(statsResponse.body));
        gotFreshStats = true;
        await _saveCached(_statsCacheResource(year), _stats!.toJson());
      } else {
        _errorMessage = 'Could not load your lifetime stats. Please try again.';
        await _useCachedStats(year);
      }

      final achievementsResponse = await _apiService.get('/lifetime/achievements');

      if (achievementsResponse.statusCode == 200) {
        final List<dynamic> data = jsonDecode(achievementsResponse.body);
        _achievements = data.map((e) => AchievementModel.fromJson(e)).toList();
        await _saveCached(
          _achievementsCacheResource,
          _achievements.map((a) => a.toJson()).toList(),
        );
      }
      
    } catch (e) {
      if (kDebugMode) debugPrint("Error fetching lifetime data: $e");
      _errorMessage = 'Network error. Check your connection and try again.';
      if (!gotFreshStats) await _useCachedStats(year);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setYear(int? year) {
    fetchLifetimeData(year: year);
  }
}
