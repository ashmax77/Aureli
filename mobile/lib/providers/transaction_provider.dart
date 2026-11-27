import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/category_model.dart';
import '../models/transaction_model.dart';
import '../services/api_service.dart';
import '../services/network_failure.dart';
import '../services/offline_queue_service.dart';
import '../services/snapshot_cache_service.dart';

enum TransactionCreateResult { success, failed, networkError }

class TransactionProvider with ChangeNotifier {
  final ApiService _apiService;

  static const String _categoriesCacheResource = 'categories';
  static const String _transactionsCacheResource = 'transactions';
  static const Duration _categoryFreshness = Duration(minutes: 5);

  /// What the screens show: pending (not yet synced) items on top of [_serverTransactions].
  List<TransactionModel> _transactions = [];

  /// Transactions as last reported by the server (or the snapshot cache).
  List<TransactionModel> _serverTransactions = [];

  /// Raw offline-queue entries, mirrored from encrypted storage.
  List<Map<String, dynamic>> _pendingEntries = [];
  List<CategoryModel> _categories = [];
  bool _isLoading = false;
  bool _isCategoriesLoading = false;
  bool _isActionLoading = false;
  bool _isSyncingQueue = false;
  bool _syncRequestedAgain = false;
  bool _syncAgainIgnoresBackoff = false;
  bool _isOffline = false;
  Timer? _retryTimer;
  StreamSubscription<bool>? _connectivitySubscription;

  /// Called after the server accepted a change to transactions made here (queued items
  /// synced, or a transaction edited / deleted), so dependent data (budget / debt
  /// summaries) can refresh.
  VoidCallback? onFinancialDataChanged;

  /// How long to wait before one more sync attempt after a connection-level failure.
  final Duration retryDelay;
  int _transactionRequestGeneration = 0;
  String? _lastCreateRequestId;
  String? _errorMessage;
  String? _actionErrorMessage;
  DateTime? _lastUpdatedAt;
  DateTime? _categoriesFetchedAt;

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

  /// [connectivityChanges] emits `true` when a network interface comes up and `false`
  /// when the last one goes away (see ConnectivityService); when omitted the provider
  /// simply does not react to connectivity changes.
  TransactionProvider(
    this._apiService, {
    Stream<bool>? connectivityChanges,
    this.onFinancialDataChanged,
    this.retryDelay = const Duration(seconds: 30),
  }) {
    _loadCachedData();
    _loadPendingFromQueue();
    _connectivitySubscription = connectivityChanges?.listen((online) {
      if (online) {
        onConnectivityRestored();
      } else {
        _isOffline = true;
        notifyListeners();
      }
    });
  }

  /// When the transaction data on screen was last confirmed by the server (or, right
  /// after a restart, when the cached snapshot was saved). Null until anything loaded.
  DateTime? get lastUpdatedAt => _lastUpdatedAt;

  /// Number of transactions saved on this device that still wait to be synced.
  int get pendingCount => _pendingEntries.length;

  /// True when the last attempt to reach the server failed at connection level (or the
  /// device reported no network). Cleared by the next successful response.
  bool get isOffline => _isOffline;

  /// Re-reads the persisted offline queue so pending items survive app restarts and
  /// stay in step with what the sync loop has removed.
  Future<void> _loadPendingFromQueue() async {
    _pendingEntries = await _readQueueSafely();
    _rebuildDisplay();
    notifyListeners();
  }

  Future<List<Map<String, dynamic>>> _readQueueSafely() async {
    try {
      return await OfflineQueueService.getPendingTransactions();
    } catch (e) {
      if (kDebugMode) debugPrint("Error loading offline queue: $e");
      return [];
    }
  }

  void _rebuildDisplay() {
    final pending = <TransactionModel>[];
    // Newest queued entry first, matching how fresh transactions are listed.
    for (final entry in _pendingEntries.reversed) {
      try {
        final tx = _pendingFromEntry(entry);
        if (_matchesCurrentView(tx)) pending.add(tx);
      } catch (e) {
        if (kDebugMode) debugPrint("Skipping unreadable queued transaction: $e");
      }
    }
    _transactions = [...pending, ..._serverTransactions];
  }

  TransactionModel _pendingFromEntry(Map<String, dynamic> entry) {
    final type =
        entry['type'] == 'INCOME' ? TransactionType.INCOME : TransactionType.EXPENSE;
    final categoryId = (entry['categoryId'] as num).toInt();
    return TransactionModel(
      id: (entry['id'] as num).toInt(),
      type: type,
      amount: (entry['amount'] as num).toDouble(),
      transactionDate: DateTime.parse(entry['transactionDate'] as String),
      paymentMethod: entry['paymentMethod'] == 'BANK_TRANSFER'
          ? PaymentMethod.BANK_TRANSFER
          : PaymentMethod.CASH,
      category: _categories.firstWhere(
        (c) => c.id == categoryId,
        orElse: () => CategoryModel(id: categoryId, name: "Pending", type: type),
      ),
      note: entry['note'] as String?,
      isSavingsEnabled: entry['isSavingsEnabled'] as bool?,
      savingsRate: (entry['savingsRate'] as num?)?.toDouble(),
      createdAt:
          DateTime.tryParse(entry['queuedAt'] as String? ?? '')?.toLocal() ??
              DateTime.now(),
      isPending: true,
      syncAttempts: (entry['attempts'] as num?)?.toInt() ?? 0,
    );
  }

  /// A pending item is only listed where the server would list it: inside the selected
  /// month (or custom date range) and matching every active filter.
  bool _matchesCurrentView(TransactionModel tx) {
    DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
    final from = dateOnly(startDate ?? DateTime(_selectedYear, _selectedMonth, 1));
    final to = dateOnly(endDate ?? DateTime(_selectedYear, _selectedMonth + 1, 0));
    final day = dateOnly(tx.transactionDate);
    if (day.isBefore(from) || day.isAfter(to)) return false;
    if (selectedType != null && tx.type != selectedType) return false;
    if (selectedCategoryId != null && tx.category.id != selectedCategoryId) {
      return false;
    }
    if (minAmount != null && tx.amount < minAmount!) return false;
    if (maxAmount != null && tx.amount > maxAmount!) return false;
    final query = searchQuery.trim().toLowerCase();
    if (query.isNotEmpty && !(tx.note ?? '').toLowerCase().contains(query)) {
      return false;
    }
    return true;
  }

  Future<void> _loadCachedData() async {
    try {
      final userId = _apiService.currentUserId;
      if (userId == null) return;
      final categorySnapshot = await SnapshotCacheService.read(
        userId: userId,
        resource: _categoriesCacheResource,
      );
      if (categorySnapshot != null &&
          categorySnapshot.schemaVersion == SnapshotCacheService.currentSchemaVersion) {
        final List raw = categorySnapshot.data as List? ?? [];
        _categories = raw
            .map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
            .toList();
        _categoriesFetchedAt = categorySnapshot.savedAt;
      }
      final transactionSnapshot = await SnapshotCacheService.read(
        userId: userId,
        resource: _transactionsCacheResource,
      );
      final cachedTransactions = transactionSnapshot?.data as Map<String, dynamic>?;
      if (transactionSnapshot != null &&
          transactionSnapshot.schemaVersion == SnapshotCacheService.currentSchemaVersion &&
          cachedTransactions?['year'] == _selectedYear &&
          cachedTransactions?['month'] == _selectedMonth) {
        final List rawTx = cachedTransactions!['transactions'] as List? ?? [];
        _serverTransactions = rawTx
            .map((e) => TransactionModel.fromJson(e as Map<String, dynamic>))
            .toList();
        // Only adopt the snapshot's age if a fresh fetch hasn't already landed.
        _lastUpdatedAt ??= transactionSnapshot.savedAt;
        _rebuildDisplay();
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
      final userId = _apiService.currentUserId;
      if (userId == null) return;
      await SnapshotCacheService.write(
        userId: userId,
        resource: _categoriesCacheResource,
        data: _categories.map((c) => c.toJson()).toList(),
      );
    } catch (e) {
      if (kDebugMode) debugPrint("Error saving cached categories: $e");
    }
  }

  Future<void> _saveCachedTransactions() async {
    try {
      final userId = _apiService.currentUserId;
      if (userId == null) return;
      await SnapshotCacheService.write(
        userId: userId,
        resource: _transactionsCacheResource,
        data: {
          'year': _selectedYear,
          'month': _selectedMonth,
          // Server data only: pending items live in the offline queue, not the snapshot.
          'transactions': _serverTransactions.take(15).map((t) => t.toJson()).toList(),
        },
      );
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
    if (!force &&
        _categories.isNotEmpty &&
        _categoriesFetchedAt != null &&
        DateTime.now().difference(_categoriesFetchedAt!) < _categoryFreshness) {
      return;
    }
    _isCategoriesLoading = true;
    notifyListeners();
    try {
      final response = await _apiService.get('/categories');
      if (response.statusCode == 200) {
        final List raw = jsonDecode(response.body) as List? ?? [];
        _categories = raw
            .map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
            .toList();
        _categoriesFetchedAt = DateTime.now();
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
    _actionErrorMessage = null;
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
      _actionErrorMessage = _serverMessage(response, "Could not create the category");
    } catch (e) {
      _actionErrorMessage = "Could not create the category: $e";
      if (kDebugMode) debugPrint("Error creating category: $e");
    }
    notifyListeners();
    return false;
  }

  // Update Category
  Future<bool> updateCategory(int id, String name, TransactionType type,
      {String? iconKey, String? colorKey}) async {
    _actionErrorMessage = null;
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
      _actionErrorMessage = _serverMessage(response, "Could not update the category");
    } catch (e) {
      _actionErrorMessage = "Could not update the category: $e";
      if (kDebugMode) debugPrint("Error updating category: $e");
    }
    notifyListeners();
    return false;
  }

  // Delete Category
  Future<bool> deleteCategory(int id) async {
    _actionErrorMessage = null;
    try {
      final response = await _apiService.delete('/categories/$id');
      if (response.statusCode == 204) {
        _categories.removeWhere((c) => c.id == id);
        notifyListeners();
        await _saveCachedCategories();
        return true;
      }
      _actionErrorMessage = _serverMessage(response, "Could not delete the category");
    } catch (e) {
      _actionErrorMessage = "Could not delete the category: $e";
      if (kDebugMode) debugPrint("Error deleting category: $e");
    }
    notifyListeners();
    return false;
  }

  // Fetch transactions with pagination
  Future<void> fetchTransactions({bool refresh = false}) async {
    // A refresh supersedes any in-flight request (its response is discarded below via
    // the generation check); only pagination requests are dropped while loading.
    if (_isLoading && !refresh) return;
    if (refresh) {
      _currentPage = 0;
      _hasMore = true;
    }
    if (!_hasMore) return;

    _isLoading = true;
    final requestGeneration = ++_transactionRequestGeneration;
    if (_transactions.isEmpty) {
      notifyListeners();
    }
    _errorMessage = null;

    try {
      final queryParams = _buildQueryParams();
      final response =
          await _apiService.get('/transactions', queryParams: queryParams);

      // Ignore responses (including errors) from requests superseded by a newer one.
      if (requestGeneration != _transactionRequestGeneration) return;

      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            jsonDecode(response.body) as Map<String, dynamic>;
        final List content = data['content'] as List? ?? [];
        final bool lastPage = data['last'] as bool? ?? true;

        final newTransactions = content
            .map((e) => TransactionModel.fromJson(e as Map<String, dynamic>))
            .toList();

        // Re-read the queue so not-yet-synced items are layered on top of the fresh list.
        // Read before assigning, then re-check the generation: no await may sit between
        // the check and the assignment or a superseded response could overwrite newer data.
        final queued = await _readQueueSafely();
        if (requestGeneration != _transactionRequestGeneration) return;

        if (refresh) {
          _serverTransactions = newTransactions;
        } else {
          _serverTransactions.addAll(newTransactions);
        }
        _pendingEntries = queued;
        _rebuildDisplay();
        _isOffline = false;
        if (!hasActiveFilters) _lastUpdatedAt = DateTime.now();
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

        if (isOfflineFallback) {
          if (kDebugMode) {
            debugPrint(
                "Using cached transactions due to network timeout/offline");
          }
          // Keep whatever we have (cache + pending), re-applying the current filters
          // to pending items. Only complain when there is nothing at all to show.
          _rebuildDisplay();
          _isOffline = true;
          // No further pages can load right now; without this the list's "load more"
          // spinner would animate forever. A refresh re-arms pagination.
          _hasMore = false;
          if (_serverTransactions.isEmpty && _pendingEntries.isEmpty) {
            _errorMessage =
                "You're offline. Connect to the internet to load your transactions.";
          }
        } else {
          _errorMessage =
              "Failed to fetch transactions: Code ${response.statusCode}";
        }
      }
    } catch (e) {
      if (requestGeneration != _transactionRequestGeneration) return;
      if (_transactions.isNotEmpty) {
        if (kDebugMode) {
          debugPrint(
              "Network error fetching transactions (fallback to cache): $e");
        }
      } else {
        _errorMessage = "Network error: $e";
      }
    } finally {
      if (requestGeneration == _transactionRequestGeneration) {
        _isLoading = false;
        notifyListeners();
      }
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
        // The server has it. Nothing below may change that outcome: reporting an error here
        // would make the caller offer to save it again (a duplicate).
        try {
          await fetchTransactions(refresh: true);
        } catch (e) {
          if (kDebugMode) debugPrint("Refreshing transactions after create failed: $e");
        }
        // Whichever screen saved it, budgets, the dashboard, analytics and lifetime stats
        // all depend on this transaction, so this runs even if the refresh above failed.
        try {
          onFinancialDataChanged?.call();
        } catch (e) {
          if (kDebugMode) debugPrint("Summary refresh after create failed: $e");
        }
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
        _isOffline = true;
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

    // The queue is the source of truth: show the saved item from it (marked pending).
    await _loadPendingFromQueue();
  }

  /// Drops a not-yet-synced transaction from the offline queue (e.g. one the server keeps
  /// rejecting). Only pending items (negative local ids) can be discarded this way.
  Future<void> discardPendingTransaction(int localId) async {
    if (!_pendingEntries.any((e) => e['id'] == localId)) return;
    await OfflineQueueService.removeTransaction(localId);
    await _loadPendingFromQueue();
  }

  /// Replays queued transactions to the server, oldest first.
  ///
  /// - [ignoreBackoff]: set for explicit triggers (network came back, app resumed) so a
  ///   previously rejected item is retried now instead of waiting out its backoff.
  /// - A dropped connection / timeout / gateway error (see [_isTransientFailure]) is not
  ///   the item's fault: the pass stops without growing its retry counter, and a single
  ///   delayed retry is scheduled.
  /// - Items queued while a pass runs are picked up by that same call.
  ///
  /// Returns true when it ended by refreshing the transaction list from the server.
  Future<bool> syncOfflineQueue({bool ignoreBackoff = false}) async {
    if (_isSyncingQueue) {
      // A pass is already running; make it go around once more so this trigger
      // (e.g. "network is back") is not lost.
      _syncRequestedAgain = true;
      _syncAgainIgnoresBackoff = _syncAgainIgnoresBackoff || ignoreBackoff;
      return false;
    }
    _isSyncingQueue = true;
    _retryTimer?.cancel();

    var syncedAny = false;
    var hitTransientFailure = false;
    final attemptedThisCall = <int>{};
    var passIgnoresBackoff = ignoreBackoff;

    try {
      bool progressed;
      do {
        _syncRequestedAgain = false;
        progressed = false;

        final queue = await OfflineQueueService.getPendingTransactions();
        if (queue.isEmpty) break;
        if (kDebugMode) {
          debugPrint("Attempting to sync ${queue.length} offline transactions");
        }

        for (final tx in queue) {
          final tempId = (tx['id'] as num?)?.toInt();
          if (tempId == null || attemptedThisCall.contains(tempId)) continue;
          if (!passIgnoresBackoff) {
            final nextAttemptAt =
                DateTime.tryParse(tx['nextAttemptAt'] as String? ?? '');
            if (nextAttemptAt != null &&
                nextAttemptAt.isAfter(DateTime.now().toUtc())) {
              continue;
            }
          }
          attemptedThisCall.add(tempId);

          try {
            final body = Map<String, dynamic>.from(tx)
              ..remove('id')
              ..remove('isPendingOffline')
              ..remove('queueId')
              ..remove('attempts')
              ..remove('nextAttemptAt')
              ..remove('queuedAt');

            final response = await _apiService.post('/transactions', body);
            if (response.statusCode == 201) {
              await OfflineQueueService.removeTransaction(tempId);
              syncedAny = true;
              progressed = true;
              _isOffline = false;
              if (kDebugMode) {
                debugPrint("Successfully synced offline transaction $tempId");
              }
            } else if (_isTransientFailure(response)) {
              hitTransientFailure = true;
              if (isConnectivityFailure(response)) _isOffline = true;
              break; // the rest would fail the same way; try again later
            } else {
              await OfflineQueueService.recordFailure(tempId);
            }
          } catch (e) {
            await OfflineQueueService.recordFailure(tempId);
            if (kDebugMode) debugPrint("Failed to sync offline transaction: $e");
          }
        }

        if (_syncRequestedAgain) {
          // An explicit trigger (network back, app resumed) arrived mid-pass: conditions
          // may have changed since items were tried, so go around again from scratch.
          passIgnoresBackoff = passIgnoresBackoff || _syncAgainIgnoresBackoff;
          _syncAgainIgnoresBackoff = false;
          attemptedThisCall.clear();
          progressed = true;
        }
      } while (progressed && !hitTransientFailure);

      var refreshed = false;
      if (syncedAny) {
        // Release the lock first: the refresh below re-triggers a (cheap) sync pass and
        // any trigger arriving meanwhile must not be swallowed.
        _isSyncingQueue = false;
        await fetchTransactions(refresh: true);
        refreshed = true;
        onFinancialDataChanged?.call();
      } else {
        await _loadPendingFromQueue(); // surfaces updated retry counts / offline flag
      }
      if (hitTransientFailure) _scheduleRetry();
      return refreshed;
    } finally {
      _isSyncingQueue = false;
    }
  }

  /// Connection dropped, timed out, or a gateway/rate-limit/auth hiccup: nothing is wrong
  /// with the queued transaction itself.
  bool _isTransientFailure(http.Response response) {
    const transientStatuses = {401, 408, 429, 502, 503, 504};
    return transientStatuses.contains(response.statusCode) ||
        isConnectivityFailure(response);
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    _retryTimer = Timer(retryDelay, () {
      syncOfflineQueue(ignoreBackoff: true);
    });
  }

  /// The network came back: replay the queue, and if that did not already refresh the
  /// list, refresh it so stale cached data is replaced.
  Future<void> onConnectivityRestored() async {
    final refreshed = await syncOfflineQueue(ignoreBackoff: true);
    if (!refreshed) await fetchTransactions(refresh: true);
  }

  /// Sync right now, ignoring retry backoff (e.g. the user tapped "Sync now").
  Future<void> syncNow() => syncOfflineQueue(ignoreBackoff: true);

  /// The app returned to the foreground: flush anything still queued.
  Future<void> onAppResumed() => syncNow();

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _retryTimer?.cancel();
    super.dispose();
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

  /// Why the last edit/delete failed. Kept apart from [errorMessage] because that one
  /// replaces the whole transaction list on screen.
  String? get actionErrorMessage => _actionErrorMessage;

  String _serverMessage(http.Response response, String fallback) {
    final connectivity = connectivityFailureMessage(response);
    if (connectivity != null) return connectivity;
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body['message'] is String) {
        return body['message'] as String;
      }
    } catch (_) {}
    return "$fallback (code ${response.statusCode})";
  }

  /// Edits a transaction that already exists on the server. This is a full replacement
  /// on the backend, so every field is sent; for income the savings settings must be
  /// passed too or the server would silently re-enable savings.
  ///
  /// Needs the server (not queued offline): a failure leaves the transaction untouched
  /// and explains why in [actionErrorMessage].
  Future<bool> updateTransaction(
    int id, {
    required TransactionType type,
    required int categoryId,
    required double amount,
    required DateTime date,
    required PaymentMethod paymentMethod,
    String? note,
    bool? isSavingsEnabled,
    double? savingsRate,
  }) async {
    _actionErrorMessage = null;
    if (id <= 0) {
      _actionErrorMessage =
          "This transaction hasn't synced yet. Wait for it to sync, or discard it and add it again.";
      notifyListeners();
      return false;
    }
    _isActionLoading = true;
    notifyListeners();
    try {
      final body = <String, dynamic>{
        'type': type.toString().split('.').last,
        'categoryId': categoryId,
        'amount': amount,
        'transactionDate':
            "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}",
        'paymentMethod': paymentMethod.toString().split('.').last,
        'note': note,
      };
      if (type == TransactionType.INCOME) {
        if (isSavingsEnabled != null) body['isSavingsEnabled'] = isSavingsEnabled;
        if (savingsRate != null && isSavingsEnabled != false) {
          body['savingsRate'] = savingsRate;
        }
      }
      final response = await _apiService.put('/transactions/$id', body);

      if (response.statusCode == 200) {
        _isOffline = false;
        await fetchTransactions(refresh: true);
        onFinancialDataChanged?.call();
        return true;
      }
      if (isConnectivityFailure(response)) _isOffline = true;
      _actionErrorMessage = _serverMessage(response, "Update failed");
    } catch (e) {
      _actionErrorMessage = "Update failed: $e";
    } finally {
      _isActionLoading = false;
      notifyListeners();
    }
    return false;
  }

  /// Deletes a transaction that exists on the server. Needs the server; a failure leaves
  /// it in place and explains why in [actionErrorMessage]. (Pending items are removed
  /// with [discardPendingTransaction].)
  Future<bool> deleteTransaction(int id) async {
    _actionErrorMessage = null;
    if (id <= 0) {
      _actionErrorMessage =
          "This transaction hasn't synced yet. Discard it instead.";
      notifyListeners();
      return false;
    }
    _isActionLoading = true;
    notifyListeners();
    try {
      final response = await _apiService.delete('/transactions/$id');
      // 404: it is already gone (e.g. deleted on another device) - the goal is met.
      if (response.statusCode == 204 ||
          response.statusCode == 200 ||
          response.statusCode == 404) {
        _isOffline = false;
        await fetchTransactions(refresh: true);
        onFinancialDataChanged?.call();
        return true;
      }
      if (isConnectivityFailure(response)) _isOffline = true;
      _actionErrorMessage = _serverMessage(response, "Delete failed");
    } catch (e) {
      _actionErrorMessage = "Delete failed: $e";
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
