import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/category_model.dart';
import '../models/transaction_model.dart';
import '../services/api_service.dart';

class TransactionProvider with ChangeNotifier {
  final ApiService _apiService;

  List<TransactionModel> _transactions = [];
  List<CategoryModel> _categories = [];
  bool _isLoading = false;
  bool _isCategoriesLoading = false;
  bool _isActionLoading = false;
  String? _errorMessage;

  // Pagination & Filtering state
  int _currentPage = 0;
  final int _pageSize = 15;
  bool _hasMore = true;

  TransactionType? selectedType;
  int? selectedCategoryId;
  DateTime? startDate;
  DateTime? endDate;
  double? minAmount;
  double? maxAmount;
  String searchQuery = "";

  List<TransactionModel> get transactions => _transactions;
  List<CategoryModel> get categories => _categories;
  bool get isLoading => _isLoading;
  bool get isCategoriesLoading => _isCategoriesLoading;
  bool get isActionLoading => _isActionLoading;
  String? get errorMessage => _errorMessage;
  int get currentPage => _currentPage;
  bool get hasMore => _hasMore;

  TransactionProvider(this._apiService);

  // Clear filters
  void clearFilters() {
    selectedType = null;
    selectedCategoryId = null;
    startDate = null;
    endDate = null;
    minAmount = null;
    maxAmount = null;
    searchQuery = "";
    _currentPage = 0;
    _hasMore = true;
    notifyListeners();
  }

  // Fetch categories list (for selection drop-downs)
  Future<void> fetchCategories() async {
    _isCategoriesLoading = true;
    notifyListeners();
    try {
      final response = await _apiService.get('/categories');
      if (response.statusCode == 200) {
        final List raw = jsonDecode(response.body) as List? ?? [];
        _categories = raw.map((e) => CategoryModel.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint("Error fetching categories: $e");
    } finally {
      _isCategoriesLoading = false;
      notifyListeners();
    }
  }

  // Create Category
  Future<bool> createCategory(String name, TransactionType type) async {
    try {
      final response = await _apiService.post('/categories', {
        'name': name,
        'type': type.toString().split('.').last,
      });
      if (response.statusCode == 201) {
        await fetchCategories();
        return true;
      }
    } catch (e) {
      debugPrint("Error creating category: $e");
    }
    return false;
  }

  // Update Category
  Future<bool> updateCategory(int id, String name, TransactionType type) async {
    try {
      final response = await _apiService.put('/categories/$id', {
        'name': name,
        'type': type.toString().split('.').last,
      });
      if (response.statusCode == 200) {
        await fetchCategories();
        return true;
      }
    } catch (e) {
      debugPrint("Error updating category: $e");
    }
    return false;
  }

  // Delete Category
  Future<bool> deleteCategory(int id) async {
    try {
      final response = await _apiService.delete('/categories/$id');
      if (response.statusCode == 204) {
        await fetchCategories();
        return true;
      }
    } catch (e) {
      debugPrint("Error deleting category: $e");
    }
    return false;
  }

  // Fetch transactions with pagination
  Future<void> fetchTransactions({bool refresh = false}) async {
    if (_isLoading) return;
    if (refresh) {
      _currentPage = 0;
      _hasMore = true;
      _transactions.clear();
    }
    if (!_hasMore) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final queryParams = _buildQueryParams();
      final response = await _apiService.get('/transactions', queryParams: queryParams);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
        final List content = data['content'] as List? ?? [];
        final bool lastPage = data['last'] as bool? ?? true;

        final newTransactions = content
            .map((e) => TransactionModel.fromJson(e as Map<String, dynamic>))
            .toList();

        _transactions.addAll(newTransactions);
        _hasMore = !lastPage;
        _currentPage++;
      } else {
        _errorMessage = "Failed to fetch transactions: Code ${response.statusCode}";
      }
    } catch (e) {
      _errorMessage = "Network error: $e";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Create transaction
  Future<bool> createTransaction({
    required TransactionType type,
    required int categoryId,
    required double amount,
    required DateTime date,
    required PaymentMethod paymentMethod,
    String? note,
  }) async {
    _isActionLoading = true;
    notifyListeners();
    try {
      final response = await _apiService.post('/transactions', {
        'type': type.toString().split('.').last,
        'categoryId': categoryId,
        'amount': amount,
        'transactionDate': "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}",
        'paymentMethod': paymentMethod.toString().split('.').last,
        'note': note,
      });

      if (response.statusCode == 201) {
        await fetchTransactions(refresh: true);
        return true;
      }
      _errorMessage = "Create failed: Code ${response.statusCode}";
    } catch (e) {
      _errorMessage = "Create network error: $e";
    } finally {
      _isActionLoading = false;
      notifyListeners();
    }
    return false;
  }

  // Update transaction
  Future<bool> updateTransaction(
    int id, {
    required TransactionType type,
    required int categoryId,
    required double amount,
    required DateTime date,
    required PaymentMethod paymentMethod,
    String? note,
  }) async {
    _isActionLoading = true;
    notifyListeners();
    try {
      final response = await _apiService.put('/transactions/$id', {
        'type': type.toString().split('.').last,
        'categoryId': categoryId,
        'amount': amount,
        'transactionDate': "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}",
        'paymentMethod': paymentMethod.toString().split('.').last,
        'note': note,
      });

      if (response.statusCode == 200) {
        await fetchTransactions(refresh: true);
        return true;
      }
      _errorMessage = "Update failed: Code ${response.statusCode}";
    } catch (e) {
      _errorMessage = "Update network error: $e";
    } finally {
      _isActionLoading = false;
      notifyListeners();
    }
    return false;
  }

  // Delete transaction
  Future<bool> deleteTransaction(int id) async {
    _isActionLoading = true;
    notifyListeners();
    try {
      final response = await _apiService.delete('/transactions/$id');
      if (response.statusCode == 204) {
        await fetchTransactions(refresh: true);
        return true;
      }
      _errorMessage = "Delete failed: Code ${response.statusCode}";
    } catch (e) {
      _errorMessage = "Delete network error: $e";
    } finally {
      _isActionLoading = false;
      notifyListeners();
    }
    return false;
  }

  // Fetch CSV export text
  Future<String?> exportCsv() async {
    try {
      final queryParams = _buildQueryParams();
      // Remove page params for full export
      queryParams.remove('page');
      queryParams.remove('size');
      queryParams.remove('sort');

      final response = await _apiService.get('/transactions/export', queryParams: queryParams);
      if (response.statusCode == 200) {
        return response.body;
      }
    } catch (e) {
      debugPrint("CSV Export error: $e");
    }
    return null;
  }

  Map<String, String> _buildQueryParams() {
    final Map<String, String> params = {
      'page': _currentPage.toString(),
      'size': _pageSize.toString(),
      'sort': 'transactionDate,desc',
    };

    if (selectedType != null) {
      params['type'] = selectedType.toString().split('.').last;
    }
    if (selectedCategoryId != null) {
      params['categoryId'] = selectedCategoryId.toString();
    }
    if (startDate != null) {
      params['startDate'] = "${startDate!.year.toString().padLeft(4, '0')}-${startDate!.month.toString().padLeft(2, '0')}-${startDate!.day.toString().padLeft(2, '0')}";
    }
    if (endDate != null) {
      params['endDate'] = "${endDate!.year.toString().padLeft(4, '0')}-${endDate!.month.toString().padLeft(2, '0')}-${endDate!.day.toString().padLeft(2, '0')}";
    }
    if (minAmount != null) {
      params['minAmount'] = minAmount.toString();
    }
    if (maxAmount != null) {
      params['maxAmount'] = maxAmount.toString();
    }
    if (searchQuery.isNotEmpty) {
      params['search'] = searchQuery;
    }

    return params;
  }
}
