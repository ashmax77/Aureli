import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/budget_summary_model.dart';
import '../models/category_budget_model.dart';
import '../services/api_service.dart';
import '../services/secure_storage_service.dart';

class BudgetProvider with ChangeNotifier {
  final ApiService _apiService;

  static const String _summaryCacheKey = 'aureli_cached_budget_summary';

  BudgetSummaryModel? _summary;
  bool _isLoading = false;
  String? _errorMessage;

  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;

  BudgetSummaryModel? get summary => _summary;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  int get selectedYear => _selectedYear;
  int get selectedMonth => _selectedMonth;

  BudgetProvider(this._apiService) {
    _loadCachedSummary();
  }

  Future<void> _loadCachedSummary() async {
    try {
      final cached = await SecureStorageService.read(_summaryCacheKey);
      if (cached != null) {
        _summary = BudgetSummaryModel.fromJson(jsonDecode(cached) as Map<String, dynamic>);
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) debugPrint("Error loading cached budget summary: $e");
    }
  }

  Future<void> _saveCachedSummary(BudgetSummaryModel summary) async {
    try {
      await SecureStorageService.write(_summaryCacheKey, jsonEncode(summary.toJson()));
    } catch (e) {
      if (kDebugMode) debugPrint("Error saving cached budget summary: $e");
    }
  }

  // FUTURE MODIFICATION NOTE:
  // Currently, the valid transaction time duration for a month is strictly bounded from the 1st day 
  // to the last day of each calendar month. In future releases with direct bank account synchronization, 
  // this will support custom financial month start dates (e.g. user salary payday).
  void changeMonth(int year, int month) {
    _selectedYear = year;
    _selectedMonth = month;
    fetchSummary();
  }

  // Fetch monthly summary
  Future<void> fetchSummary() async {
    if (_isLoading) return;
    
    _isLoading = true;
    // Only update UI loading indicator if we don't have cached data yet
    if (_summary == null) {
      notifyListeners();
    }
    _errorMessage = null;

    try {
      final response = await _apiService.get(
        '/budgets/summary',
        queryParams: {
          'year': _selectedYear.toString(),
          'month': _selectedMonth.toString(),
        },
      );

      if (response.statusCode == 200) {
        _summary = BudgetSummaryModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
        if (_selectedYear == DateTime.now().year && _selectedMonth == DateTime.now().month) {
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

        if (isOfflineFallback && _summary != null) {
          if (kDebugMode) debugPrint("Using cached budget summary due to network timeout/offline");
          // Suppress error and retain cached summary
        } else {
          _errorMessage = "Failed to load budget summary: Code ${response.statusCode}";
        }
      }
    } catch (e) {
      if (_summary != null) {
        if (kDebugMode) debugPrint("Network error loading summary (fallback to cache): $e");
      } else {
        _errorMessage = "Network error loading summary: $e";
      }
    } finally {
      _isLoading = false;
      notifyListeners();
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
        await fetchSummary();
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
