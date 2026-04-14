import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../globals.dart';
import '../../../services/contacts_tool_service.dart';
import '../../../theme/app_theme.dart';

bool get _isMobile {
  if (kIsWeb) return false;
  return Platform.isAndroid || Platform.isIOS;
}

class ContactsToolPage extends StatefulWidget {
  const ContactsToolPage({super.key});

  @override
  State<ContactsToolPage> createState() => _ContactsToolPageState();
}

class _ContactsToolPageState extends State<ContactsToolPage> {
  final _service = ContactsToolService();
  final _searchController = TextEditingController();
  String _searchQuery = '';
  final Map<String, bool> _expandedState = {};

  String? get _groupId => Globals.profileManager.currentGroupId;

  bool get _canEdit {
    final role = Globals.profileManager.currentRole;
    return !Globals.appRuntimeState.isReadOnlyOffline &&
        (role == 'editor' || role == 'admin');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ─── Phone actions ───────────────────────────────────────────────────────

  Future<void> _copyPhone(String phone) async {
    await Clipboard.setData(ClipboardData(text: phone));
    if (mounted) {
      Globals.errorNotificationManager.showSuccess('📋 Номер скопійовано');
    }
  }

  Future<void> _openSignal(String phone) async {
    String clean = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (clean.startsWith('0')) clean = '38$clean';
    final url = Uri.parse('https://signal.me/#p/+$clean');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _makeCall(String phone) async {
    final url = Uri.parse('tel:$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  // ─── Filtering ───────────────────────────────────────────────────────────

  List<DepartmentEntry> _filter(List<DepartmentEntry> departments) {
    if (_searchQuery.isEmpty) return departments;
    final q = _searchQuery.toLowerCase();
    return departments
        .map((dept) {
          final deptMatches = dept.name.toLowerCase().contains(q);
          final matchedContacts = dept.contacts.where((c) {
            return c.name.toLowerCase().contains(q) ||
                c.unit.toLowerCase().contains(q) ||
                c.rank.toLowerCase().contains(q) ||
                c.phone.contains(q) ||
                deptMatches;
          }).toList();
          if (deptMatches || matchedContacts.isNotEmpty) {
            return dept.copyWith(
              contacts: deptMatches ? dept.contacts : matchedContacts,
            );
          }
          return null;
        })
        .whereType<DepartmentEntry>()
        .toList();
  }

  // ─── Dialogs ─────────────────────────────────────────────────────────────

  Future<void> _showAddDepartmentDialog() async {
    final nameCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Новий підрозділ'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Назва підрозділу',
            hintText: 'напр. 1 НАВЧАЛЬНИЙ БАТАЛЬЙОН',
          ),
          textCapitalization: TextCapitalization.characters,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Скасувати'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Додати'),
          ),
        ],
      ),
    );
    if (confirmed == true && nameCtrl.text.trim().isNotEmpty) {
      await _service.addDepartment(_groupId!, nameCtrl.text.trim());
    }
  }

  Future<void> _showEditDepartmentDialog(DepartmentEntry dept) async {
    final nameCtrl = TextEditingController(text: dept.name);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Редагувати підрозділ'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Назва підрозділу'),
          textCapitalization: TextCapitalization.characters,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Скасувати'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Зберегти'),
          ),
        ],
      ),
    );
    if (confirmed == true && nameCtrl.text.trim().isNotEmpty) {
      await _service.updateDepartmentName(
        _groupId!,
        dept.id,
        nameCtrl.text.trim(),
      );
    }
  }

  Future<void> _confirmDeleteDepartment(DepartmentEntry dept) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Видалити підрозділ?'),
          ],
        ),
        content: Text(
          'Підрозділ "${dept.name}" та всі ${dept.contacts.length} контактів буде видалено.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Скасувати'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Видалити'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _service.deleteDepartment(_groupId!, dept.id);
    }
  }

  Future<void> _showContactDialog({
    required DepartmentEntry dept,
    ContactEntry? existing,
    int? existingIndex,
  }) async {
    final unitCtrl = TextEditingController(text: existing?.unit ?? '');
    final rankCtrl = TextEditingController(text: existing?.rank ?? '');
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Новий контакт' : 'Редагувати контакт'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: unitCtrl,
                  decoration: const InputDecoration(labelText: 'Підрозділ *'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Обовʼязкове поле'
                      : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: rankCtrl,
                  decoration: const InputDecoration(labelText: 'Звання'),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'ПІБ'),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(labelText: 'Телефон'),
                  keyboardType: TextInputType.phone,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Скасувати'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Зберегти'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final newContact = ContactEntry(
        unit: unitCtrl.text.trim(),
        rank: rankCtrl.text.trim(),
        name: nameCtrl.text.trim(),
        phone: phoneCtrl.text.trim(),
      );
      final updated = List<ContactEntry>.from(dept.contacts);
      if (existingIndex != null) {
        updated[existingIndex] = newContact;
      } else {
        updated.add(newContact);
      }
      await _service.updateContacts(_groupId!, dept.id, updated);
    }
  }

  Future<void> _deleteContact(DepartmentEntry dept, int index) async {
    final contact = dept.contacts[index];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Видалити контакт?'),
        content: Text(
          contact.name.isNotEmpty
              ? '"${contact.name}" (${contact.unit})'
              : contact.unit,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Скасувати'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Видалити'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final updated = List<ContactEntry>.from(dept.contacts)..removeAt(index);
      await _service.updateContacts(_groupId!, dept.id, updated);
    }
  }

  // ─── UI Builders ─────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Пошук за іменем, підрозділом або номером...',
          hintStyle: TextStyle(color: AppTheme.textMuted),
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: AppTheme.surfaceRaised,
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      _searchQuery = '';
                      _searchController.clear();
                    });
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25),
            borderSide: BorderSide(color: AppTheme.borderSubtle),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25),
            borderSide: BorderSide(color: AppTheme.borderSubtle),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25),
            borderSide: BorderSide(
              color: AppTheme.infoStatus.border,
              width: 1.5,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 10,
          ),
        ),
        onChanged: (v) => setState(() => _searchQuery = v.trim()),
      ),
    );
  }

  Widget _buildStats(List<DepartmentEntry> filtered, int totalContacts) {
    final deptCount = filtered.length;
    final contactCount = filtered.fold<int>(
      0,
      (sum, d) => sum + d.contacts.length,
    );

    String text;
    if (_searchQuery.isNotEmpty) {
      text =
          'Знайдено: $deptCount ${_deptWord(deptCount)} • $contactCount ${_contactWord(contactCount)}';
    } else {
      text =
          'Всього: $deptCount ${_deptWord(deptCount)} • $totalContacts ${_contactWord(totalContacts)}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Text(
        text,
        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
      ),
    );
  }

  Widget _buildContactCard(
    BuildContext context,
    ContactEntry contact,
    DepartmentEntry dept,
    int index,
  ) {
    final hasPhone = contact.phone.isNotEmpty;

    return Card(
      color: AppTheme.surfaceRaised,
      elevation: 1,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: AppTheme.borderSubtle.withOpacity(0.45)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 6, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header: unit badge + rank badge + menu
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 2,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.infoStatus.background,
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                            color: AppTheme.infoStatus.border.withOpacity(0.7),
                          ),
                        ),
                        child: Text(
                          contact.unit,
                          style: TextStyle(
                            color: AppTheme.infoStatus.badge,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (contact.rank.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.accentStatus.background,
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                              color: AppTheme.accentStatus.border.withOpacity(
                                0.7,
                              ),
                            ),
                          ),
                          child: Text(
                            contact.rank,
                            style: TextStyle(
                              color: AppTheme.accentStatus.badge,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (_canEdit)
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: PopupMenuButton<String>(
                      iconSize: 14,
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        Icons.more_vert,
                        size: 14,
                        color: AppTheme.textSecondary,
                      ),
                      onSelected: (val) async {
                        if (val == 'edit') {
                          await _showContactDialog(
                            dept: dept,
                            existing: contact,
                            existingIndex: index,
                          );
                        } else if (val == 'delete') {
                          await _deleteContact(dept, index);
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: ListTile(
                            leading: Icon(Icons.edit, size: 16),
                            title: Text('Редагувати'),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                          value: 'delete',
                          child: ListTile(
                            leading: Icon(
                              Icons.delete,
                              size: 16,
                              color: Colors.red,
                            ),
                            title: Text('Видалити'),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            // Name
            if (contact.name.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                contact.name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
            // Phone block
            if (hasPhone) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceOverlay,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AppTheme.borderSubtle.withOpacity(0.65),
                  ),
                ),
                child: Text(
                  contact.phone,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  Expanded(
                    child: _actionButton(
                      label: 'Копіювати',
                      icon: '📋',
                      color: AppTheme.successStatus.border,
                      onTap: () => _copyPhone(contact.phone),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _actionButton(
                      label: 'Signal',
                      icon: '💬',
                      color: AppTheme.infoStatus.border,
                      onTap: () => _openSignal(contact.phone),
                    ),
                  ),
                  if (_isMobile) ...[
                    const SizedBox(width: 4),
                    Expanded(
                      child: _actionButton(
                        label: 'Дзвінок',
                        icon: '📞',
                        color: AppTheme.warningStatus.border,
                        onTap: () => _makeCall(contact.phone),
                      ),
                    ),
                  ],
                ],
              ),
            ] else ...[
              const SizedBox(height: 4),
              Text(
                'Телефон не вказано',
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontStyle: FontStyle.italic,
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required String icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(icon, style: const TextStyle(fontSize: 11)),
              const SizedBox(width: 3),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDepartmentSection(DepartmentEntry dept) {
    final isExpanded = _expandedState[dept.id] ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Department header (collapsible)
        GestureDetector(
          onTap: () => setState(() => _expandedState[dept.id] = !isExpanded),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryBlue.shade600,
                  AppTheme.primaryBlue.shade700,
                ],
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.infoStatus.border.withOpacity(0.22),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                const Text('🏛️ ', style: TextStyle(fontSize: 16)),
                Expanded(
                  child: Text(
                    dept.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (_canEdit)
                  PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.more_vert,
                      color: Colors.white,
                      size: 18,
                    ),
                    onSelected: (val) async {
                      switch (val) {
                        case 'edit':
                          await _showEditDepartmentDialog(dept);
                          break;
                        case 'add_contact':
                          await _showContactDialog(dept: dept);
                          break;
                        case 'delete':
                          await _confirmDeleteDepartment(dept);
                          break;
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit, size: 16),
                          title: Text('Змінити назву'),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'add_contact',
                        child: ListTile(
                          leading: Icon(Icons.person_add, size: 16),
                          title: Text('Додати контакт'),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(
                            Icons.delete,
                            size: 16,
                            color: Colors.red,
                          ),
                          title: Text('Видалити підрозділ'),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                AnimatedRotation(
                  turns: isExpanded ? 0 : -0.25,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                    Icons.expand_more,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Contacts grid
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: _buildContactsGrid(dept),
          crossFadeState: isExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 250),
        ),
      ],
    );
  }

  Widget _buildContactsGrid(DepartmentEntry dept) {
    if (dept.contacts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Row(
          children: [
            Text(
              'Контакти відсутні',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
            ),
            if (_canEdit) ...[
              const SizedBox(width: 12),
              TextButton.icon(
                onPressed: () => _showContactDialog(dept: dept),
                icon: const Icon(Icons.add, size: 14),
                label: const Text('Додати', style: TextStyle(fontSize: 13)),
              ),
            ],
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          final isWide = constraints.maxWidth > 600;
          if (!isWide) {
            // Single column — cards have natural (variable) height
            return Column(
              children: dept.contacts.asMap().entries.map((e) {
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: e.key < dept.contacts.length - 1 ? 8 : 0,
                  ),
                  child: _buildContactCard(ctx, e.value, dept, e.key),
                );
              }).toList(),
            );
          }
          // Two columns via Wrap — each card wraps to its natural height
          final cardWidth = (constraints.maxWidth - 10) / 2;
          return Wrap(
            spacing: 10,
            runSpacing: 8,
            children: dept.contacts.asMap().entries.map((e) {
              return SizedBox(
                width: cardWidth,
                child: _buildContactCard(ctx, e.value, dept, e.key),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupId = _groupId;
    if (groupId == null) {
      return const Scaffold(body: Center(child: Text('Групу не знайдено')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [Text('📞 '), Text('Корисні контакти')]),
        actions: [
          if (_canEdit)
            IconButton(
              icon: const Icon(Icons.add_business),
              tooltip: 'Додати підрозділ',
              onPressed: _showAddDepartmentDialog,
            ),
        ],
      ),
      body: StreamBuilder<List<DepartmentEntry>>(
        stream: _service.watchDepartments(groupId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Помилка: ${snapshot.error}'),
                ],
              ),
            );
          }

          final all = snapshot.data ?? [];
          final totalContacts = all.fold<int>(
            0,
            (s, d) => s + d.contacts.length,
          );
          final filtered = _filter(all);

          return Column(
            children: [
              _buildSearchBar(),
              _buildStats(filtered, totalContacts),
              Expanded(
                child: filtered.isEmpty
                    ? _buildEmptyState(all.isEmpty)
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (ctx, i) =>
                            _buildDepartmentSection(filtered[i]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(bool noData) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            noData ? Icons.contacts : Icons.search_off,
            size: 64,
            color: AppTheme.textMuted.withOpacity(0.7),
          ),
          const SizedBox(height: 16),
          Text(
            noData ? 'Контакти відсутні' : 'Нічого не знайдено',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            noData
                ? (_canEdit
                      ? 'Натисніть + щоб додати підрозділ'
                      : 'Контакти ще не додані')
                : 'Спробуйте змінити пошуковий запит',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }

  // ─── Pluralization helpers ────────────────────────────────────────────────

  String _deptWord(int n) {
    if (n == 1) return 'підрозділ';
    if (n >= 2 && n <= 4) return 'підрозділи';
    return 'підрозділів';
  }

  String _contactWord(int n) {
    if (n == 1) return 'контакт';
    if (n >= 2 && n <= 4) return 'контакти';
    return 'контактів';
  }
}
