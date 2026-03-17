import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'firestore_manager.dart';
import 'profile_manager.dart';

enum SessionScreen { loading, signedOut, authenticated, accessDenied }

abstract class SessionController extends ChangeNotifier {
  SessionScreen get screen;

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

  @override
  SessionScreen get screen => _screen;

  @override
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    _initialized = true;
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
    _setScreen(SessionScreen.signedOut);
  }

  @override
  Future<void> revalidate() async {
    if (_firebaseAuth.currentUser == null) {
      _setScreen(SessionScreen.signedOut);
      return;
    }

    await _validateAuthenticatedUser(forceLoading: true);
  }

  Future<void> _restoreAndValidate() async {
    _setScreen(SessionScreen.loading);

    try {
      await _authService.restoreSession();
    } catch (error) {
      debugPrint('AppSessionController: restore session failed: $error');
    }

    if (_firebaseAuth.currentUser == null) {
      _setScreen(SessionScreen.signedOut);
      return;
    }

    await _validateAuthenticatedUser(forceLoading: false);
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
      final isSynced = await _firestoreManager.ensureUserProfileSynced();
      if (!isSynced) {
        await _handleAccessDenied();
        return;
      }

      await _profileManager.initialize();
      await _profileManager.loadAndSyncProfile();
      _setScreen(SessionScreen.authenticated);
    } catch (error) {
      debugPrint('AppSessionController: validation failed: $error');
      await _authService.signOut();
      _setScreen(SessionScreen.signedOut);
    } finally {
      _isValidating = false;
    }
  }

  Future<void> _handleAccessDenied() async {
    _preserveDeniedStateOnNextSignOut = true;
    await _authService.signOut();
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

      if (_screen != SessionScreen.signedOut &&
          _screen != SessionScreen.loading) {
        _setScreen(SessionScreen.signedOut);
      }
      return;
    }

    if (_screen == SessionScreen.signedOut) {
      unawaited(_validateAuthenticatedUser(forceLoading: true));
    }
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
