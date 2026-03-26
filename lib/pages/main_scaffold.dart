import 'dart:async';

import 'package:flutter/material.dart';
import 'home_page.dart';
import 'calendar_page/calendar_page.dart';
import 'materials_page/materials_page.dart';
import 'profile_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../globals.dart';
import '../services/app_session_controller.dart';
import '../services/push_notifications_service.dart';
import '../services/web_push_environment.dart';
import '../widgets/web_push_install_banner.dart';
import 'tools_page/tools_page.dart';
import 'admin_page/admin_panel_page.dart';
import 'calendar_page/widgets/lesson_details_dialog.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key, required this.sessionController});

  final SessionController sessionController;

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;
  Map<String, String> groupNames = {};
  bool _groupsLoaded = false;
  bool _isHandlingPushNavigation = false;

  bool get _hasAdminAccess =>
      !Globals.appRuntimeState.isReadOnlyOffline &&
      Globals.profileManager.currentRole == 'admin';

  // 🚀 Динамічний масив сторінок залежно від ролі
  List<Widget> get _pages {
    final pages = <Widget>[];

    if (_hasAdminAccess) {
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

    if (_hasAdminAccess) {
      items.add(
        const BottomNavigationBarItem(
          icon: Icon(Icons.admin_panel_settings),
          label: 'Адмін-панель',
        ),
      );
    }

    items.addAll([
      const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Головна'),
      const BottomNavigationBarItem(
        icon: Icon(Icons.calendar_month),
        label: 'Календар',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.build),
        label: 'Інструменти',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.article),
        label: 'Матеріали',
      ),
    ]);

    return items;
  }

  // 🎯 Динамічні елементи меню для широких екранів
  List<PopupMenuEntry<String>> get _menuItems {
    final items = <PopupMenuEntry<String>>[];

    if (_hasAdminAccess) {
      items.add(
        const PopupMenuItem(value: 'admin_panel', child: Text('Адмін-панель')),
      );
    }

    items.addAll([
      const PopupMenuItem(value: 'home', child: Text('Головна')),
      const PopupMenuItem(value: 'calendar', child: Text('Календар')),
      const PopupMenuItem(value: 'tools', child: Text('Інструменти')),
      const PopupMenuItem(value: 'materials', child: Text('Матеріали')),
      const PopupMenuItem(value: 'logout', child: Text('Вийти')),
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
    _hydrateCachedGroups();
    Globals.pushNotificationsService.addListener(_handlePushNavigationChanged);
    _hydrateWebPushFromUrl();
    _initGroups();
    unawaited(_initializePushNotifications());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Globals.startupTelemetry.markShellShown();
    });
  }

  @override
  void dispose() {
    Globals.pushNotificationsService.removeListener(
      _handlePushNavigationChanged,
    );
    super.dispose();
  }

  Future<void> _initGroups() async {
    if (groupNames.isNotEmpty) {
      await Globals.profileManager.loadSavedGroupWithFallback(groupNames);
      if (mounted) {
        setState(() => _groupsLoaded = true);
      }
      await _handlePendingPushNavigation();
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    try {
      groupNames = await Globals.firestoreManager.getGroupNamesForUser(
        user.email!,
      );
      await Globals.profileManager.loadSavedGroupWithFallback(groupNames);
    } catch (e) {
      debugPrint('MainScaffold: group refresh failed, using cached groups: $e');
    }

    if (mounted) {
      setState(() => _groupsLoaded = true);
    }

    await _handlePendingPushNavigation();
  }

  void _hydrateCachedGroups() {
    final sessionSnapshot = Globals.appSnapshotStore.getSessionSnapshot();
    if (sessionSnapshot == null || sessionSnapshot.groupNames.isEmpty) {
      return;
    }

    groupNames = Map<String, String>.from(sessionSnapshot.groupNames);
    _groupsLoaded = true;
  }

  Future<void> _initializePushNotifications() async {
    await Globals.pushNotificationsService.initialize();
    await _handlePendingPushNavigation();
  }

  void _handlePushNavigationChanged() {
    unawaited(_handlePendingPushNavigation());
  }

  void _hydrateWebPushFromUrl() {
    final request = PushNavigationRequest.fromUri(Uri.base);
    if (request == null) {
      return;
    }

    Globals.pushNotificationsService.queueNavigationRequest(request);
    WebPushEnvironment.clearPushQueryParameters();
  }

  int get _homeTabIndex => _hasAdminAccess ? 1 : 0;

  Future<void> _handlePendingPushNavigation() async {
    if (!mounted || !_groupsLoaded || _isHandlingPushNavigation) {
      return;
    }

    final request = Globals.pushNotificationsService.pendingNavigationRequest;
    if (request == null) {
      return;
    }

    _isHandlingPushNavigation = true;
    try {
      if (request.groupId != null &&
          request.groupId != Globals.profileManager.currentGroupId) {
        await _switchToNotificationGroup(request.groupId!);
        return;
      }

      Globals.pushNotificationsService.clearPendingNavigationRequest();

      if (request.kind == PushNavigationKind.lesson &&
          request.lessonId != null) {
        await _openLessonFromNotification(request);
        return;
      }

      _openGroupNotification(request);
    } finally {
      _isHandlingPushNavigation = false;
    }
  }

  Future<void> _switchToNotificationGroup(String groupId) async {
    if (groupNames[groupId] == null) {
      final user = FirebaseAuth.instance.currentUser;
      if (user?.email != null) {
        groupNames = await Globals.firestoreManager.getGroupNamesForUser(
          user!.email!,
        );
      }
    }

    final groupName = groupNames[groupId];
    if (groupName == null) {
      Globals.pushNotificationsService.clearPendingNavigationRequest();
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не вдалося відкрити сповіщення для вибраної групи'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    await Globals.profileManager.setCurrentGroup(
      groupId,
      groupName,
      Globals.profileManager.getRoleInGroup(groupId),
    );

    if (!mounted) {
      return;
    }

    await widget.sessionController.revalidate();
  }

  void _openGroupNotification(PushNavigationRequest request) {
    if (!mounted) {
      return;
    }

    setState(() => _currentIndex = _homeTabIndex);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final message = request.body.trim().isNotEmpty
          ? '${request.title}\n${request.body}'
          : request.title;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.blue),
      );
    });
  }

  Future<void> _openLessonFromNotification(
    PushNavigationRequest request,
  ) async {
    if (!mounted || request.lessonId == null) {
      return;
    }

    setState(() => _currentIndex = _homeTabIndex);

    final lesson = await Globals.calendarService.getLessonById(
      request.lessonId!,
      groupId: request.groupId,
    );

    if (!mounted) {
      return;
    }

    if (lesson == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Заняття зі сповіщення не знайдено'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => LessonDetailsDialog(
        lesson: lesson,
        onUpdated: () {
          if (mounted) {
            setState(() {});
          }
        },
      ),
    );
  }

  // 🔄 Оновлена логіка навігації з урахуванням динамічних індексів
  Future<void> _onMenuSelect(String value) async {
    final isAdmin = _hasAdminAccess;
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
        await widget.sessionController.signOut();
        return;
    }

    setState(() => _currentIndex = newIndex);
  }

  void _openHomePage() {
    if (!mounted) return;
    setState(() => _currentIndex = _homeTabIndex);
  }

  // 🛡️ Безпечна валідація поточного індексу
  void _validateCurrentIndex() {
    final maxIndex = _pages.length - 1;
    if (_currentIndex > maxIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _currentIndex = _homeTabIndex;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = isMobileLayout(context);
    final user = FirebaseAuth.instance.currentUser;
    final initials =
        user?.displayName != null && user!.displayName!.contains(' ')
        ? user.displayName!.split(' ').map((e) => e[0]).take(2).join()
        : (Globals.profileManager.currentUserInitials.isNotEmpty
              ? Globals.profileManager.currentUserInitials
              : user?.email?.substring(0, 2).toUpperCase() ?? '?');

    // Перевіряємо валідність поточного індексу
    _validateCurrentIndex();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 8),
            IconButton(
              icon: CircleAvatar(
                radius: 14,
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                child: Text(initials),
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ProfilePage(sessionController: widget.sessionController),
                ),
              ),
            ),
          ],
        ),
        title: _groupsLoaded
            ? Row(
                children: [
                  if (groupNames.length > 1)
                    Row(
                      children: [
                        InkWell(
                          onTap: _openHomePage,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 6,
                            ),
                            child: Text(
                              Globals.profileManager.currentGroupName ??
                                  'Оберіть групу',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (selectedGroupId) async {
                            final groupName = groupNames[selectedGroupId]!;
                            final role = Globals.profileManager.getRoleInGroup(
                              selectedGroupId,
                            );
                            await Globals.profileManager.setCurrentGroup(
                              selectedGroupId,
                              groupName,
                              role,
                            );
                            await widget.sessionController.revalidate();
                          },
                          itemBuilder: (context) =>
                              groupNames.entries.map((entry) {
                                return PopupMenuItem<String>(
                                  value: entry.key,
                                  child: Text(entry.value),
                                );
                              }).toList(),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                          icon: Icon(
                            Icons.keyboard_arrow_down,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    )
                  else
                    InkWell(
                      onTap: _openHomePage,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 6,
                        ),
                        child: Text(
                          Globals.profileManager.currentGroupName ?? '',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                ],
              )
            : const Text('Завантаження...'),
        actions: [
          if (!isMobile)
            PopupMenuButton<String>(
              onSelected: _onMenuSelect,
              itemBuilder: (_) =>
                  _menuItems, // 🎯 Використовуємо динамічне меню
            ),
        ],
      ),
      body: Column(
        children: [
          const WebPushInstallBanner(),
          AnimatedBuilder(
            animation: Globals.appRuntimeState,
            builder: (context, _) {
              if (!Globals.appRuntimeState.isReadOnlyOffline) {
                return const SizedBox.shrink();
              }

              final lastSyncAt = Globals.appRuntimeState.lastSuccessfulSyncAt;
              final subtitle = lastSyncAt == null
                  ? 'Показано останній збережений стан. Дії редагування тимчасово вимкнені.'
                  : 'Показано стан на ${lastSyncAt.day.toString().padLeft(2, '0')}.'
                        '${lastSyncAt.month.toString().padLeft(2, '0')}.'
                        '${lastSyncAt.year} '
                        '${lastSyncAt.hour.toString().padLeft(2, '0')}:'
                        '${lastSyncAt.minute.toString().padLeft(2, '0')}. '
                        'Дії редагування тимчасово вимкнені.';

              return Material(
                color: Colors.amber.shade100,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.cloud_off, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          subtitle,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 12),
                      TextButton(
                        onPressed: () => widget.sessionController.revalidate(),
                        child: const Text('Спробувати онлайн'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          Expanded(
            child: _pages.isNotEmpty && _currentIndex < _pages.length
                ? _pages[_currentIndex]
                : const Center(child: CircularProgressIndicator()),
          ),
        ],
      ), // 🛡️ Захист від помилок
      bottomNavigationBar: isMobile
          ? BottomNavigationBar(
              backgroundColor: Theme.of(
                context,
              ).bottomNavigationBarTheme.backgroundColor,
              selectedItemColor: Theme.of(
                context,
              ).bottomNavigationBarTheme.selectedItemColor,
              unselectedItemColor: Theme.of(
                context,
              ).bottomNavigationBarTheme.unselectedItemColor,
              currentIndex: _currentIndex.clamp(
                0,
                _navigationItems.length - 1,
              ), // 🛡️ Безпечний індекс
              onTap: (index) => setState(() => _currentIndex = index),
              items: _navigationItems, // 🎯 Використовуємо динамічні елементи
              type: BottomNavigationBarType
                  .fixed, // 📱 Для стабільного відображення всіх елементів
            )
          : null,
    );
  }
}
