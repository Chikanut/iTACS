import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../globals.dart';
import 'app_snapshot_store.dart';
import 'auth_service.dart';
import 'firestore_manager.dart';
import 'profile_manager.dart';

enum SessionScreen {
  loading,
  signedOut,
  authenticated,
  offlineAuthenticated,
  accessDenied,
}

abstract class SessionController extends ChangeNotifier {
  SessionScreen get screen;
  bool get isReadOnlyOffline;
  DateTime? get lastSuccessfulSyncAt;

  Future<void> initialize();
  Future<void> signIn(BuildContext context);
  Future<void> signOut();
  Future<void> revalidate();
}

class AppSessionController extends SessionController {
  AppSessionController({
    required AuthService authService,
    required FirebaseAuth firebaseAuth,
    required FirestoreManager firestoreManager,
    required ProfileManager profileManager,
  }) : _authService = authService,
       _firebaseAuth = firebaseAuth,
       _firestoreManager = firestoreManager,
       _profileManager = profileManager {
    _authStateSubscription = _firebaseAuth.authStateChanges().listen(
      _handleAuthStateChanged,
    );
  }

  final AuthService _authService;
  final FirebaseAuth _firebaseAuth;
  final FirestoreManager _firestoreManager;
  final ProfileManager _profileManager;

  late final StreamSubscription<User?> _authStateSubscription;

  SessionScreen _screen = SessionScreen.loading;
  bool _initialized = false;
  bool _isDisposed = false;
  bool _isValidating = false;
  bool _preserveDeniedStateOnNextSignOut = false;
  bool _isReadOnlyOffline = false;
  DateTime? _lastSuccessfulSyncAt;
  SessionSnapshot? _cachedSessionSnapshot;

  @override
  SessionScreen get screen => _screen;

  @override
  bool get isReadOnlyOffline => _isReadOnlyOffline;

  @override
  DateTime? get lastSuccessfulSyncAt => _lastSuccessfulSyncAt;

  @override
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    _initialized = true;
    await _profileManager.initialize();

    _cachedSessionSnapshot = Globals.appSnapshotStore.getSessionSnapshot();
    Globals.startupTelemetry.markSnapshotHydrated();

    if (_cachedSessionSnapshot?.canOpenOfflineShell == true) {
      _enterReadOnlyOffline(
        lastSuccessfulSyncAt: _cachedSessionSnapshot?.lastSuccessfulSyncAt,
      );
      unawaited(_restoreAndValidate(preserveShell: true));
      return;
    }

    await _restoreAndValidate();
  }

  @override
  Future<void> signIn(BuildContext context) async {
    _setScreen(SessionScreen.loading);

    final success = await _authService.signInWithGoogle(context);
    if (!success) {
      if (_firebaseAuth.currentUser == null) {
        _setScreen(SessionScreen.signedOut);
        return;
      }
    }

    await _validateAuthenticatedUser(forceLoading: false);
  }

  @override
  Future<void> signOut() async {
    _setScreen(SessionScreen.loading);
    await _authService.signOut();
    _clearSessionState();
    _setScreen(SessionScreen.signedOut);
  }

  @override
  Future<void> revalidate() async {
    await _restoreAndValidate(preserveShell: _isReadOnlyOffline);
  }

  Future<void> _restoreAndValidate({bool preserveShell = false}) async {
    if (!preserveShell) {
      _setScreen(SessionScreen.loading);
    }

    try {
      await _authService.restoreSession();
    } catch (error) {
      debugPrint('AppSessionController: restore session failed: $error');
    }

    if (_firebaseAuth.currentUser == null) {
      if (preserveShell &&
          _cachedSessionSnapshot?.canOpenOfflineShell == true) {
        _enterReadOnlyOffline(
          lastSuccessfulSyncAt: _cachedSessionSnapshot?.lastSuccessfulSyncAt,
        );
        return;
      }

      await Globals.clearLocalUserState();
      _clearSessionState();
      _setScreen(SessionScreen.signedOut);
      return;
    }

    await _validateAuthenticatedUser(forceLoading: !preserveShell);
  }

  Future<void> _validateAuthenticatedUser({required bool forceLoading}) async {
    if (_isValidating) {
      return;
    }

    _isValidating = true;
    if (forceLoading) {
      _setScreen(SessionScreen.loading);
    }

    try {
      final bootstrap = await _firestoreManager.bootstrapAuthenticatedUser();
      if (!bootstrap.isAllowed) {
        await _handleAccessDenied();
        return;
      }

      await _profileManager.saveBootstrappedProfile(
        userData: bootstrap.userData,
        email: bootstrap.email,
        uid: bootstrap.uid,
        groups: bootstrap.groups,
        rolesPerGroup: bootstrap.rolesByGroup,
        syncedAt: DateTime.now(),
      );
      await _profileManager.loadSavedGroupWithFallback(bootstrap.groupNames);
      await _persistSessionSnapshot(bootstrap);

      if (bootstrap.isFromCache) {
        _enterReadOnlyOffline(lastSuccessfulSyncAt: _lastSuccessfulSyncAt);
      } else {
        _setOnlineValidatedState();
      }
    } catch (error) {
      debugPrint('AppSessionController: validation failed: $error');
      if (_cachedSessionSnapshot?.canOpenOfflineShell == true) {
        _enterReadOnlyOffline(
          lastSuccessfulSyncAt: _cachedSessionSnapshot?.lastSuccessfulSyncAt,
        );
      } else {
        await _authService.signOut();
        _clearSessionState();
        _setScreen(SessionScreen.signedOut);
      }
    } finally {
      _isValidating = false;
      Globals.startupTelemetry.markOnlineRevalidateFinished(
        readOnlyOffline: _isReadOnlyOffline,
      );
      debugPrint(Globals.startupTelemetry.buildSummary());
    }
  }

  Future<void> _handleAccessDenied() async {
    _preserveDeniedStateOnNextSignOut = true;
    await _authService.signOut();
    _clearSessionState();
    _setScreen(SessionScreen.accessDenied);
  }

  void _handleAuthStateChanged(User? user) {
    if (!_initialized || _isDisposed) {
      return;
    }

    if (user == null) {
      if (_preserveDeniedStateOnNextSignOut) {
        _preserveDeniedStateOnNextSignOut = false;
        _setScreen(SessionScreen.accessDenied);
        return;
      }

      if (_screen == SessionScreen.offlineAuthenticated &&
          _cachedSessionSnapshot?.canOpenOfflineShell == true) {
        return;
      }

      if (_screen != SessionScreen.signedOut &&
          _screen != SessionScreen.loading) {
        _setScreen(SessionScreen.signedOut);
      }
      return;
    }

    if (_screen == SessionScreen.signedOut ||
        _screen == SessionScreen.offlineAuthenticated) {
      unawaited(
        _validateAuthenticatedUser(
          forceLoading: _screen == SessionScreen.signedOut,
        ),
      );
    }
  }

  Future<void> _persistSessionSnapshot(SessionBootstrapResult bootstrap) async {
    final syncedAt = bootstrap.isFromCache
        ? (_cachedSessionSnapshot?.lastSuccessfulSyncAt ??
              _lastSuccessfulSyncAt)
        : DateTime.now();

    final snapshot = SessionSnapshot(
      wasSignedIn: true,
      accessGranted: true,
      userScopeId: bootstrap.email,
      userEmail: bootstrap.email,
      userUid: bootstrap.uid,
      groupNames: bootstrap.groupNames,
      lastSuccessfulSyncAt: syncedAt,
    );

    await Globals.appSnapshotStore.saveSessionSnapshot(snapshot);
    _cachedSessionSnapshot = snapshot;
    _lastSuccessfulSyncAt = syncedAt;
  }

  void _setOnlineValidatedState() {
    _isReadOnlyOffline = false;
    Globals.appRuntimeState.updateSessionState(
      isReadOnlyOffline: false,
      lastSuccessfulSyncAt: _lastSuccessfulSyncAt,
    );
    _setScreen(SessionScreen.authenticated);
  }

  void _enterReadOnlyOffline({DateTime? lastSuccessfulSyncAt}) {
    _isReadOnlyOffline = true;
    _lastSuccessfulSyncAt = lastSuccessfulSyncAt;
    Globals.appRuntimeState.updateSessionState(
      isReadOnlyOffline: true,
      lastSuccessfulSyncAt: _lastSuccessfulSyncAt,
    );
    _setScreen(SessionScreen.offlineAuthenticated);
  }

  void _clearSessionState() {
    _isReadOnlyOffline = false;
    _lastSuccessfulSyncAt = null;
    _cachedSessionSnapshot = null;
    Globals.appRuntimeState.clearSessionState();
  }

  void _setScreen(SessionScreen nextScreen) {
    if (_isDisposed || _screen == nextScreen) {
      return;
    }

    _screen = nextScreen;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _authStateSubscription.cancel();
    super.dispose();
  }
}
