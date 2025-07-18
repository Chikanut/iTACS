import 'package:flutter/material.dart';

class TemplatesTab extends StatefulWidget {
  const TemplatesTab({super.key});

  @override
  State<TemplatesTab> createState() => _TemplatesTabState();
}

class _TemplatesTabState extends State<TemplatesTab> {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.description,
            size: 64,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'Редагування шаблонів',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Цей функціонал буде реалізований у наступних версіях',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}