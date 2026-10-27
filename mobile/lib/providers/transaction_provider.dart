import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/category_model.dart';
import '../models/transaction_model.dart';
import '../services/api_service.dart';
import '../services/secure_storage_service.dart';
import '../services/offline_queue_service.dart';

enum TransactionCreateResult { success, failed, networkError }

class TransactionProvider with ChangeNotifier {
  final ApiService _apiService;

  static const String _categoriesCacheKey = 'aureli_cached_categories';
  static const String _transactionsCacheKey = 'aureli_cached_transactions';

  List<TransactionModel> _transactions = [];
  List<CategoryModel> _categories = [];
  bool _isLoading = false;
  bool _isCategoriesLoading = false;
  bool _isActionLoading = false;
  bool _isSyncingQueue = false;
  String? _lastCreateRequestId;
  String? _errorMessage;

  // Pagination & Filtering state
  int _currentPage = 0;
  final int _pageSize = 50;
  bool _hasMore = true;

  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;

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
  int get selectedYear => _selectedYear;
  int get selectedMonth => _selectedMonth;

  bool get hasActiveFilters =>
      selectedType != null ||
      selectedCategoryId != null ||
      startDate != null ||
      endDate != null ||
      minAmount != null ||
      maxAmount != null ||
      searchQuery.trim().isNotEmpty;

  void changeMonth(int year, int month, {DateTime? registrationDate}) {
    if (registrationDate != null) {
      if (year < registrationDate.year ||
          (year == registrationDate.year && month < registrationDate.month)) {
        return; // Permanently reject out-of-bounds selection
      }
    }
    _selectedYear = year;
    _selectedMonth = month;
    _currentPage = 0;
    _hasMore = true;
    fetchTransactions(refresh: true);
  }

  TransactionProvider(this._apiService) {
    _loadCachedData();
  }

  Future<void> _loadCachedData() async {
    try {
      final catJson = await SecureStorageService.read(_categoriesCacheKey);
      if (catJson != null) {
        final List raw = jsonDecode(catJson) as List? ?? [];
        _categories = raw
            .map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      final txJson = await SecureStorageService.read(_transactionsCacheKey);
      if (txJson != null) {
        final List rawTx = jsonDecode(txJson) as List? ?? [];
        _transactions = rawTx
            .map((e) => TransactionModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      if (_categories.isNotEmpty || _transactions.isNotEmpty) {
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) debugPrint("Error loading cached transaction data: $e");
    }
  }

  Future<void> _saveCachedCategories() async {
    try {
      await SecureStorageService.write(_categoriesCacheKey,
          jsonEncode(_categories.map((c) => c.toJson()).toList()));
    } catch (e) {
      if (kDebugMode) debugPrint("Error saving cached categories: $e");
    }
  }

  Future<void> _saveCachedTransactions() async {
    try {
      await SecureStorageService.write(_transactionsCacheKey,
          jsonEncode(_transactions.take(15).map((t) => t.toJson()).toList()));
    } catch (e) {
      if (kDebugMode) debugPrint("Error saving cached transactions: $e");
    }
  }

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
  Future<void> fetchCategories({bool force = false}) async {
    if (!force && _categories.isNotEmpty) return;
    _isCategoriesLoading = true;
    notifyListeners();
    try {
      final response = await _apiService.get('/categories');
      if (response.statusCode == 200) {
        final List raw = jsonDecode(response.body) as List? ?? [];
        _categories = raw
            .map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
            .toList();
        await _saveCachedCategories();
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
        if (isOfflineFallback && _categories.isNotEmpty) {
          if (kDebugMode) {
            debugPrint(
                "Using cached categories due to network timeout/offline");
          }
        } else {
          if (kDebugMode) {
            debugPrint("Failed to fetch categories: ${response.statusCode}");
          }
        }
      }
    } catch (e) {
      if (_categories.isNotEmpty) {
        if (kDebugMode) {
          debugPrint(
              "Network error fetching categories (fallback to cache): $e");
        }
      } else {
        if (kDebugMode) debugPrint("Error fetching categories: $e");
      }
    } finally {
      _isCategoriesLoading = false;
      notifyListeners();
    }
  }

  // Create Category
  Future<bool> createCategory(String name, TransactionType type,
      {String? iconKey, String? colorKey}) async {
    try {
      final body = <String, dynamic>{
        'name': name,
        'type': type.toString().split('.').last,
      };
      if (iconKey != null) body['iconKey'] = iconKey;
      if (colorKey != null) body['colorKey'] = colorKey;

      final response = await _apiService.post('/categories', body);
      if (response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final newCategory = CategoryModel.fromJson(data);
        _categories.removeWhere((c) => c.id == newCategory.id);
        _categories.add(newCategory);
        notifyListeners();
        await _saveCachedCategories();
        return true;
      }
    } catch (e) {
      if (kDebugMode) debugPrint("Error creating category: $e");
    }
    return false;
  }

  // Update Category
  Future<bool> updateCategory(int id, String name, TransactionType type,
      {String? iconKey, String? colorKey}) async {
    try {
      final body = <String, dynamic>{
        'name': name,
        'type': type.toString().split('.').last,
      };
      if (iconKey != null) body['iconKey'] = iconKey;
      if (colorKey != null) body['colorKey'] = colorKey;

      final response = await _apiService.put('/categories/$id', body);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final updatedCategory = CategoryModel.fromJson(data);
        final index = _categories.indexWhere((c) => c.id == id);
        if (index != -1) {
          _categories[index] = updatedCategory;
        }
        notifyListeners();
        await _saveCachedCategories();
        return true;
      }
    } catch (e) {
      if (kDebugMode) debugPrint("Error updating category: $e");
    }
    return false;
  }

  // Delete Category
  Future<bool> deleteCategory(int id) async {
    try {
      final response = await _apiService.delete('/categories/$id');
      if (response.statusCode == 204) {
        _categories.removeWhere((c) => c.id == id);
        notifyListeners();
        await _saveCachedCategories();
        return true;
      }
    } catch (e) {
      if (kDebugMode) debugPrint("Error deleting category: $e");
    }
    return false;
  }

  // Fetch transactions with pagination
  Future<void> fetchTransactions({bool refresh = false}) async {
    if (_isLoading) return;
    if (refresh) {
      _currentPage = 0;
      _hasMore = true;
    }
    if (!_hasMore) return;

    _isLoading = true;
    if (_transactions.isEmpty) {
      notifyListeners();
    }
    _errorMessage = null;

    try {
      final queryParams = _buildQueryParams();
      final response =
          await _apiService.get('/transactions', queryParams: queryParams);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            jsonDecode(response.body) as Map<String, dynamic>;
        final List content = data['content'] as List? ?? [];
        final bool lastPage = data['last'] as bool? ?? true;

        final newTransactions = content
            .map((e) => TransactionModel.fromJson(e as Map<String, dynamic>))
            .toList();

        if (refresh) {
          _transactions = newTransactions;
        } else {
          _transactions.addAll(newTransactions);
        }
        _hasMore = !lastPage;
        _currentPage++;

        if (!hasActiveFilters) {
          await _saveCachedTransactions();
          if (refresh) {
            syncOfflineQueue(); // Fire and forget
          }
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

        if (isOfflineFallback && _transactions.isNotEmpty) {
          if (kDebugMode) {
            debugPrint(
                "Using cached transactions due to network timeout/offline");
          }
          // Suppress error
        } else {
          _errorMessage =
              "Failed to fetch transactions: Code ${response.statusCode}";
        }
      }
    } catch (e) {
      if (_transactions.isNotEmpty) {
        if (kDebugMode) {
          debugPrint(
              "Network error fetching transactions (fallback to cache): $e");
        }
      } else {
        _errorMessage = "Network error: $e";
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Create transaction
  Future<TransactionCreateResult> createTransaction({
    required TransactionType type,
    required int categoryId,
    required double amount,
    required DateTime date,
    required PaymentMethod paymentMethod,
    String? note,
    bool? isSavingsEnabled,
    double? savingsRate,
  }) async {
    _isActionLoading = true;
    notifyListeners();
    try {
      final clientRequestId = _generateClientRequestId();
      _lastCreateRequestId = clientRequestId;
      final body = <String, dynamic>{
        'clientRequestId': clientRequestId,
        'type': type.toString().split('.').last,
        'categoryId': categoryId,
        'amount': amount,
        'transactionDate':
            "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}",
        'paymentMethod': paymentMethod.toString().split('.').last,
        'note': note,
      };
      if (isSavingsEnabled != null) body['isSavingsEnabled'] = isSavingsEnabled;
      if (savingsRate != null) body['savingsRate'] = savingsRate;

      final response = await _apiService.post('/transactions', body);

      if (response.statusCode == 201) {
        await fetchTransactions(refresh: true);
        return TransactionCreateResult.success;
      }

      bool isOfflineFallback = false;
      if (response.statusCode >= 500) {
        try {
          final errBody = jsonDecode(response.body) as Map<String, dynamic>;
          if (errBody['isOffline'] == true || errBody['isTimeout'] == true) {
            isOfflineFallback = true;
          }
        } catch (_) {}
      }

      if (isOfflineFallback) {
        _errorMessage = "Network timeout";
        return TransactionCreateResult.networkError;
      }

      _errorMessage = "Create failed: Code ${response.statusCode}";
    } catch (e) {
      _errorMessage = "Create network error: $e";
      return TransactionCreateResult.networkError;
    } finally {
      _isActionLoading = false;
      notifyListeners();
    }
    return TransactionCreateResult.failed;
  }

  Future<void> saveTransactionOffline({
    required TransactionType type,
    required int categoryId,
    required double amount,
    required DateTime date,
    required PaymentMethod paymentMethod,
    String? note,
    bool? isSavingsEnabled,
    double? savingsRate,
  }) async {
    final body = <String, dynamic>{
      'clientRequestId': _lastCreateRequestId ?? _generateClientRequestId(),
      'type': type.toString().split('.').last,
      'categoryId': categoryId,
      'amount': amount,
      'transactionDate':
          "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}",
      'paymentMethod': paymentMethod.toString().split('.').last,
      'note': note,
    };
    if (isSavingsEnabled != null) body['isSavingsEnabled'] = isSavingsEnabled;
    if (savingsRate != null) body['savingsRate'] = savingsRate;

    await OfflineQueueService.enqueueTransaction(body);
    _lastCreateRequestId = null;

    // Create an optimistic local transaction model to show in UI
    final tempTx = TransactionModel(
      id: (body['id'] as int?) ?? -(DateTime.now().millisecondsSinceEpoch),
      type: type,
      amount: amount,
      transactionDate: date,
      paymentMethod: paymentMethod,
      category: categories.firstWhere(
        (c) => c.id == categoryId,
        orElse: () =>
            CategoryModel(id: categoryId, name: "Pending", type: type),
      ),
      note: note,
      isSavingsEnabled: isSavingsEnabled ?? false,
      savingsRate: savingsRate,
      createdAt: DateTime.now(),
    );

    _transactions.insert(0, tempTx);
    notifyListeners();
  }

  Future<void> syncOfflineQueue() async {
    if (_isSyncingQueue) return;
    _isSyncingQueue = true;

    try {
      final queue = await OfflineQueueService.getPendingTransactions();
      if (queue.isEmpty) return;

      if (kDebugMode) {
        debugPrint("Attempting to sync ${queue.length} offline transactions");
      }
      bool hasUpdates = false;

      for (var tx in queue.toList()) {
        try {
          final body = Map<String, dynamic>.from(tx);
          final tempId = body.remove('id');
          body.remove('isPendingOffline');

          final response = await _apiService.post('/transactions', body);
          if (response.statusCode == 201) {
            await OfflineQueueService.removeTransaction(tempId as int);
            hasUpdates = true;
            if (kDebugMode) {
              debugPrint("Successfully synced offline transaction $tempId");
            }
          }
        } catch (e) {
          if (kDebugMode) debugPrint("Failed to sync offline transaction: $e");
        }
      }

      if (hasUpdates) {
        await fetchTransactions(refresh: true);
      }
    } finally {
      _isSyncingQueue = false;
    }
  }

  String _generateClientRequestId() {
    final random = Random.secure();
    final timestamp = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final suffix = List<String>.generate(
      16,
      (_) => random.nextInt(16).toRadixString(16),
    ).join();
    return '$timestamp-$suffix';
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
        'transactionDate':
            "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}",
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

      final response = await _apiService.get('/transactions/export',
          queryParams: queryParams);
      if (response.statusCode == 200) {
        return response.body;
      }
    } catch (e) {
      if (kDebugMode) debugPrint("CSV Export error: $e");
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
      params['startDate'] =
          "${startDate!.year.toString().padLeft(4, '0')}-${startDate!.month.toString().padLeft(2, '0')}-${startDate!.day.toString().padLeft(2, '0')}";
    } else {
      final start = DateTime(_selectedYear, _selectedMonth, 1);
      params['startDate'] =
          "${start.year.toString().padLeft(4, '0')}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}";
    }

    if (endDate != null) {
      params['endDate'] =
          "${endDate!.year.toString().padLeft(4, '0')}-${endDate!.month.toString().padLeft(2, '0')}-${endDate!.day.toString().padLeft(2, '0')}";
    } else {
      final end = DateTime(_selectedYear, _selectedMonth + 1, 0);
      params['endDate'] =
          "${end.year.toString().padLeft(4, '0')}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}";
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
