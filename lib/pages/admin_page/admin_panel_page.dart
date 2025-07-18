import 'package:flutter/material.dart';
import '../../globals.dart';
import 'tabs/absences_grid_tab.dart';
import 'tabs/group_members_tab.dart';
import 'tabs/templates_tab.dart';

class AdminPanelPage extends StatefulWidget {
  const AdminPanelPage({super.key});

  @override
  State<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends State<AdminPanelPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Перевіряємо права адміністратора
    final currentRole = Globals.profileManager.currentRole;
    if (currentRole != 'admin') {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Адмін-панель'),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock,
                size: 64,
                color: Colors.grey,
              ),
              SizedBox(height: 16),
              Text(
                'Недостатньо прав',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Тільки адміністратори мають доступ до цієї сторінки',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.admin_panel_settings, 
                 color: Theme.of(context).colorScheme.onPrimary),
            const SizedBox(width: 8),
            const Text('Адмін-панель'),
          ],
        ),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Theme.of(context).colorScheme.onPrimary,
          labelColor: Theme.of(context).colorScheme.onPrimary,
          unselectedLabelColor: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
          tabs: const [
            Tab(
              icon: Icon(Icons.grid_view),
              text: 'Відсутності',
            ),
            Tab(
              icon: Icon(Icons.group),
              text: 'Учасники',
            ),
            Tab(
              icon: Icon(Icons.description),
              text: 'Шаблони',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          AbsencesGridTab(),
          GroupMembersTab(),
          TemplatesTab(),
        ],
      ),
    );
  }
}