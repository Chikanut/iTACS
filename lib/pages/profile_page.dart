import 'package:flutter/material.dart';

import '../globals.dart';
import '../models/notification_preferences.dart';
import '../services/app_session_controller.dart';
import '../services/profile_manager.dart';
import '../theme/app_theme.dart';
import 'profile_full_info_tab.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.sessionController});

  final SessionController sessionController;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _rankController = TextEditingController();
  final TextEditingController _positionController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  NotificationPreferences _notificationPreferences =
      NotificationPreferences.defaults;

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _rankController.dispose();
    _positionController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);

    try {
      if (Globals.profileManager.needsSync()) {
        await Globals.profileManager.loadAndSyncProfile();
      }

      final profile = Globals.profileManager.profile;

      _firstNameController.text = profile.firstName ?? '';
      _lastNameController.text = profile.lastName ?? '';
      _rankController.text = profile.rank ?? '';
      _positionController.text = profile.position ?? '';
      _phoneController.text = profile.phone ?? '';
      _notificationPreferences = profile.notificationPreferences;
    } catch (e) {
      if (mounted) {
        Globals.errorNotificationManager.showError(
          'Помилка завантаження профілю: ${e.toString()}',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);

    try {
      final success = await Globals.profileManager.updatePersonalInfo(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        rank: _rankController.text.trim(),
        position: _positionController.text.trim(),
        phone: _phoneController.text.trim(),
        notificationPreferences: _notificationPreferences,
      );

      if (success && mounted) {
        Globals.errorNotificationManager.showSuccess('Профіль збережено!');
        Navigator.pop(context);
      } else if (mounted) {
        Globals.errorNotificationManager.showError(
          'Помилка збереження профілю',
        );
      }
    } catch (e) {
      if (mounted) {
        Globals.errorNotificationManager.showError(
          'Помилка збереження: ${e.toString()}',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _signOut() async {
    try {
      final shouldSignOut = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Вихід з акаунту'),
          content: const Text('Ви впевнені, що хочете вийти з акаунту?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Скасувати'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.dangerStatus.border,
              ),
              child: const Text('Вийти'),
            ),
          ],
        ),
      );

      if (shouldSignOut == true) {
        await widget.sessionController.signOut();
        if (!mounted) return;
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        Globals.errorNotificationManager.showError(
          'Помилка виходу: ${e.toString()}',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Профіль')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final profile = Globals.profileManager.profile;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Профіль'),
          actions: [
            IconButton(
              onPressed: _loadProfile,
              icon: const Icon(Icons.refresh),
              tooltip: 'Оновити дані',
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Загальна інформація'),
              Tab(text: 'Повна інформація'),
              Tab(text: 'Налаштування'),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _buildProfileHeader(profile),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildEditForm(),
                        const SizedBox(height: 24),
                        _buildGroupsInfo(profile),
                      ],
                    ),
                  ),
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: const PersonnelFullInfoTab(),
                  ),
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: _buildNotificationSettings(),
                  ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: _buildActionButtons(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(UserProfile profile) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Text(
                profile.initials,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.fullName,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (profile.email != null)
                    Text(
                      profile.email!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  if (Globals.profileManager.currentGroupName != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Chip(
                        label: Text(
                          Globals.profileManager.currentGroupName!,
                          style: const TextStyle(fontSize: 12),
                        ),
                        backgroundColor: AppTheme.infoStatus.background,
                        side: BorderSide(color: AppTheme.infoStatus.border),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Особиста інформація',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _firstNameController,
              decoration: const InputDecoration(
                labelText: 'Імʼя',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _lastNameController,
              decoration: const InputDecoration(
                labelText: 'Прізвище',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _rankController,
              decoration: const InputDecoration(
                labelText: 'Звання',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.military_tech),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _positionController,
              decoration: const InputDecoration(
                labelText: 'Посада',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.work),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Телефон',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupsInfo(UserProfile profile) {
    if (profile.groups.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Навчальні групи',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...profile.groups.map((groupId) {
              final role = profile.rolesPerGroup[groupId] ?? 'viewer';
              final isCurrentGroup =
                  groupId == Globals.profileManager.currentGroupId;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isCurrentGroup
                      ? AppTheme.infoStatus.background
                      : AppTheme.neutralStatus.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isCurrentGroup
                        ? AppTheme.infoStatus.border
                        : AppTheme.neutralStatus.border,
                  ),
                ),
                child: Row(
                  children: [
                    if (isCurrentGroup)
                      Icon(
                        Icons.check_circle,
                        color: AppTheme.infoStatus.border,
                        size: 20,
                      ),
                    if (isCurrentGroup) const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            groupId,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  fontWeight: isCurrentGroup
                                      ? FontWeight.bold
                                      : null,
                                ),
                          ),
                          Text(
                            'Роль: $role',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    if (isCurrentGroup)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.infoStatus.border,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Поточна',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Push-сповіщення',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Тут можна керувати тим, які push-сповіщення приходять для вашого акаунта.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                ...NotificationPreferences.generalDefinitions.map(
                  _buildPreferenceTile,
                ),
                if (Globals.profileManager.isCurrentGroupAdmin) ...[
                  const SizedBox(height: 20),
                  Text(
                    'Admin push',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...NotificationPreferences.adminDefinitions.map(
                    _buildPreferenceTile,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Системний дозвіл на push у браузері або на пристрої керується окремо від цих тоглів. Тут налаштовується лише логіка застосунку.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreferenceTile(NotificationPreferenceDefinition definition) {
    return SwitchListTile.adaptive(
      value: _notificationPreferences.valueForKey(definition.key),
      contentPadding: EdgeInsets.zero,
      title: Text(definition.title),
      subtitle: Text(definition.description),
      onChanged: (value) {
        setState(() {
          _notificationPreferences = _updatedPreferencesForKey(
            key: definition.key,
            value: value,
          );
        });
      },
    );
  }

  NotificationPreferences _updatedPreferencesForKey({
    required String key,
    required bool value,
  }) {
    switch (key) {
      case NotificationPreferences.groupAnnouncementsKey:
        return _notificationPreferences.copyWith(groupAnnouncements: value);
      case NotificationPreferences.lessonAssignedKey:
        return _notificationPreferences.copyWith(lessonAssigned: value);
      case NotificationPreferences.lessonRemovedKey:
        return _notificationPreferences.copyWith(lessonRemoved: value);
      case NotificationPreferences.lessonCriticalChangedKey:
        return _notificationPreferences.copyWith(lessonCriticalChanged: value);
      case NotificationPreferences.absenceRequestResultKey:
        return _notificationPreferences.copyWith(absenceRequestResult: value);
      case NotificationPreferences.lessonProgressReminderKey:
        return _notificationPreferences.copyWith(lessonProgressReminder: value);
      case NotificationPreferences.adminAbsenceAssignmentKey:
        return _notificationPreferences.copyWith(adminAbsenceAssignment: value);
      case NotificationPreferences.adminLessonAcknowledgedKey:
        return _notificationPreferences.copyWith(
          adminLessonAcknowledged: value,
        );
      default:
        return _notificationPreferences;
    }
  }

  Widget _buildActionButtons() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isSaving ? null : _saveProfile,
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: Text(_isSaving ? 'Збереження...' : 'Зберегти'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _signOut,
            icon: const Icon(Icons.logout),
            label: const Text('Вийти з акаунту'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.dangerStatus.border,
              foregroundColor: AppTheme.dangerStatus.foreground,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }
}
