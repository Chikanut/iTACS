import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../globals.dart';
import 'login_page.dart';
import '../services/profile_manager.dart';

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
      // Синхронізуємо профіль з Firestore якщо потрібно
      if (Globals.profileManager.needsSync()) {
        await Globals.profileManager.loadAndSyncProfile();
      }

      final profile = Globals.profileManager.profile;
      
      // Заповнюємо контролери
      _firstNameController.text = profile.firstName ?? '';
      _lastNameController.text = profile.lastName ?? '';
      _rankController.text = profile.rank ?? '';
      _positionController.text = profile.position ?? '';
      _phoneController.text = profile.phone ?? '';

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
      );

      if (success && mounted) {
        Globals.errorNotificationManager.showSuccess('Профіль збережено!');
        Navigator.pop(context);
      } else if (mounted) {
        Globals.errorNotificationManager.showError('Помилка збереження профілю');
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
      // Показуємо діалог підтвердження
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
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Вийти'),
            ),
          ],
        ),
      );

      if (shouldSignOut == true) {
        // Очищуємо дані профілю
        await Globals.profileManager.clearProfile();
        
        // Виходимо з Firebase
        await FirebaseAuth.instance.signOut();
        
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginPage()),
            (route) => false,
          );
        }
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
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Профіль'),
        actions: [
          // Кнопка оновлення
          IconButton(
            onPressed: _loadProfile,
            icon: const Icon(Icons.refresh),
            tooltip: 'Оновити дані',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок з ініціалами
            _buildProfileHeader(profile),
            
            const SizedBox(height: 24),
            
            // Форма редагування
            _buildEditForm(),
            
            const SizedBox(height: 24),
            
            // Інформація про групи
            _buildGroupsInfo(profile),
            
            const SizedBox(height: 24),
            
            // Кнопки дій
            _buildActionButtons(),
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
            // Аватар з ініціалами
            CircleAvatar(
              radius: 30,
              backgroundColor: Theme.of(context).primaryColor,
              child: Text(
                profile.initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            
            const SizedBox(width: 16),
            
            // Інформація
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
                        color: Colors.grey[600],
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
                        backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
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
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
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
    if (profile.groups.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Навчальні групи',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            ...profile.groups.map((groupId) {
              final role = profile.rolesPerGroup[groupId] ?? 'viewer';
              final isCurrentGroup = groupId == Globals.profileManager.currentGroupId;
              
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isCurrentGroup 
                      ? Theme.of(context).primaryColor.withOpacity(0.1)
                      : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: isCurrentGroup 
                      ? Border.all(color: Theme.of(context).primaryColor)
                      : null,
                ),
                child: Row(
                  children: [
                    if (isCurrentGroup)
                      Icon(
                        Icons.check_circle,
                        color: Theme.of(context).primaryColor,
                        size: 20,
                      ),
                    if (isCurrentGroup) const SizedBox(width: 8),
                    
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            groupId,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: isCurrentGroup ? FontWeight.bold : null,
                            ),
                          ),
                          Text(
                            'Роль: $role',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    if (isCurrentGroup)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Поточна',
                          style: TextStyle(
                            color: Colors.white,
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

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Кнопка збереження
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
        
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 16),
        
        // Кнопка виходу
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _signOut,
            icon: const Icon(Icons.logout),
            label: const Text('Вийти з акаунту'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }
}