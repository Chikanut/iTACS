import 'package:flutter/material.dart';
import '../../globals.dart';
import 'tabs/absences_grid_tab.dart';
import 'tabs/group_members_tab.dart';
import 'tabs/notifications_tab.dart';
import 'tabs/report_templates_tab.dart';
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
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompactMobile = screenWidth < 600;

    // Перевіряємо права адміністратора
    final currentRole = Globals.profileManager.currentRole;
    if (currentRole != 'admin') {
      return Scaffold(
        appBar: AppBar(title: const Text('Адмін-панель')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock, size: 64, color: Colors.grey),
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
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: isCompactMobile ? 56 : null,
        title: Row(
          children: [
            Icon(
              Icons.admin_panel_settings,
              size: isCompactMobile ? 20 : 24,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
            SizedBox(width: isCompactMobile ? 6 : 8),
            Text(
              'Адмін-панель',
              style: TextStyle(fontSize: isCompactMobile ? 22 : null),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        bottom: TabBar(
          controller: _tabController,
          tabAlignment: TabAlignment.fill,
          indicatorColor: Theme.of(context).colorScheme.onPrimary,
          labelColor: Theme.of(context).colorScheme.onPrimary,
          indicatorWeight: isCompactMobile ? 2.5 : 3,
          labelStyle: TextStyle(
            fontSize: isCompactMobile ? 12 : 14,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: TextStyle(
            fontSize: isCompactMobile ? 12 : 14,
            fontWeight: FontWeight.w500,
          ),
          labelPadding: EdgeInsets.symmetric(
            horizontal: isCompactMobile ? 6 : 12,
          ),
          unselectedLabelColor: Theme.of(
            context,
          ).colorScheme.onPrimary.withOpacity(0.7),
          tabs: [
            Tab(
              height: isCompactMobile ? 56 : null,
              iconMargin: EdgeInsets.only(bottom: isCompactMobile ? 4 : 6),
              icon: Icon(Icons.grid_view, size: isCompactMobile ? 20 : 24),
              text: 'Статус',
            ),
            Tab(
              height: isCompactMobile ? 56 : null,
              iconMargin: EdgeInsets.only(bottom: isCompactMobile ? 4 : 6),
              icon: Icon(Icons.group, size: isCompactMobile ? 20 : 24),
              text: 'Учасники',
            ),
            Tab(
              height: isCompactMobile ? 56 : null,
              iconMargin: EdgeInsets.only(bottom: isCompactMobile ? 4 : 6),
              icon: Icon(Icons.campaign, size: isCompactMobile ? 20 : 24),
              text: 'Сповіщення',
            ),
            Tab(
              height: isCompactMobile ? 56 : null,
              iconMargin: EdgeInsets.only(bottom: isCompactMobile ? 4 : 6),
              icon: Icon(Icons.description, size: isCompactMobile ? 20 : 24),
              text: 'Шаблони',
            ),
            Tab(
              height: isCompactMobile ? 56 : null,
              iconMargin: EdgeInsets.only(bottom: isCompactMobile ? 4 : 6),
              icon: Icon(Icons.query_stats, size: isCompactMobile ? 20 : 24),
              text: 'Звіти',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          AbsencesGridTab(),
          GroupMembersTab(),
          NotificationsTab(),
          TemplatesTab(),
          ReportTemplatesTab(),
        ],
      ),
    );
  }
}
