// auth_service.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../globals.dart';

class AuthService {
  static GoogleSignInAccount? currentGoogleUser;
  static String? _cachedAccessToken;
  static DateTime? _tokenExpirationTime;

  // Додаємо необхідні scopes для Google Drive
  static final GoogleSignIn _googleSignInWithDrive = GoogleSignIn(
    scopes: [
      'email',
      'https://www.googleapis.com/auth/drive.readonly',
    ],
  );

  static Future signInWithGoogle(BuildContext context) async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignInWithDrive.signIn();
      if (googleUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Вхід скасовано')),
        );
        return;
      }

      currentGoogleUser = googleUser;
      
      // Зберігаємо інформацію про успішний вхід
      await _saveSignInState(true);
      
      final googleAuth = await googleUser.authentication;

      // Кешуємо токен та час його закінчення
      _cachedAccessToken = googleAuth.accessToken;
      _tokenExpirationTime = DateTime.now().add(Duration(hours: 1)); // Google токени живуть близько години

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential =
          await Globals.firebaseAuth.signInWithCredential(credential);

      final email = userCredential.user?.email ?? 'невідомо';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Ви увійшли як $email')),
      );
    } catch (e) {
      debugPrint('🚫 Помилка входу: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('🚫 Помилка входу: $e')),
      );
    }
  }

  /// Ініціалізація при запуску додатка
  static Future<void> initializeAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final wasSignedIn = prefs.getBool('google_signed_in') ?? false;
      
      if (wasSignedIn) {
        // Спробуємо тихо увійти
        final account = await _googleSignInWithDrive.signInSilently();
        if (account != null) {
          currentGoogleUser = account;
          debugPrint('✅ Тихий вхід успішний');
          
          // Отримуємо fresh токен
          final auth = await account.authentication;
          _cachedAccessToken = auth.accessToken;
          _tokenExpirationTime = DateTime.now().add(Duration(hours: 1));
        } else {
          debugPrint('⚠️ Тихий вхід не вдався, користувач має увійти знову');
          await _saveSignInState(false);
        }
      }
    } catch (e) {
      debugPrint('🚫 Помилка ініціалізації авторизації: $e');
      await _saveSignInState(false);
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
        await _saveSignInState(false);
        return null;
      }

      // Оновлюємо токен
      final auth = await account.authentication;

      if (auth.accessToken == null) {
        debugPrint('🛑 AccessToken не отримано. Спробуємо повторну авторизацію...');
        
        // Спробуємо очистити кеш і увійти знову
        await _googleSignInWithDrive.signOut();
        account = await _googleSignInWithDrive.signIn();
        
        if (account == null) {
          await _saveSignInState(false);
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
      currentGoogleUser = account;

      debugPrint('✅ AccessToken отримано успішно');
      return _cachedAccessToken;
    } catch (e) {
      debugPrint('🚫 Помилка отримання AccessToken: $e');
      await _saveSignInState(false);
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

  /// Додаємо метод для виходу
  Future<void> signOut() async {
    try {
      await _googleSignInWithDrive.signOut();
      await Globals.firebaseAuth.signOut();
      await _saveSignInState(false);
      
      // Очищаємо кеш
      _cachedAccessToken = null;
      _tokenExpirationTime = null;
      currentGoogleUser = null;
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