import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../globals.dart';

class AuthService {
  static const String _signedInMarkerKey = 'auth_signed_in';
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: const ['email'],
  );

  Future<bool> signInWithGoogle(BuildContext context) async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        if (!context.mounted) {
          return false;
        }

        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(const SnackBar(content: Text('❌ Вхід скасовано')));
        return false;
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await Globals.firebaseAuth.signInWithCredential(
        credential,
      );
      await _saveSignInState(true);

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

  Future<void> restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final wasSignedIn = prefs.getBool(_signedInMarkerKey) ?? false;
      final firebaseUser = Globals.firebaseAuth.currentUser;

      if (!wasSignedIn && firebaseUser == null) {
        return;
      }

      final account = await _googleSignIn.signInSilently();
      if (account != null) {
        await _saveSignInState(true);
        debugPrint('✅ Тихий вхід успішний');
      } else if (firebaseUser == null) {
        debugPrint(
          '⚠️ Тихий вхід не вдався, але локальний marker входу збережено',
        );
      }
    } catch (e) {
      debugPrint('🚫 Помилка відновлення авторизації: $e');
      if (Globals.firebaseAuth.currentUser == null && !(await isSignedIn())) {
        await _saveSignInState(false);
      }
    }
  }

  Future<bool> isUserAllowed(String email) async {
    return Globals.firestoreManager.isUserAllowed(email);
  }

  static Future<void> _saveSignInState(bool isSignedIn) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_signedInMarkerKey, isSignedIn);
  }

  static Future<bool> isSignedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_signedInMarkerKey) ?? false;
  }

  Future<void> signOut() async {
    try {
      await Globals.pushNotificationsService.handleSignOut();
      await _googleSignIn.signOut();
      await Globals.firebaseAuth.signOut();
      await _saveSignInState(false);
      await Globals.clearLocalUserState();
    } catch (e) {
      debugPrint('🚫 Помилка виходу: $e');
    }
  }
}
