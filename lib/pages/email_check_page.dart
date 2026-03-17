import 'package:flutter/material.dart';

class EmailCheckPage extends StatelessWidget {
  const EmailCheckPage({
    super.key,
    this.message = 'Перевіряємо сесію та доступ...',
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
