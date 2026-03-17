import 'package:flutter/material.dart';

import '../services/app_session_controller.dart';

class AccessDeniedPage extends StatelessWidget {
  const AccessDeniedPage({super.key, required this.sessionController});

  final SessionController sessionController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.block, size: 100, color: Colors.redAccent),
              const SizedBox(height: 30),
              const Text(
                '⛔ Доступ заборонено',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Ваш email не має дозволу на використання цієї аплікації.\n'
                'Зверніться до адміністратора для отримання доступу.',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () async {
                  await sessionController.signOut();
                },
                icon: const Icon(Icons.login),
                label: const Text('Повернутись до входу'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
