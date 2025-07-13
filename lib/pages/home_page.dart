import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

const String kAppVersion = 'v0.1.0';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? 'невідомо';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Домашня сторінка'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: Text(
                kAppVersion,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: Text('✅ Ви залогінені як $email'),
      ),
    );
  }
}
