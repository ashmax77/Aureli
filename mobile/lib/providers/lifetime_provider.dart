import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/lifetime_stats_model.dart';
import '../models/achievement_model.dart';
import '../services/api_service.dart';

class LifetimeProvider with ChangeNotifier {
  final ApiService _apiService;

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

  LifetimeProvider(this._apiService);

  Future<void> fetchLifetimeData({int? year}) async {
    _selectedYear = year;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      String path = '/lifetime/stats';
      if (year != null) {
        path += '?year=$year';
      }

      final statsResponse = await _apiService.get(path);
      
      if (statsResponse.statusCode == 200) {
        _stats = LifetimeStatsModel.fromJson(jsonDecode(statsResponse.body));
      } else {
        _errorMessage = 'Could not load your lifetime stats. Please try again.';
      }

      final achievementsResponse = await _apiService.get('/lifetime/achievements');

      if (achievementsResponse.statusCode == 200) {
        final List<dynamic> data = jsonDecode(achievementsResponse.body);
        _achievements = data.map((e) => AchievementModel.fromJson(e)).toList();
      }
      
    } catch (e) {
      if (kDebugMode) debugPrint("Error fetching lifetime data: $e");
      _errorMessage = 'Network error. Check your connection and try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setYear(int? year) {
    fetchLifetimeData(year: year);
  }
}
