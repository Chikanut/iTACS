import 'package:flutter/material.dart';

import '../services/app_session_controller.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key, required this.sessionController});

  final SessionController sessionController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            await sessionController.signIn(context);
          },
          child: const Text('Увійти через Google'),
        ),
      ),
    );
  }
}
