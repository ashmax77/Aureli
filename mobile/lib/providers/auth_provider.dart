import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/auth_error_mapper.dart';
import '../services/api_service.dart';
import '../services/secure_storage_service.dart';
import '../services/snapshot_cache_service.dart';

enum AuthStatus {
  initializing,
  signedOut,
  syncingProfile,
  ready,
  profileSyncFailed,
}

class AuthProvider with ChangeNotifier {
  final AuthGateway _authService;
  final ApiService _apiService;

  static const String _userCacheResource = 'profile';

  User? _firebaseUser;
  UserModel? _userModel;
  bool _isLoading = true;
  String? _errorMessage;
  AuthStatus _status = AuthStatus.initializing;
  int _authGeneration = 0;
  String? _profileSyncUid;
  Future<bool>? _profileSyncFuture;

  User? get firebaseUser => _firebaseUser;
  UserModel? get userModel => _userModel;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  AuthStatus get status => _status;

  bool get isAuthenticated => _firebaseUser != null;
  bool get needsOnboarding => _userModel != null && _userModel!.onboardingStatus == OnboardingStatus.NOT_STARTED;

  AuthProvider(this._authService, this._apiService) {
    _authService.userChanges.listen(_onAuthStateChanged);
  }

  Future<bool> _loadCachedUser(String userId) async {
    try {
      final cached = await SnapshotCacheService.read(
        userId: userId,
        resource: _userCacheResource,
      );
      if (cached != null && cached.schemaVersion == SnapshotCacheService.currentSchemaVersion) {
        _userModel = UserModel.fromJson(cached.data as Map<String, dynamic>);
        notifyListeners();
        return true;
      }
    } catch (e) {
      if (kDebugMode) debugPrint("Error loading cached user: $e");
    }
    return false;
  }

  Future<void> _saveCachedUser(UserModel user) async {
    try {
      await SnapshotCacheService.write(
        userId: user.firebaseUid,
        resource: _userCacheResource,
        data: user.toJson(),
      );
    } catch (e) {
      if (kDebugMode) debugPrint("Error saving cached user: $e");
    }
  }

  Future<void> _clearCachedUser() async {
    try {
      final userId = _authService.currentUser?.uid;
      if (userId != null) {
        await SnapshotCacheService.invalidate(
          userId: userId,
          resource: _userCacheResource,
        );
      }
    } catch (_) {}
  }

  Future<void> _onAuthStateChanged(User? user) async {
    final previousUserId = _firebaseUser?.uid;
    if (user != null &&
        previousUserId == user.uid &&
        _profileSyncFuture != null) {
      return;
    }
    final generation = ++_authGeneration;
    _firebaseUser = user;
    _errorMessage = null;

    if (user == null) {
      _userModel = null;
      _isLoading = false;
      _status = AuthStatus.signedOut;
      _profileSyncUid = null;
      _profileSyncFuture = null;
      await _clearCachedUser();
      notifyListeners();
      return;
    }

    _isLoading = true;
    _status = AuthStatus.syncingProfile;
    notifyListeners();
    await _syncAuthenticatedUser(user, generation: generation);
  }

  Future<bool> _syncAuthenticatedUser(User user, {required int generation}) {
    if (_profileSyncUid == user.uid && _profileSyncFuture != null) {
      return _profileSyncFuture!;
    }

    _profileSyncUid = user.uid;
    final future = _performProfileSync(user, generation: generation);
    _profileSyncFuture = future;
    future.then((_) {
      if (identical(_profileSyncFuture, future)) {
        _profileSyncFuture = null;
      }
    }, onError: (_) {
      if (identical(_profileSyncFuture, future)) {
        _profileSyncFuture = null;
      }
    });
    return future;
  }

  Future<bool> _performProfileSync(User user, {required int generation}) async {
    final hasCache = await _loadCachedUser(user.uid);
    if (generation != _authGeneration || _firebaseUser?.uid != user.uid) {
      return false;
    }

    _isLoading = !hasCache;
    _status = hasCache ? AuthStatus.ready : AuthStatus.syncingProfile;
    notifyListeners();
    return fetchUserProfile(
      silent: hasCache,
      expectedUserId: user.uid,
      expectedGeneration: generation,
    );
  }

  // Fetch or Provision local user profile
  Future<bool> fetchUserProfile({
    bool silent = false,
    String? expectedUserId,
    int? expectedGeneration,
  }) async {
    if (!silent) {
      _isLoading = true;
      notifyListeners();
    }
    try {
      final response = await _apiService.get('/me');
      if ((expectedUserId != null && _firebaseUser?.uid != expectedUserId) ||
          (expectedGeneration != null && expectedGeneration != _authGeneration)) {
        return false;
      }
      if (response.statusCode == 200) {
        _userModel = UserModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
        if (_userModel!.firebaseUid != _firebaseUser?.uid) {
          _errorMessage = "The account profile does not match the signed-in user.";
          _status = AuthStatus.profileSyncFailed;
          return false;
        }
        await _saveCachedUser(_userModel!);
        _status = AuthStatus.ready;
        return true;
      } else {
        _errorMessage = "Backend profile sync status: ${response.statusCode}";
        _status = _userModel != null ? AuthStatus.ready : AuthStatus.profileSyncFailed;
      }
    } catch (e) {
      _errorMessage = "Network error syncing profile: $e";
      _status = _userModel != null ? AuthStatus.ready : AuthStatus.profileSyncFailed;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return false;
  }

  // Login
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _authService.signIn(email, password);
      final user = _authService.currentUser;
      if (user == null) {
        _errorMessage = "Sign-in completed, but the account session was not ready.";
        _status = AuthStatus.profileSyncFailed;
        return false;
      }
      _firebaseUser = user;
      final generation = ++_authGeneration;
      return await _syncAuthenticatedUser(user, generation: generation);
    } catch (e) {
      _errorMessage = AuthErrorMapper.message(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Sign Up
  Future<bool> signUp(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _authService.signUp(email, password);
      final user = _authService.currentUser;
      if (user == null) {
        _errorMessage = "Account creation completed, but the account session was not ready.";
        _status = AuthStatus.profileSyncFailed;
        return false;
      }
      _firebaseUser = user;
      final generation = ++_authGeneration;
      return await _syncAuthenticatedUser(user, generation: generation);
    } catch (e) {
      _errorMessage = AuthErrorMapper.message(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Complete Onboarding status
  Future<bool> completeOnboarding() async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _apiService.patch('/me/onboarding', {'status': 'COMPLETED'});
      if (response.statusCode == 200) {
        _userModel = UserModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
        await _saveCachedUser(_userModel!);
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = "Failed to complete onboarding: Code ${response.statusCode}";
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = "Network error completing onboarding: $e";
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Register device FCM token
  Future<void> registerFcmToken(String token) async {
    try {
      final response = await _apiService.patch('/me/fcm-token', {'fcmToken': token});
      if (response.statusCode != 200) {
        if (kDebugMode) debugPrint("Failed to register FCM token: Code ${response.statusCode}");
      }
    } catch (e) {
      if (kDebugMode) debugPrint("Error registering FCM token: $e");
    }
  }

  // Update Savings Rate percentage
  Future<bool> updateSavingsRate(double rate) async {
    try {
      final response = await _apiService.patch('/me/savings-rate', {'savingsRatePercentage': rate});
      if (response.statusCode == 200) {
        _userModel = UserModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
        await _saveCachedUser(_userModel!);
        notifyListeners();
        return true;
      }
    } catch (e) {
      if (kDebugMode) debugPrint("Error updating savings rate: $e");
    }
    return false;
  }

  // Sign out
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();
    // CRITICAL: Clear ALL encrypted caches (transactions, budgets, debts, offline queue)
    await SecureStorageService.deleteAll();
    await _authService.signOut();
  }

  // Send password reset email
  Future<bool> sendPasswordResetEmail(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _authService.sendPasswordResetEmail(email);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = AuthErrorMapper.message(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

}
