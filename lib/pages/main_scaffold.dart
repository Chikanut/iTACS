import 'package:flutter/material.dart';
import 'home_page.dart';
import 'calendar_page/calendar_page.dart'; // додано
import 'materials_page/materials_page.dart';
import 'profile_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'email_check_page.dart';
import '../globals.dart';
import 'tools_page/tools_page.dart';
import 'admin_page/admin_panel_page.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;
  Map<String, String> groupNames = {};
  bool _groupsLoaded = false;

  final List<Widget> _pages = const [
    AdminPanelPage(), // Адмін-панель
    HomePage(),
    CalendarPage(),   // 🗓️ нова сторінка — календар
    ToolsPage(),
    MaterialsPage(),
  ];

  bool isMobileLayout(BuildContext context) {
    final shortestSide = MediaQuery.of(context).size.shortestSide;
    return shortestSide < 600;
  }

  @override
  void initState() {
    super.initState();
    _initGroups();
  }

  Future<void> _initGroups() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final email = user.email!;
    groupNames = await Globals.firestoreManager.getGroupNamesForUser(email);
    await Globals.profileManager.loadSavedGroupWithFallback(groupNames);

    if (mounted) setState(() => _groupsLoaded = true);
  }

  void _onMenuSelect(String value) {
    switch (value) {
      case 'admin_panel':
        setState(() => _currentIndex = 0);
        break;
      case 'home':
        setState(() => _currentIndex = 1);
        break;
      case 'calendar':
        setState(() => _currentIndex = 2);
        break;
      case 'tools':
        setState(() => _currentIndex = 3);
        break;
      case 'materials':
        setState(() => _currentIndex = 4);
        break;
      case 'logout':
        FirebaseAuth.instance.signOut();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = isMobileLayout(context);
    final user = FirebaseAuth.instance.currentUser;
    final initials = user?.displayName != null && user!.displayName!.contains(' ')
        ? user.displayName!.split(' ').map((e) => e[0]).take(2).join()
        : user?.email?.substring(0, 2).toUpperCase() ?? '?';

    return Scaffold(
      appBar: AppBar(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 8),
            IconButton(
              icon: CircleAvatar(
                radius: 14,
                child: Text(initials),
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfilePage()),
              ),
            ),
          ],
        ),
        title: _groupsLoaded
            ? Row(
                children: [
                  if (groupNames.length > 1)
                    PopupMenuButton<String>(
                      onSelected: (selectedGroupId) async {
                        final groupName = groupNames[selectedGroupId]!;
                        await Globals.profileManager.setCurrentGroup(selectedGroupId, groupName);
                        if (!mounted) return;
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => const EmailCheckPage()),
                        );
                      },
                      itemBuilder: (context) => groupNames.entries.map((entry) {
                        return PopupMenuItem<String>(
                          value: entry.key,
                          child: Text(entry.value),
                        );
                      }).toList(),
                      child: Row(
                        children: [
                          Text(
                            Globals.profileManager.currentGroupName ?? 'Оберіть групу',
                            style: const TextStyle(color: Colors.white),
                          ),
                          const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                        ],
                      ),
                    )
                  else
                    Text(
                      Globals.profileManager.currentGroupName ?? '',
                      style: const TextStyle(color: Colors.white),
                    ),
                ],
              )
            : const Text('Завантаження...'),
        actions: [
          if (!isMobile)
            PopupMenuButton<String>(
              onSelected: _onMenuSelect,
              itemBuilder: (_) => [
                if (Globals.profileManager.currentRole == 'admin')
                   PopupMenuItem(value: 'admin_panel', child: Text('Адмін-панель')),
                PopupMenuItem(value: 'home', child: Text('Головна')),
                PopupMenuItem(value: 'calendar', child: Text('Календар')),
                PopupMenuItem(value: 'tools', child: Text('Інструменти')),
                PopupMenuItem(value: 'materials', child: Text('Матеріали')),
                
              ],
            ),
        ],
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: isMobile
          ? BottomNavigationBar(
              backgroundColor: Colors.white,
              selectedItemColor: Colors.blue,
              unselectedItemColor: Colors.grey,
              currentIndex: _currentIndex,
              onTap: (index) => setState(() => _currentIndex = index),
              items: [
                if (Globals.profileManager.currentRole == 'admin')
                  const BottomNavigationBarItem(icon: Icon(Icons.admin_panel_settings), label: 'Адмін-панель'),
                const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Головна'),
                const BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: 'Календар'),
                const BottomNavigationBarItem(icon: Icon(Icons.build), label: 'Інструменти'),
                const BottomNavigationBarItem(icon: Icon(Icons.article), label: 'Матеріали'),
              ],
            )
          : null,
    );
  }
}
