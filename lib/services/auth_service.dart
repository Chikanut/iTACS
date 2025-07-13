// auth_service.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../globals.dart';

class AuthService {
  static GoogleSignInAccount? currentGoogleUser;

  static Future<void> signInWithGoogle(BuildContext context) async {
  try {
    final GoogleSignInAccount? googleUser = await Globals.googleSignIn.signIn();
    if (googleUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Вхід скасовано')),
      );
      return;
    }

    currentGoogleUser = googleUser;
    final googleAuth = await googleUser.authentication;

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


  Future<String?> getAccessToken() async {

    GoogleSignInAccount? account = Globals.googleSignIn.currentUser;

    account ??= await Globals.googleSignIn.signInSilently();

    account ??= await Globals.googleSignIn.signIn();

    final auth = await account?.authentication;

    if (auth?.accessToken == null) {
      debugPrint('🛑 AccessToken не отримано. Можливо scopes не виставлені або користувач не авторизований знову.');
    }

    return auth?.accessToken;
  }

  Future<bool> isUserAllowed(String email) async {
    return await Globals.firestoreManager.isUserAllowed(email);
  }
}
