import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/auth_service.dart';
import 'email_check_page.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            await AuthService.signInWithGoogle(context);

            if (FirebaseAuth.instance.currentUser != null) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const EmailCheckPage()),
              );
            }
          },
          child: const Text('Увійти через Google'),
        ),
      ),
    );
  }
}
