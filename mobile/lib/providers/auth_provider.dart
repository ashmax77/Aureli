import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/auth_error_mapper.dart';
import '../services/api_service.dart';
import '../services/network_failure.dart';
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
  String? _actionErrorMessage;
  AuthStatus _status = AuthStatus.initializing;
  int _authGeneration = 0;
  String? _profileSyncUid;
  Future<bool>? _profileSyncFuture;

  User? get firebaseUser => _firebaseUser;
  UserModel? get userModel => _userModel;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Why the last profile change (savings rate, onboarding) failed. Separate from
  /// [errorMessage], which the sign-in screens display.
  String? get actionErrorMessage => _actionErrorMessage;
  AuthStatus get status => _status;

  // Email verification. Soft: it never blocks the app, it only prompts. Defaults to
  // "verified" so nothing is shown while signed out or before the first check.
  bool _emailVerified = true;
  bool _verificationBannerDismissed = false;
  bool _verificationEmailSent = false;
  bool _isSendingVerification = false;

  /// The signed-in person has not confirmed their email address yet.
  bool get needsEmailVerification => _firebaseUser != null && !_emailVerified;

  /// [needsEmailVerification], unless they waved the reminder away for this session.
  bool get showVerificationBanner =>
      needsEmailVerification && !_verificationBannerDismissed;

  /// A verification email went out during this session (so the reminder can say so).
  bool get verificationEmailSent => _verificationEmailSent;
  bool get isSendingVerification => _isSendingVerification;

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
      _resetEmailVerification();
      _userModel = null;
      _isLoading = false;
      _status = AuthStatus.signedOut;
      _profileSyncUid = null;
      _profileSyncFuture = null;
      await _clearCachedUser();
      notifyListeners();
      return;
    }

    _emailVerified = _authService.isEmailVerified;
    _isLoading = true;
    _status = AuthStatus.syncingProfile;
    notifyListeners();
    await _syncAuthenticatedUser(user, generation: generation);
  }

  void _resetEmailVerification() {
    _emailVerified = true;
    _verificationBannerDismissed = false;
    _verificationEmailSent = false;
    _isSendingVerification = false;
  }

  /// Emails the signed-in user a verification link. Returns null on success, otherwise a
  /// message that can be shown to the user.
  Future<String?> sendVerificationEmail() async {
    final uid = _firebaseUser?.uid;
    if (uid == null || _emailVerified) return null;
    if (_isSendingVerification) return null;
    _isSendingVerification = true;
    notifyListeners();
    try {
      await _authService.sendEmailVerification();
      if (_firebaseUser?.uid == uid) _verificationEmailSent = true;
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'too-many-requests') {
        return 'Please wait a moment before asking for another email.';
      }
      return AuthErrorMapper.message(e);
    } catch (e) {
      return AuthErrorMapper.message(e);
    } finally {
      if (_firebaseUser?.uid == uid) {
        _isSendingVerification = false;
        notifyListeners();
      }
    }
  }

  /// Asks Firebase whether the user has opened the link yet; the reminder goes away on its
  /// own once they have. Returns whether the address is verified, or null when the check
  /// could not be made (offline), in which case nothing changes.
  Future<bool?> refreshEmailVerification() async {
    final uid = _firebaseUser?.uid;
    if (uid == null) return null;
    try {
      final verified = await _authService.reloadEmailVerified();
      if (_firebaseUser?.uid != uid) return null;
      if (verified != _emailVerified) {
        _emailVerified = verified;
        notifyListeners();
      }
      return verified;
    } catch (e) {
      if (kDebugMode) debugPrint("Error refreshing email verification: $e");
      return null;
    }
  }

  void dismissVerificationBanner() {
    if (_verificationBannerDismissed) return;
    _verificationBannerDismissed = true;
    notifyListeners();
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
    // A profile already in memory (cached, or the provisional one from sign-up) lets the
    // app show its screens while the server answers in the background.
    final hasCache = await _loadCachedUser(user.uid) || _userModel?.firebaseUid == user.uid;
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
      _emailVerified = _authService.isEmailVerified;
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
      _emailVerified = _authService.isEmailVerified;

      // Ask them to confirm the address. It runs alongside everything else so signing up
      // never waits on the email; if it fails the reminder offers "Resend".
      unawaited(sendVerificationEmail());

      // The account was only just created, so it cannot have finished onboarding yet.
      // Show the onboarding screen straight away instead of a spinner that lasts as long
      // as the server takes to answer; the real profile replaces this one when it arrives.
      // It is not cached, so a failed sync never leaves a made-up profile behind.
      if (_userModel?.firebaseUid != user.uid) {
        _userModel = UserModel(
          firebaseUid: user.uid,
          email: user.email ?? email,
          onboardingStatus: OnboardingStatus.NOT_STARTED,
        );
        _status = AuthStatus.ready;
        notifyListeners();
      }

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
        _actionErrorMessage = connectivityFailureMessage(response) ?? _errorMessage;
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = "Network error completing onboarding: $e";
      _actionErrorMessage = _errorMessage;
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
    _actionErrorMessage = null;
    try {
      final response = await _apiService.patch('/me/savings-rate', {'savingsRatePercentage': rate});
      if (response.statusCode == 200) {
        _userModel = UserModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
        await _saveCachedUser(_userModel!);
        notifyListeners();
        return true;
      }
      _actionErrorMessage = connectivityFailureMessage(response) ??
          "Could not update your savings rate (code ${response.statusCode})";
    } catch (e) {
      _actionErrorMessage = "Could not update your savings rate: $e";
      if (kDebugMode) debugPrint("Error updating savings rate: $e");
    }
    notifyListeners();
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
