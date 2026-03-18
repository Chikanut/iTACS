import 'package:flutter/material.dart';

import '../../../globals.dart';
import '../../../theme/app_theme.dart';

class GroupMembersTab extends StatefulWidget {
  const GroupMembersTab({super.key});

  @override
  State<GroupMembersTab> createState() => _GroupMembersTabState();
}

class _GroupMembersTabState extends State<GroupMembersTab> {
  static const Map<String, String> _roleLabels = {
    'viewer': 'Перегляд',
    'editor': 'Редактор',
    'admin': 'Адмін',
  };

  List<Map<String, dynamic>> _members = [];
  bool _isLoading = true;
  bool _isCreatingMember = false;
  final Set<String> _updatingEmails = <String>{};

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    final currentGroupId = Globals.profileManager.currentGroupId;
    if (currentGroupId == null) {
      if (mounted) {
        setState(() {
          _members = [];
          _isLoading = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() => _isLoading = true);
    }

    final members = await Globals.firestoreManager.getGroupMembersWithDetails(
      currentGroupId,
    );

    if (!mounted) return;
    setState(() {
      _members = members;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentGroupName =
        Globals.profileManager.currentGroupName ?? 'Поточна група';

    if (Globals.profileManager.currentGroupId == null) {
      return const Center(child: Text('Спочатку оберіть групу'));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _InfoCard(
                icon: Icons.groups_2,
                title: 'Учасники',
                value: '${_members.length}',
                subtitle: currentGroupName,
              ),
              FilledButton.icon(
                onPressed: _isCreatingMember ? null : _showAddMemberDialog,
                icon: _isCreatingMember
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.person_add),
                label: const Text('Додати людину'),
              ),
              IconButton(
                tooltip: 'Оновити',
                onPressed: _isLoading ? null : _loadMembers,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _members.isEmpty
              ? const _EmptyState()
              : RefreshIndicator(
                  onRefresh: _loadMembers,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: _members.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final member = _members[index];
                      return _buildMemberCard(member);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildMemberCard(Map<String, dynamic> member) {
    final fullName = (member['fullName'] as String?)?.trim();
    final email = ((member['email'] as String?) ?? '').trim();
    final role = ((member['role'] as String?) ?? 'viewer').toLowerCase();
    final rank = ((member['rank'] as String?) ?? '').trim();
    final position = ((member['position'] as String?) ?? '').trim();
    final isCurrentUser = _isCurrentUser(email);
    final isUpdating = _updatingEmails.contains(email);
    final subtitleParts = <String>[
      if (rank.isNotEmpty) rank,
      if (position.isNotEmpty) position,
      email,
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(child: Text(_buildInitials(fullName, email))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            fullName?.isNotEmpty == true ? fullName! : email,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (isCurrentUser)
                            Chip(
                              label: const Text('Ви'),
                              backgroundColor: AppTheme.infoStatus.background,
                              side: BorderSide(
                                color: AppTheme.infoStatus.border,
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitleParts.join(' • '),
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _roleLabels.containsKey(role) ? role : 'viewer',
                    decoration: const InputDecoration(
                      labelText: 'Роль у групі',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: _roleLabels.entries
                        .map(
                          (entry) => DropdownMenuItem<String>(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                        )
                        .toList(),
                    onChanged: isUpdating || isCurrentUser
                        ? null
                        : (value) {
                            if (value != null && value != role) {
                              _updateRole(email, value);
                            }
                          },
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: isUpdating || isCurrentUser
                        ? null
                        : () => _confirmRemoveMember(member),
                    icon: isUpdating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.delete_outline),
                    label: const Text('Видалити'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.dangerStatus.border,
                      side: BorderSide(
                        color: AppTheme.dangerStatus.border.withOpacity(0.7),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (isCurrentUser) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Власний доступ змінюється поза цією вкладкою, щоб не втратити адмін-права випадково.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showAddMemberDialog() async {
    final formKey = GlobalKey<FormState>();
    final emailController = TextEditingController();
    String selectedRole = 'viewer';

    final shouldSubmit = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Додати людину до групи'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        hintText: 'name@example.com',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        final email = value?.trim() ?? '';
                        final emailRegex = RegExp(
                          r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                        );
                        if (email.isEmpty) {
                          return 'Вкажіть email';
                        }
                        if (!emailRegex.hasMatch(email)) {
                          return 'Некоректний email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedRole,
                      decoration: const InputDecoration(
                        labelText: 'Роль',
                        border: OutlineInputBorder(),
                      ),
                      items: _roleLabels.entries
                          .map(
                            (entry) => DropdownMenuItem<String>(
                              value: entry.key,
                              child: Text(entry.value),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setStateDialog(() => selectedRole = value);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Скасувати'),
                ),
                FilledButton(
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      Navigator.of(context).pop(true);
                    }
                  },
                  child: const Text('Додати'),
                ),
              ],
            );
          },
        );
      },
    );

    if (shouldSubmit != true || !mounted) {
      emailController.dispose();
      return;
    }

    final currentGroupId = Globals.profileManager.currentGroupId;
    if (currentGroupId == null) {
      emailController.dispose();
      return;
    }

    setState(() => _isCreatingMember = true);
    try {
      await Globals.firestoreManager.addOrUpdateGroupMember(
        groupId: currentGroupId,
        email: emailController.text.trim(),
        role: selectedRole,
      );
      await _loadMembers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Людину додано до групи'),
          backgroundColor: AppTheme.successStatus.border,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Не вдалося додати людину: $e'),
          backgroundColor: AppTheme.dangerStatus.border,
        ),
      );
    } finally {
      emailController.dispose();
      if (mounted) {
        setState(() => _isCreatingMember = false);
      }
    }
  }

  Future<void> _updateRole(String email, String role) async {
    final currentGroupId = Globals.profileManager.currentGroupId;
    if (currentGroupId == null) return;

    setState(() => _updatingEmails.add(email));
    try {
      await Globals.firestoreManager.updateGroupMemberRole(
        groupId: currentGroupId,
        email: email,
        role: role,
      );
      await _loadMembers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Роль оновлено'),
          backgroundColor: AppTheme.successStatus.border,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Не вдалося оновити роль: $e'),
          backgroundColor: AppTheme.dangerStatus.border,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _updatingEmails.remove(email));
      }
    }
  }

  Future<void> _confirmRemoveMember(Map<String, dynamic> member) async {
    final email = ((member['email'] as String?) ?? '').trim();
    final fullName =
        ((member['fullName'] as String?) ?? '').trim().isNotEmpty == true
        ? (member['fullName'] as String).trim()
        : email;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Видалити людину з групи?'),
        content: Text(
          'Користувач $fullName втратить доступ до поточної групи.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Скасувати'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.dangerStatus.border,
            ),
            child: const Text('Видалити'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final currentGroupId = Globals.profileManager.currentGroupId;
    if (currentGroupId == null) return;

    setState(() => _updatingEmails.add(email));
    try {
      await Globals.firestoreManager.removeGroupMember(
        groupId: currentGroupId,
        email: email,
      );
      await _loadMembers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Людину видалено з групи'),
          backgroundColor: AppTheme.successStatus.border,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Не вдалося видалити людину: $e'),
          backgroundColor: AppTheme.dangerStatus.border,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _updatingEmails.remove(email));
      }
    }
  }

  bool _isCurrentUser(String email) {
    final currentEmail = Globals.profileManager.currentUserEmail
        ?.trim()
        .toLowerCase();
    return currentEmail != null && currentEmail == email.toLowerCase();
  }

  String _buildInitials(String? fullName, String email) {
    final name = (fullName ?? '').trim();
    if (name.isNotEmpty) {
      final parts = name.split(RegExp(r'\s+')).where((part) => part.isNotEmpty);
      final initials = parts
          .take(2)
          .map((part) => part[0].toUpperCase())
          .join();
      if (initials.isNotEmpty) {
        return initials;
      }
    }
    return email.isNotEmpty ? email[0].toUpperCase() : '?';
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceRaised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppTheme.infoStatus.border),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.group_off, size: 64, color: AppTheme.textMuted),
            const SizedBox(height: 16),
            const Text(
              'У групі поки немає учасників',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Додайте першу людину через кнопку вище.',
              style: TextStyle(color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
