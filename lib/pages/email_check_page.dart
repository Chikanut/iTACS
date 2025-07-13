import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_1/services/auth_service.dart';

import 'main_scaffold.dart';
import 'access_denied_page.dart';
import 'login_page.dart';

import '../globals.dart';

class EmailCheckPage extends StatefulWidget {
  const EmailCheckPage({super.key});

  @override
  State<EmailCheckPage> createState() => _EmailCheckPageState();
}

class _EmailCheckPageState extends State<EmailCheckPage> {
  @override
  void initState() {
    super.initState();
    _validateEmail();
  }

  Future<void> _validateEmail() async {
    final user = FirebaseAuth.instance.currentUser;
    
    if (user == null) {
      _goTo(const LoginPage());
      return;
    }

    await AuthService.signInWithGoogle(context);

    final isSynced = await Globals.firestoreManager.ensureUserProfileSynced();

    if (!isSynced) {
      await FirebaseAuth.instance.signOut();
      _goTo(const AccessDeniedPage());
    } else {
      _goTo(const MainScaffold());
    }
  }

  void _goTo(Widget page) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
