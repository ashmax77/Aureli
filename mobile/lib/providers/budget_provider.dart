import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/budget_summary_model.dart';
import '../models/category_budget_model.dart';
import '../services/api_service.dart';
import '../services/snapshot_cache_service.dart';

class BudgetProvider with ChangeNotifier {
  final ApiService _apiService;

  static const String _summaryCacheResource = 'budget-summary';
  static const Duration _summaryFreshness = Duration(minutes: 5);

  BudgetSummaryModel? _summary;
  BudgetSummaryModel? _dashboardSummary;
  bool _isLoading = false;
  String? _errorMessage;
  DateTime? _summaryFetchedAt;
  DateTime? _dashboardFetchedAt;
  int _summaryRequestGeneration = 0;

  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;

  BudgetSummaryModel? get summary => _summary;
  BudgetSummaryModel? get dashboardSummary => _dashboardSummary;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  int get selectedYear => _selectedYear;
  int get selectedMonth => _selectedMonth;

  BudgetProvider(this._apiService) {
    _loadCachedSummary();
  }

  Future<void> _loadCachedSummary() async {
    try {
      final userId = _apiService.currentUserId;
      if (userId == null) return;
      final snapshot = await SnapshotCacheService.read(
        userId: userId,
        resource: _summaryCacheResource,
      );
      final cachedData = snapshot?.data as Map<String, dynamic>?;
      if (snapshot != null &&
          snapshot.schemaVersion == SnapshotCacheService.currentSchemaVersion &&
          cachedData?['year'] == _selectedYear &&
          cachedData?['month'] == _selectedMonth) {
        _summary = BudgetSummaryModel.fromJson(
            cachedData!['summary'] as Map<String, dynamic>);
        _summaryFetchedAt = snapshot.savedAt;
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) debugPrint("Error loading cached budget summary: $e");
    }
  }

  Future<void> _saveCachedSummary(BudgetSummaryModel summary) async {
    try {
      final userId = _apiService.currentUserId;
      if (userId == null) return;
      await SnapshotCacheService.write(
        userId: userId,
        resource: _summaryCacheResource,
        data: {
          'year': _selectedYear,
          'month': _selectedMonth,
          'summary': summary.toJson(),
        },
      );
    } catch (e) {
      if (kDebugMode) debugPrint("Error saving cached budget summary: $e");
    }
  }

  // FUTURE MODIFICATION NOTE:
  // Currently, the valid transaction time duration for a month is strictly bounded from the 1st day 
  // to the last day of each calendar month. In future releases with direct bank account synchronization, 
  // this will support custom financial month start dates (e.g. user salary payday).
  void changeMonth(int year, int month,
      {DateTime? registrationDate, bool dashboardOnly = false}) {
    if (registrationDate != null) {
      if (year < registrationDate.year || (year == registrationDate.year && month < registrationDate.month)) {
        return; // Permanently reject out-of-bounds selection
      }
    }
    _selectedYear = year;
    _selectedMonth = month;
    _dashboardFetchedAt = null;
    if (dashboardOnly) {
      fetchDashboardSummary(force: true);
    } else {
      fetchSummary(force: true);
    }
  }

  // Fetch monthly summary
  Future<void> fetchSummary({bool force = false}) async {
    await _fetchSummary('/budgets/summary', force: force, saveCache: true);
  }

  Future<void> fetchDashboardSummary({bool force = false}) async {
    if (!force &&
        _dashboardSummary != null &&
        _dashboardFetchedAt != null &&
        DateTime.now().difference(_dashboardFetchedAt!) < _summaryFreshness) {
      return;
    }
    await _fetchSummary('/budgets/dashboard-summary', force: force, saveCache: false, dashboardOnly: true);
  }

  Future<void> _fetchSummary(String path,
      {required bool force, required bool saveCache, bool dashboardOnly = false}) async {
    if (_isLoading && !force) return;
    final cachedSummary = dashboardOnly ? _dashboardSummary : _summary;
    final cachedAt = dashboardOnly ? _dashboardFetchedAt : _summaryFetchedAt;
    if (!force &&
      cachedSummary != null &&
      cachedAt != null &&
      DateTime.now().difference(cachedAt) < _summaryFreshness) {
      return;
    }
    
    _isLoading = true;
    final requestGeneration = ++_summaryRequestGeneration;
    // Only update UI loading indicator if we don't have cached data yet
    if (_summary == null) {
      notifyListeners();
    }
    _errorMessage = null;

    try {
      final response = await _apiService.get(
        path,
        queryParams: {
          'year': _selectedYear.toString(),
          'month': _selectedMonth.toString(),
        },
      );

      if (response.statusCode == 200) {
        if (requestGeneration != _summaryRequestGeneration) return;
        final parsed = BudgetSummaryModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
        if (dashboardOnly) {
          _dashboardSummary = parsed;
          _dashboardFetchedAt = DateTime.now();
        } else {
          _summary = parsed;
          _summaryFetchedAt = DateTime.now();
        }
        if (saveCache && _selectedYear == DateTime.now().year && _selectedMonth == DateTime.now().month) {
          await _saveCachedSummary(_summary!);
        }
      } else {
        bool isOfflineFallback = false;
        if (response.statusCode >= 500) {
          try {
            final errBody = jsonDecode(response.body) as Map<String, dynamic>;
            if (errBody['isOffline'] == true || errBody['isTimeout'] == true) {
              isOfflineFallback = true;
            }
          } catch (_) {}
        }

        if (isOfflineFallback && cachedSummary != null) {
          if (kDebugMode) debugPrint("Using cached budget summary due to network timeout/offline");
          // Suppress error and retain cached summary
        } else {
          _errorMessage = "Failed to load budget summary: Code ${response.statusCode}";
        }
      }
    } catch (e) {
      if (cachedSummary != null) {
        if (kDebugMode) debugPrint("Network error loading summary (fallback to cache): $e");
      } else {
        _errorMessage = "Network error loading summary: $e";
      }
    } finally {
      if (requestGeneration == _summaryRequestGeneration) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  // Set category budget
  Future<CategoryBudgetModel?> setCategoryBudget({
    required int categoryId,
    required DateTime month,
    required double limit,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final String monthStr = "${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}-01";
      final response = await _apiService.post('/budgets', {
        'categoryId': categoryId,
        'budgetMonth': monthStr,
        'amountLimit': limit,
      });

      if (response.statusCode == 201) {
        // Refresh summary
        _summaryFetchedAt = null;
        _isLoading = false;
        await fetchSummary(force: true);
        return CategoryBudgetModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
      } else {
        try {
          final errBody = jsonDecode(response.body) as Map<String, dynamic>;
          _errorMessage = errBody['message'] ?? "Failed to set budget: Code ${response.statusCode}";
        } catch (_) {
          _errorMessage = "Failed to set budget: Code ${response.statusCode}";
        }
      }
    } catch (e) {
      _errorMessage = "Network error setting budget: $e";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return null;
  }
}
