import 'package:flutter/material.dart';

class GroupMembersTab extends StatefulWidget {
  const GroupMembersTab({super.key});

  @override
  State<GroupMembersTab> createState() => _GroupMembersTabState();
}

class _GroupMembersTabState extends State<GroupMembersTab> {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.group,
            size: 64,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'Управління учасниками групи',
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