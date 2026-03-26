// auth_service.dart

import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../globals.dart';

class AuthService {
  static GoogleSignInAccount? _currentGoogleUser;
  static String? _cachedAccessToken;
  static DateTime? _tokenExpirationTime;

  // Додаємо необхідні scopes для Google Drive
  static final GoogleSignIn _googleSignInWithDrive = GoogleSignIn(
    scopes: ['email', 'https://www.googleapis.com/auth/drive.readonly'],
  );

  GoogleSignInAccount? get currentGoogleUser => _currentGoogleUser;

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
        _currentGoogleUser = account;
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
    try {
      // Перевіряємо чи є закешований токен і чи не закінчився
      if (_cachedAccessToken != null &&
          _tokenExpirationTime != null &&
          DateTime.now().isBefore(_tokenExpirationTime!)) {
        debugPrint('✅ Використовуємо закешований токен');
        return _cachedAccessToken;
      }

      GoogleSignInAccount? account = _googleSignInWithDrive.currentUser;

      // Якщо немає поточного користувача, спробуємо тихий вхід
      if (account == null) {
        debugPrint('🔄 Спроба тихого входу...');
        account = await _googleSignInWithDrive.signInSilently();
      }

      if (account == null) {
        debugPrint('🛑 Користувач не авторизований');
        return null;
      }

      // Оновлюємо токен
      final auth = await account.authentication;

      if (auth.accessToken == null) {
        debugPrint(
          '🛑 AccessToken не отримано. Спробуємо повторну авторизацію...',
        );

        // Спробуємо очистити кеш і увійти знову
        await _googleSignInWithDrive.signOut();
        account = await _googleSignInWithDrive.signIn();

        if (account == null) {
          return null;
        }

        final newAuth = await account.authentication;
        _cachedAccessToken = newAuth.accessToken;
        _tokenExpirationTime = DateTime.now().add(Duration(hours: 1));

        return _cachedAccessToken;
      }

      // Кешуємо новий токен
      _cachedAccessToken = auth.accessToken;
      _tokenExpirationTime = DateTime.now().add(Duration(hours: 1));
      _currentGoogleUser = account;

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
      _currentGoogleUser = null;
    } catch (e) {
      debugPrint('🚫 Помилка виходу: $e');
    }
  }

  /// Примусово оновлюємо токен
  Future<String?> forceRefreshToken() async {
    _cachedAccessToken = null;
    _tokenExpirationTime = null;
    return await getAccessToken();
  }
}
