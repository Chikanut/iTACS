import 'package:flutter/material.dart';
import 'home_page.dart';
import 'calendar_page/calendar_page.dart';
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

  // 🚀 Динамічний масив сторінок залежно від ролі
  List<Widget> get _pages {
    final pages = <Widget>[];
    
    if (Globals.profileManager.currentRole == 'admin') {
      pages.add(const AdminPanelPage());
    }
    
    pages.addAll([
      const HomePage(),
      const CalendarPage(),
      const ToolsPage(),
      const MaterialsPage(),
    ]);
    
    return pages;
  }

  // 🎯 Динамічні елементи навігації для мобільних
  List<BottomNavigationBarItem> get _navigationItems {
    final items = <BottomNavigationBarItem>[];
    
    if (Globals.profileManager.currentRole == 'admin') {
      items.add(const BottomNavigationBarItem(
        icon: Icon(Icons.admin_panel_settings), 
        label: 'Адмін-панель'
      ));
    }
    
    items.addAll([
      const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Головна'),
      const BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: 'Календар'),
      const BottomNavigationBarItem(icon: Icon(Icons.build), label: 'Інструменти'),
      const BottomNavigationBarItem(icon: Icon(Icons.article), label: 'Матеріали'),
    ]);
    
    return items;
  }

  // 🎯 Динамічні елементи меню для широких екранів
  List<PopupMenuEntry<String>> get _menuItems {
    final items = <PopupMenuEntry<String>>[];
    
    if (Globals.profileManager.currentRole == 'admin') {
      items.add(const PopupMenuItem(
        value: 'admin_panel', 
        child: Text('Адмін-панель')
      ));
    }
    
    items.addAll([
      const PopupMenuItem(value: 'home', child: Text('Головна')),
      const PopupMenuItem(value: 'calendar', child: Text('Календар')),
      const PopupMenuItem(value: 'tools', child: Text('Інструменти')),
      const PopupMenuItem(value: 'materials', child: Text('Матеріали')),
    ]);
    
    return items;
  }

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

  // 🔄 Оновлена логіка навігації з урахуванням динамічних індексів
  void _onMenuSelect(String value) {
    final isAdmin = Globals.profileManager.currentRole == 'admin';
    int newIndex = 0;
    
    switch (value) {
      case 'admin_panel':
        newIndex = 0; // Завжди перший, якщо є
        break;
      case 'home':
        newIndex = isAdmin ? 1 : 0; // Залежно від наявності адмін панелі
        break;
      case 'calendar':
        newIndex = isAdmin ? 2 : 1;
        break;
      case 'tools':
        newIndex = isAdmin ? 3 : 2;
        break;
      case 'materials':
        newIndex = isAdmin ? 4 : 3;
        break;
      case 'logout':
        FirebaseAuth.instance.signOut();
        return;
    }
    
    setState(() => _currentIndex = newIndex);
  }

  // 🛡️ Безпечна валідація поточного індексу
  void _validateCurrentIndex() {
    final maxIndex = _pages.length - 1;
    if (_currentIndex > maxIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _currentIndex = Globals.profileManager.currentRole == 'admin' ? 1 : 0; // HomePage
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = isMobileLayout(context);
    final user = FirebaseAuth.instance.currentUser;
    final initials = user?.displayName != null && user!.displayName!.contains(' ')
        ? user.displayName!.split(' ').map((e) => e[0]).take(2).join()
        : user?.email?.substring(0, 2).toUpperCase() ?? '?';

    // Перевіряємо валідність поточного індексу
    _validateCurrentIndex();

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
              itemBuilder: (_) => _menuItems, // 🎯 Використовуємо динамічне меню
            ),
        ],
      ),
      body: _pages.isNotEmpty && _currentIndex < _pages.length 
          ? _pages[_currentIndex] 
          : const Center(child: CircularProgressIndicator()), // 🛡️ Захист від помилок
      bottomNavigationBar: isMobile
          ? BottomNavigationBar(
              backgroundColor: Colors.white,
              selectedItemColor: Colors.blue,
              unselectedItemColor: Colors.grey,
              currentIndex: _currentIndex.clamp(0, _navigationItems.length - 1), // 🛡️ Безпечний індекс
              onTap: (index) => setState(() => _currentIndex = index),
              items: _navigationItems, // 🎯 Використовуємо динамічні елементи
              type: BottomNavigationBarType.fixed, // 📱 Для стабільного відображення всіх елементів
            )
          : null,
    );
  }
}