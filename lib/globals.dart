// globals.dart

import 'package:flutter_application_1/services/error_notification_manager.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'services/auth_service.dart';
import 'services/firebase_options.dart';
import 'services/file_manager.dart';
import 'services/firestore_manager.dart';
import 'services/profile_manager.dart';

class Globals {
  static final GoogleSignIn googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'https://www.googleapis.com/auth/drive.readonly',
    ],
  );

  static final FirebaseAuth firebaseAuth = FirebaseAuth.instance;
  static final FileManager fileManager = FileManager();
  static final AuthService authService = AuthService();
  static final ErrorNotificationManager errorNotificationManager = ErrorNotificationManager();
  static final FirestoreManager firestoreManager = FirestoreManager();
  static final ProfileManager profileManager = ProfileManager(); 
}