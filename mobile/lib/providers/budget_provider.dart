import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/budget_summary_model.dart';
import '../models/category_budget_model.dart';
import '../services/api_service.dart';

class BudgetProvider with ChangeNotifier {
  final ApiService _apiService;

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

  BudgetProvider(this._apiService);

  // Set active month & year
  void changeMonth(int year, int month) {
    _selectedYear = year;
    _selectedMonth = month;
    fetchSummary();
  }

  // Fetch monthly summary
  Future<void> fetchSummary() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

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
      } else {
        _errorMessage = "Failed to load budget summary: Code ${response.statusCode}";
      }
    } catch (e) {
      _errorMessage = "Network error loading summary: $e";
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
        _errorMessage = "Failed to set budget: Code ${response.statusCode}";
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
