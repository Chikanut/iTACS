import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../globals.dart';
import '../../../../mixins/loading_state_mixin.dart';
import '../../../../models/material_journal/material_journal.dart';
import '../../../../services/material_journal_service.dart';
import '../../../../widgets/loading_indicator.dart';
import 'dialogs/journal_dialog.dart';
import 'material_journal_page.dart';

class MaterialJournalsHomePage extends StatefulWidget {
  const MaterialJournalsHomePage({super.key});

  @override
  State<MaterialJournalsHomePage> createState() =>
      _MaterialJournalsHomePageState();
}

class _MaterialJournalsHomePageState extends State<MaterialJournalsHomePage>
    with LoadingStateMixin {
  final _service = MaterialJournalService();
  List<MaterialJournal> _journals = [];

  bool get _canManage =>
      !Globals.appRuntimeState.isReadOnlyOffline &&
      Globals.profileManager.currentRole != 'viewer';

  bool get _isAdmin =>
      !Globals.appRuntimeState.isReadOnlyOffline &&
      Globals.profileManager.currentRole == 'admin';

  @override
  void initState() {
    super.initState();
    unawaited(_fetch());
  }

  Future<void> _fetch() async {
    await withLoading('fetch', () async {
      final groupId = Globals.profileManager.currentGroupId;
      if (groupId == null) return;
      final journals = await _service.getJournals(groupId);
      if (mounted) setState(() => _journals = journals);
    });
  }

  Future<void> _showCreateDialog() async {
    await showDialog<void>(
      context: context,
      builder: (_) => JournalDialog(onSaved: _fetch),
    );
  }

  Future<void> _showEditDialog(MaterialJournal journal) async {
    await showDialog<void>(
      context: context,
      builder: (_) => JournalDialog(
        journalId: journal.id,
        initialName: journal.name,
        initialDescription: journal.description,
        onSaved: _fetch,
      ),
    );
  }

  Future<void> _deleteJournal(MaterialJournal journal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Видалити журнал?'),
        content: Text(
          'Журнал "${journal.name}" та вся матбаза в ньому будуть видалені. Цю дію не можна скасувати.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Скасувати'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Видалити'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final groupId = Globals.profileManager.currentGroupId;
    if (groupId == null) return;

    try {
      await withLoading('delete_${journal.id}', () async {
        await _service.deleteJournal(groupId, journal.id);
      });
      await _fetch();
      if (mounted) {
        Globals.errorNotificationManager.showSuccess(
          'Журнал "${journal.name}" видалено',
        );
      }
    } catch (e) {
      if (mounted) {
        Globals.errorNotificationManager.showError('Помилка видалення: $e');
      }
    }
  }

  void _openJournal(MaterialJournal journal) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MaterialJournalPage(journal: journal),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loading = isLoading('fetch') && _journals.isEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Журнали матбази')),
      body: loading
          ? const Center(
              child: LoadingIndicator(message: 'Завантаження журналів...'),
            )
          : RefreshIndicator(
              onRefresh: _fetch,
              child: _journals.isEmpty
                  ? _buildEmpty()
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _journals.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, i) =>
                          _JournalCard(
                            journal: _journals[i],
                            canManage: _canManage,
                            isAdmin: _isAdmin,
                            onTap: () => _openJournal(_journals[i]),
                            onEdit: () => _showEditDialog(_journals[i]),
                            onDelete: () => _deleteJournal(_journals[i]),
                          ),
                    ),
            ),
      floatingActionButton: _canManage
          ? FloatingActionButton(
              onPressed: _showCreateDialog,
              tooltip: 'Новий журнал',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 64,
            color: Colors.grey.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Журнали відсутні',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          if (_canManage) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showCreateDialog,
              icon: const Icon(Icons.add),
              label: const Text('Створити перший журнал'),
            ),
          ],
        ],
      ),
    );
  }
}

class _JournalCard extends StatelessWidget {
  final MaterialJournal journal;
  final bool canManage;
  final bool isAdmin;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _JournalCard({
    required this.journal,
    required this.canManage,
    required this.isAdmin,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'щойно';
    if (diff.inHours < 1) return '${diff.inMinutes} хв тому';
    if (diff.inDays < 1) return '${diff.inHours} год тому';
    if (diff.inDays < 7) return '${diff.inDays} дн тому';
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.inventory_2,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      journal.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (journal.description != null &&
                        journal.description!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        journal.description!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      'Змінено: ${_formatDate(journal.modifiedAt)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              if (canManage)
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'edit') onEdit();
                    if (v == 'delete') onDelete();
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 18),
                          SizedBox(width: 8),
                          Text('Редагувати'),
                        ],
                      ),
                    ),
                    if (isAdmin)
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text(
                              'Видалити',
                              style: TextStyle(color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
