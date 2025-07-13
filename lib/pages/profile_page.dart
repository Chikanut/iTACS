import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../globals.dart';
import 'login_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _rankController = TextEditingController();
  final TextEditingController _positionController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  List<String> _groups = [];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final data = await Globals.firestoreManager.getOrCreateUserData();
    if (data != null) {
      _firstNameController.text = data['firstName'] ?? '';
      _lastNameController.text = data['lastName'] ?? '';
      _rankController.text = data['rank'] ?? '';
      _positionController.text = data['position'] ?? '';
      _phoneController.text = data['phone'] ?? '';
      setState(() {
        _groups = List<String>.from(data['groups'] ?? []);
      });
    }
  }

  Future<void> _saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await Globals.firestoreManager.updateEditableProfileFields(
      uid: user.uid,
      firstName: _firstNameController.text,
      lastName: _lastNameController.text,
      position: _positionController.text,
      rank: _rankController.text,
      phone: _phoneController.text,
    );

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Профіль')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(controller: _firstNameController, decoration: const InputDecoration(labelText: 'Імʼя')),
            TextField(controller: _lastNameController, decoration: const InputDecoration(labelText: 'Прізвище')),
            TextField(controller: _rankController, decoration: const InputDecoration(labelText: 'Звання')),
            TextField(controller: _positionController, decoration: const InputDecoration(labelText: 'Посада')),
            TextField(controller: _phoneController, decoration: const InputDecoration(labelText: 'Телефон')),
            const SizedBox(height: 20),
            if (_groups.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Навчальні групи:', style: TextStyle(fontWeight: FontWeight.bold)),
                  ..._groups.map((g) => Text(g)).toList(),
                  const SizedBox(height: 10),
                ],
              ),
            ElevatedButton(
              onPressed: _saveProfile,
              child: const Text('Зберегти'),
            ),
            const SizedBox(height: 20),
            const Divider(),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (!context.mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                  (route) => false,
                );
              },
              icon: const Icon(Icons.logout),
              label: const Text('Вийти з акаунту'),
            ),
          ],
        ),
      ),
    );
  }
}
