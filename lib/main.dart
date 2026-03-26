import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'services/firebase_options.dart';
import 'pages/auth_gate.dart';
import 'globals.dart';
import 'theme/app_theme.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

Future<void> _configureFirestorePersistence() async {
  final firestore = FirebaseFirestore.instance;

  if (kIsWeb) {
    try {
      await firestore.enablePersistence(
        const PersistenceSettings(synchronizeTabs: true),
      );
    } catch (error) {
      debugPrint('Firestore web persistence setup skipped: $error');
    }
    return;
  }

  firestore.settings = const Settings(persistenceEnabled: true);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Globals.startupTelemetry.startIfNeeded();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  await initializeDateFormatting('uk', null);

  if (kIsWeb) {
    await Hive.initFlutter(); // автоматично використовує hive_web
  } else {
    final dir = await getApplicationDocumentsDirectory();
    Hive.init(dir.path);
  }

  if (kIsWeb) {
    await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
  }

  await _configureFirestorePersistence();
  await Globals.init();

  runApp(const MyApp());
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(Globals.warmUpInBackground());
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'iTACS',
      theme: AppTheme.darkTheme,
      home: const AuthGate(),
      builder: (context, child) {
        Globals.errorNotificationManager.setContext(context);
        return child ?? const SizedBox.shrink();
      },
      debugShowCheckedModeBanner: false,

      // Додати локалізацію 👇
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('uk', 'UA'), // Українська
        Locale('en', 'US'), // Англійська (fallback)
      ],
      locale: const Locale('uk', 'UA'),
    );
  }
}
