// auth_service.dart

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../globals.dart';
import 'web_push_environment.dart';

class DriveReconnectResult {
  const DriveReconnectResult({
    required this.success,
    this.requiresBrowserFallback = false,
    this.message,
  });

  final bool success;
  final bool requiresBrowserFallback;
  final String? message;
}

class AuthService {
  static const String _driveReadonlyScope =
      'https://www.googleapis.com/auth/drive.readonly';
  static const String _driveFileScope =
      'https://www.googleapis.com/auth/drive.file';
  static const List<String> _driveReadScopes = <String>[_driveReadonlyScope];
  static const List<String> _driveWriteScopes = <String>[
    _driveReadonlyScope,
    _driveFileScope,
  ];
  static const List<String> _googleSignInScopes = <String>[
    'email',
    _driveReadonlyScope,
    _driveFileScope,
  ];

  static GoogleSignInAccount? _currentGoogleUser;
  static String? _cachedAccessToken;
  static DateTime? _tokenExpirationTime;

  /// Notifies listeners when Drive session availability changes.
  /// Use this to reactively show/hide [DriveSessionBanner] without polling.
  static final driveSessionAvailable = ValueNotifier<bool>(false);

  // Додаємо необхідні scopes для Google Drive
  static final GoogleSignIn _googleSignInWithDrive = GoogleSignIn(
    scopes: _googleSignInScopes,
  );

  GoogleSignInAccount? get currentGoogleUser => _currentGoogleUser;

  bool get isDriveSessionAvailable => _currentGoogleUser != null;

  static void _setCurrentGoogleUser(GoogleSignInAccount? account) {
    _currentGoogleUser = account;
    driveSessionAvailable.value = account != null;
  }

  bool get requiresBrowserFallbackForDriveReconnect =>
      WebPushEnvironment.isIosBrowser &&
      WebPushEnvironment.isStandaloneDisplayMode;

  Future<bool> signInWithGoogle(BuildContext context) async {
    try {
      final googleUser = await _googleSignInWithDrive.signIn();
      if (googleUser == null) {
        if (!context.mounted) {
          return false;
        }

        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(const SnackBar(content: Text('❌ Вхід скасовано')));
        return false;
      }

      _currentGoogleUser = googleUser;

      // Зберігаємо інформацію про успішний вхід
      await _saveSignInState(true);

      final googleAuth = await googleUser.authentication;

      // Кешуємо токен та час його закінчення
      _cachedAccessToken = googleAuth.accessToken;
      _tokenExpirationTime = DateTime.now().add(const Duration(hours: 1));

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await Globals.firebaseAuth.signInWithCredential(
        credential,
      );

      final email = userCredential.user?.email ?? 'невідомо';
      if (!context.mounted) {
        return true;
      }

      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text('✅ Ви увійшли як $email')));
      return true;
    } catch (e) {
      debugPrint('🚫 Помилка входу: $e');
      if (!context.mounted) {
        return false;
      }

      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text('🚫 Помилка входу: $e')));
      return false;
    }
  }

  /// Відновлення локальної Google-сесії без повторного логіну.
  Future<void> restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final wasSignedIn = prefs.getBool('google_signed_in') ?? false;
      final firebaseUser = Globals.firebaseAuth.currentUser;

      if (!wasSignedIn && firebaseUser == null) {
        return;
      }

      final account = await _googleSignInWithDrive.signInSilently();
      if (account != null) {
        _setCurrentGoogleUser(account);
        debugPrint('✅ Тихий вхід успішний');

        final auth = await account.authentication;
        _cachedAccessToken = auth.accessToken;
        _tokenExpirationTime = DateTime.now().add(const Duration(hours: 1));
        await _saveSignInState(true);
      } else if (firebaseUser == null) {
        debugPrint(
          '⚠️ Тихий вхід не вдався, але локальний marker входу збережено',
        );
      }
    } catch (e) {
      debugPrint('🚫 Помилка відновлення авторизації: $e');
      if (Globals.firebaseAuth.currentUser == null &&
          !(await AuthService.isSignedIn())) {
        await _saveSignInState(false);
      }
    }
  }

  Future<String?> getAccessToken() async {
    return _getAccessTokenForScopes(
      _driveReadScopes,
      allowInteractiveRecovery:
          true, // was false — now allows popup recovery on user gesture
      requireScopeConfirmation: false,
    );
  }

  Future<String?> getDriveWriteAccessToken() async {
    return _getAccessTokenForScopes(
      _driveWriteScopes,
      allowInteractiveRecovery: true,
      requireScopeConfirmation: true,
    );
  }

  Future<String?> _getAccessTokenForScopes(
    List<String> requiredScopes, {
    required bool allowInteractiveRecovery,
    required bool requireScopeConfirmation,
  }) async {
    try {
      // Перевіряємо чи є закешований токен і чи не закінчився
      if (_cachedAccessToken != null &&
          _tokenExpirationTime != null &&
          DateTime.now().isBefore(_tokenExpirationTime!)) {
        debugPrint('✅ Використовуємо закешований токен');
        return _cachedAccessToken;
      }

      GoogleSignInAccount? account =
          _currentGoogleUser ?? _googleSignInWithDrive.currentUser;

      // Якщо немає поточного користувача, спробуємо тихий вхід
      if (account == null) {
        debugPrint('🔄 Спроба тихого входу...');
        account = await _googleSignInWithDrive.signInSilently();
      }

      if (account == null &&
          Globals.firebaseAuth.currentUser != null &&
          allowInteractiveRecovery) {
        // On iOS PWA (standalone), Google OAuth popups are blocked by iOS.
        // Attempting signIn() hangs silently without showing any dialog.
        // Skip interactive recovery and let the caller surface the banner.
        if (!requiresBrowserFallbackForDriveReconnect) {
          debugPrint(
            '🔄 Google session не відновилась тихо, пробуємо інтерактивно відновити Drive доступ...',
          );
          account = await _googleSignInWithDrive.signIn();
        }
      }

      if (account == null) {
        debugPrint('🛑 Користувач не авторизований');
        _setCurrentGoogleUser(null);
        return null;
      }

      _setCurrentGoogleUser(account);

      if (requireScopeConfirmation) {
        final hasRequiredScopes = await _ensureRequiredScopes(
          requiredScopes,
          interactive: allowInteractiveRecovery,
        );
        if (!hasRequiredScopes) {
          debugPrint(
            '🛑 Не вдалося підтвердити потрібні Google Drive scopes: $requiredScopes',
          );
          return null;
        }
      }

      // Оновлюємо токен
      var auth = await account.authentication;

      if (auth.accessToken == null) {
        debugPrint(
          '🛑 AccessToken не отримано. Спробуємо повторну авторизацію...',
        );

        // Не розриваємо Google-сесію перед reauth, інакше після першого
        // логіну silent restore стає ненадійним і popup може більше не
        // з'являтися у наступних спробах.
        account = await _googleSignInWithDrive.signIn();

        if (account == null) {
          return null;
        }

        _setCurrentGoogleUser(account);

        if (requireScopeConfirmation) {
          final hasScopesAfterReauth = await _ensureRequiredScopes(
            requiredScopes,
            interactive: allowInteractiveRecovery,
          );
          if (!hasScopesAfterReauth) {
            debugPrint(
              '🛑 Після повторної авторизації потрібні Google Drive scopes так і не були надані',
            );
            return null;
          }
        }

        auth = await account.authentication;
        _cachedAccessToken = auth.accessToken;
        _tokenExpirationTime = DateTime.now().add(const Duration(hours: 1));

        return _cachedAccessToken;
      }

      // Кешуємо новий токен
      _cachedAccessToken = auth.accessToken;
      _tokenExpirationTime = DateTime.now().add(Duration(hours: 1));
      _setCurrentGoogleUser(account);

      debugPrint('✅ AccessToken отримано успішно');
      return _cachedAccessToken;
    } catch (e) {
      debugPrint('🚫 Помилка отримання AccessToken: $e');
      return null;
    }
  }

  Future<bool> isUserAllowed(String email) async {
    return await Globals.firestoreManager.isUserAllowed(email);
  }

  /// Зберігаємо стан входу
  static Future<void> _saveSignInState(bool isSignedIn) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('google_signed_in', isSignedIn);
  }

  /// Перевіряємо чи користувач увійшов
  static Future<bool> isSignedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('google_signed_in') ?? false;
  }

  Future<void> signOut() async {
    try {
      await Globals.pushNotificationsService.handleSignOut();
      await _googleSignInWithDrive.signOut();
      await Globals.firebaseAuth.signOut();
      await _saveSignInState(false);
      await Globals.clearLocalUserState();

      // Очищаємо кеш
      _cachedAccessToken = null;
      _tokenExpirationTime = null;
      _setCurrentGoogleUser(null);
    } catch (e) {
      debugPrint('🚫 Помилка виходу: $e');
    }
  }

  /// Примусово оновлюємо токен
  Future<String?> forceRefreshToken() async {
    _cachedAccessToken = null;
    _tokenExpirationTime = null;
    return _getAccessTokenForScopes(
      _driveReadScopes,
      allowInteractiveRecovery: true,
      requireScopeConfirmation: false,
    );
  }

  Future<String?> forceRefreshDriveWriteAccessToken() async {
    _cachedAccessToken = null;
    _tokenExpirationTime = null;
    return _getAccessTokenForScopes(
      _driveWriteScopes,
      allowInteractiveRecovery: true,
      requireScopeConfirmation: true,
    );
  }

  /// Explicitly reconnects Google Drive session via interactive sign-in.
  /// Call this from UI when isDriveSessionAvailable is false.
  Future<bool> reconnectDrive() async {
    final result = await reconnectDriveWithDetails();
    return result.success;
  }

  Future<DriveReconnectResult> reconnectDriveWithDetails({
    bool interactiveOnly = false,
  }) async {
    try {
      GoogleSignInAccount? account =
          _currentGoogleUser ?? _googleSignInWithDrive.currentUser;
      if (!interactiveOnly) {
        account ??= await _googleSignInWithDrive.signInSilently();
      }

      // On iOS PWA (standalone), Google OAuth popups are blocked by iOS —
      // window.open() silently fails without showing any dialog.
      // Skip the interactive sign-in attempt and surface the Safari fallback
      // immediately so the user isn't left staring at a frozen spinner.
      if (account == null && requiresBrowserFallbackForDriveReconnect) {
        return DriveReconnectResult(
          success: false,
          requiresBrowserFallback: true,
          message:
              'У режимі додатка на домашньому екрані iPhone Google повторний вхід може блокуватись. Відкрийте iTACS у Safari та підключіть Google Drive там.',
        );
      }

      account ??= await _googleSignInWithDrive.signIn();
      if (account == null) {
        return DriveReconnectResult(
          success: false,
          requiresBrowserFallback: requiresBrowserFallbackForDriveReconnect,
          message: requiresBrowserFallbackForDriveReconnect
              ? 'У режимі додатка на домашньому екрані iPhone Google повторний вхід може блокуватись. Відкрийте iTACS у Safari та підключіть Google Drive там.'
              : 'Не вдалося повторно відкрити Google-вхід для підключення Drive.',
        );
      }

      final hasScopes = await _ensureRequiredScopes(
        _driveWriteScopes,
        interactive: true,
      );
      if (!hasScopes) {
        return DriveReconnectResult(
          success: false,
          requiresBrowserFallback: requiresBrowserFallbackForDriveReconnect,
          message: requiresBrowserFallbackForDriveReconnect
              ? 'Не вдалося підтвердити доступ до Google Drive в режимі додатка на iPhone. Відкрийте iTACS у Safari та повторіть підключення.'
              : 'Google Drive не надав потрібні дозволи. Спробуйте повторити вхід ще раз.',
        );
      }

      _setCurrentGoogleUser(account);
      final auth = await account.authentication;
      _cachedAccessToken = auth.accessToken;
      _tokenExpirationTime = DateTime.now().add(const Duration(hours: 1));
      await _saveSignInState(true);
      debugPrint('AuthService: Drive session reconnected');
      return const DriveReconnectResult(success: true);
    } catch (e) {
      debugPrint('AuthService: reconnectDrive failed: $e');
      return DriveReconnectResult(
        success: false,
        requiresBrowserFallback: requiresBrowserFallbackForDriveReconnect,
        message: requiresBrowserFallbackForDriveReconnect
            ? 'Google Drive не зміг повторно авторизуватись у standalone-режимі iPhone. Відкрийте застосунок у Safari та повторіть вхід.'
            : 'Не вдалося підключитися до Google Drive. Перевірте підключення та спробуйте знову.',
      );
    }
  }

  Future<bool> _ensureRequiredScopes(
    List<String> requiredScopes, {
    required bool interactive,
  }) async {
    final existingAccess = await _canAccessScopes(requiredScopes);
    if (existingAccess == true) {
      return true;
    }

    if (!interactive) {
      return false;
    }

    try {
      debugPrint('🔐 Запитуємо Google Drive scopes: $requiredScopes');
      return await _googleSignInWithDrive.requestScopes(requiredScopes);
    } catch (e) {
      debugPrint('🚫 Не вдалося запросити Google Drive scopes: $e');
      return false;
    }
  }

  Future<bool?> _canAccessScopes(
    List<String> scopes, {
    String? accessToken,
  }) async {
    try {
      return await _googleSignInWithDrive.canAccessScopes(
        scopes,
        accessToken: accessToken,
      );
    } catch (e) {
      debugPrint('⚠️ Не вдалося перевірити Google Drive scopes: $e');
      return null;
    }
  }
}
