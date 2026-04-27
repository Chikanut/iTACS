import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../globals.dart';
import '../../../../mixins/loading_state_mixin.dart';
import '../../../../models/material_journal/material_history_record.dart';
import '../../../../models/material_journal/material_item.dart';
import '../../../../models/material_journal/material_journal.dart';
import '../../../../models/material_journal/material_template.dart';
import '../../../../services/material_journal_service.dart';
import '../../../../widgets/loading_indicator.dart';
import 'dialogs/apply_template_dialog.dart';
import 'dialogs/condition_dialog.dart';
import 'dialogs/item_dialog.dart';
import 'dialogs/quantity_action_dialog.dart';
import 'dialogs/template_dialog.dart';
import 'dialogs/transfer_dialog.dart';
import 'material_item_detail_page.dart';

class MaterialJournalPage extends StatefulWidget {
  final MaterialJournal journal;

  const MaterialJournalPage({super.key, required this.journal});

  @override
  State<MaterialJournalPage> createState() => _MaterialJournalPageState();
}

class _MaterialJournalPageState extends State<MaterialJournalPage>
    with LoadingStateMixin {
  final _service = MaterialJournalService();
  List<MaterialItem> _items = [];
  List<MaterialTemplate> _templates = [];

  bool get _canManage =>
      !Globals.appRuntimeState.isReadOnlyOffline &&
      Globals.profileManager.currentRole != 'viewer';

  bool get _isAdmin =>
      !Globals.appRuntimeState.isReadOnlyOffline &&
      Globals.profileManager.currentRole == 'admin';

  String get _groupId => Globals.profileManager.currentGroupId ?? '';
  String get _journalId => widget.journal.id;
  String get _userName => Globals.profileManager.currentUserName;

  @override
  void initState() {
    super.initState();
    unawaited(_fetchAll());
  }

  Future<void> _fetchAll() async {
    await withLoading('fetch', () async {
      final items = await _service.getItems(_groupId, _journalId);
      final templates = await _service.getTemplates(_groupId, _journalId);
      if (mounted) {
        setState(() {
          _items = items;
          _templates = templates;
        });
      }
    });
  }

  Future<void> _fetchItems() async {
    final items = await _service.getItems(_groupId, _journalId);
    if (mounted) setState(() => _items = items);
  }

  // ── Item actions ────────────────────────────────────────────────────────

  Future<void> _showWriteOff(MaterialItem item) async {
    final result = await showDialog<({double amount, String? comment})>(
      context: context,
      builder: (_) => QuantityActionDialog(
        item: item,
        actionType: QuantityActionType.writeOff,
      ),
    );
    if (result == null) return;
    try {
      await _service.writeOff(
        _groupId,
        _journalId,
        item,
        result.amount,
        result.comment,
        _userName,
      );
      await _fetchItems();
      if (mounted) {
        Globals.errorNotificationManager.showSuccess(
          'Списано ${result.amount} ${item.unit.label}',
        );
      }
    } catch (e) {
      if (mounted) {
        Globals.errorNotificationManager.showError('Помилка: $e');
      }
    }
  }

  Future<void> _showReplenish(MaterialItem item) async {
    final result = await showDialog<({double amount, String? comment})>(
      context: context,
      builder: (_) => QuantityActionDialog(
        item: item,
        actionType: QuantityActionType.replenish,
      ),
    );
    if (result == null) return;
    try {
      await _service.replenish(
        _groupId,
        _journalId,
        item,
        result.amount,
        result.comment,
        _userName,
      );
      await _fetchItems();
      if (mounted) {
        Globals.errorNotificationManager.showSuccess(
          'Поповнено +${result.amount} ${item.unit.label}',
        );
      }
    } catch (e) {
      if (mounted) {
        Globals.errorNotificationManager.showError('Помилка: $e');
      }
    }
  }

  Future<void> _showTransfer(MaterialItem item) async {
    await showDialog<void>(
      context: context,
      builder: (_) => TransferDialog(
        fromJournalId: _journalId,
        fromItem: item,
        onTransferred: _fetchItems,
      ),
    );
  }

  Future<void> _showConditionChange(MaterialItem item) async {
    final result =
        await showDialog<({ItemCondition condition, String? comment})>(
      context: context,
      builder: (_) => ConditionDialog(item: item),
    );
    if (result == null) return;
    try {
      await _service.changeCondition(
        _groupId,
        _journalId,
        item,
        result.condition,
        result.comment,
        _userName,
      );
      await _fetchItems();
    } catch (e) {
      if (mounted) {
        Globals.errorNotificationManager.showError('Помилка: $e');
      }
    }
  }

  Future<void> _showCorrection(MaterialItem item) async {
    final result = await showDialog<({double amount, String? comment})>(
      context: context,
      builder: (_) => QuantityActionDialog(
        item: item,
        actionType: QuantityActionType.correction,
      ),
    );
    if (result == null) return;
    try {
      await _service.correction(
        _groupId,
        _journalId,
        item,
        result.amount,
        result.comment,
        _userName,
      );
      await _fetchItems();
      if (mounted) {
        Globals.errorNotificationManager.showSuccess('Корекцію збережено');
      }
    } catch (e) {
      if (mounted) {
        Globals.errorNotificationManager.showError('Помилка: $e');
      }
    }
  }

  Future<void> _deleteItem(MaterialItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Видалити елемент?'),
        content: Text('Видалити "${item.name}"?'),
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
    if (ok != true) return;
    try {
      await _service.deleteItem(_groupId, _journalId, item.id);
      await _fetchItems();
    } catch (e) {
      if (mounted) {
        Globals.errorNotificationManager.showError('Помилка: $e');
      }
    }
  }

  // ── Templates ────────────────────────────────────────────────────────────

  Future<void> _showTemplates() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _TemplatesSheet(
        journalId: _journalId,
        items: _items,
        templates: _templates,
        canManage: _canManage,
        onApply: _applyTemplate,
        onChanged: _fetchAll,
      ),
    );
  }

  Future<void> _applyTemplate(MaterialTemplate template) async {
    final itemsById = {for (final i in _items) i.id: i};
    final comment = await showDialog<String?>(
      context: context,
      builder: (_) => ApplyTemplateDialog(
        template: template,
        itemsById: itemsById,
      ),
    );
    if (comment == null && !context.mounted) return;
    // null comment means confirmed without text (dialog returns null = confirmed)
    // We use Navigator.pop(null) for confirmed-without-comment case
    // but ApplyTemplateDialog pops with null on confirm too — check mounted
    if (!mounted) return;

    try {
      final errors = await _service.applyTemplate(
        _groupId,
        _journalId,
        template,
        itemsById,
        comment,
        _userName,
      );
      await _fetchItems();
      if (mounted) {
        if (errors.isEmpty) {
          Globals.errorNotificationManager.showSuccess(
            'Шаблон "${template.name}" застосовано',
          );
        } else {
          Globals.errorNotificationManager.showError(
            'Застосовано з помилками: ${errors.length} елемент(ів) пропущено',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Globals.errorNotificationManager.showError('Помилка: $e');
      }
    }
  }

  // ── History ───────────────────────────────────────────────────────────────

  Future<void> _showHistory() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _JournalHistoryPage(
          journalId: _journalId,
          journalName: widget.journal.name,
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final loading = isLoading('fetch') && _items.isEmpty;
    final criticalCount = _items.where((i) => i.isCritical).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.journal.name),
        actions: [
          if (_templates.isNotEmpty || _canManage)
            IconButton(
              icon: const Icon(Icons.auto_awesome),
              tooltip: 'Шаблони',
              onPressed: _showTemplates,
            ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Історія',
            onPressed: _showHistory,
          ),
        ],
      ),
      body: loading
          ? const Center(
              child: LoadingIndicator(message: 'Завантаження матбази...'),
            )
          : RefreshIndicator(
              onRefresh: _fetchAll,
              child: Column(
                children: [
                  if (criticalCount > 0)
                    _CriticalBanner(count: criticalCount),
                  Expanded(
                    child: _items.isEmpty
                        ? _buildEmpty()
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _items.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, i) => _ItemTile(
                              item: _items[i],
                              canManage: _canManage,
                              isAdmin: _isAdmin,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => MaterialItemDetailPage(
                                    journalId: _journalId,
                                    journalName: widget.journal.name,
                                    item: _items[i],
                                  ),
                                ),
                              ),
                              onWriteOff: () => _showWriteOff(_items[i]),
                              onReplenish: () => _showReplenish(_items[i]),
                              onTransfer: () => _showTransfer(_items[i]),
                              onCondition: () =>
                                  _showConditionChange(_items[i]),
                              onCorrection: () => _showCorrection(_items[i]),
                              onEdit: () => showDialog<void>(
                                context: context,
                                builder: (_) => ItemDialog(
                                  journalId: _journalId,
                                  existing: _items[i],
                                  onSaved: _fetchItems,
                                ),
                              ),
                              onDelete: () => _deleteItem(_items[i]),
                            ),
                          ),
                  ),
                ],
              ),
            ),
      floatingActionButton: _canManage
          ? FloatingActionButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) =>
                    ItemDialog(journalId: _journalId, onSaved: _fetchItems),
              ),
              tooltip: 'Додати елемент',
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
            Icons.inbox_outlined,
            size: 64,
            color: Colors.grey.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Матбаза порожня',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          if (_canManage) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) =>
                    ItemDialog(journalId: _journalId, onSaved: _fetchItems),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Додати перший елемент'),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Item tile ──────────────────────────────────────────────────────────────

class _ItemTile extends StatelessWidget {
  final MaterialItem item;
  final bool canManage;
  final bool isAdmin;
  final VoidCallback onTap;
  final VoidCallback onWriteOff;
  final VoidCallback onReplenish;
  final VoidCallback onTransfer;
  final VoidCallback onCondition;
  final VoidCallback onCorrection;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ItemTile({
    required this.item,
    required this.canManage,
    required this.isAdmin,
    required this.onTap,
    required this.onWriteOff,
    required this.onReplenish,
    required this.onTransfer,
    required this.onCondition,
    required this.onCorrection,
    required this.onEdit,
    required this.onDelete,
  });

  Color _statusColor(BuildContext context) {
    if (item.type == MaterialItemType.nonConsumable) {
      return switch (item.condition) {
        ItemCondition.working => Colors.green,
        ItemCondition.damaged => Colors.orange,
        ItemCondition.inRepair => Colors.blue,
        ItemCondition.writtenOff => Colors.grey,
      };
    }
    return switch (item.status) {
      ItemStatus.normal => Colors.green,
      ItemStatus.low => Colors.orange,
      ItemStatus.critical => Colors.red,
    };
  }

  String _statusLabel() {
    if (item.type == MaterialItemType.nonConsumable) {
      return item.condition.label;
    }
    return item.status.label;
  }

  String _quantityLabel() {
    if (item.type == MaterialItemType.nonConsumable) {
      return '${item.count} шт';
    }
    final q = item.quantity;
    final formatted = q == q.truncateToDouble()
        ? q.toInt().toString()
        : q.toStringAsFixed(2);
    return '$formatted ${item.unit.label}';
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(context);

    return Card(
      elevation: 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    _quantityLabel(),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 18, top: 2),
                child: Row(
                  children: [
                    Text(
                      '${item.type.label} · ${_statusLabel()}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                    if (item.type != MaterialItemType.nonConsumable &&
                        item.minQuantity > 0)
                      Text(
                        ' · мін: ${item.minQuantity.toInt()} ${item.unit.label}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[500],
                        ),
                      ),
                  ],
                ),
              ),
              if (canManage)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _ActionRow(
                    item: item,
                    isAdmin: isAdmin,
                    onWriteOff: onWriteOff,
                    onReplenish: onReplenish,
                    onTransfer: onTransfer,
                    onCondition: onCondition,
                    onCorrection: onCorrection,
                    onEdit: onEdit,
                    onDelete: onDelete,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final MaterialItem item;
  final bool isAdmin;
  final VoidCallback onWriteOff;
  final VoidCallback onReplenish;
  final VoidCallback onTransfer;
  final VoidCallback onCondition;
  final VoidCallback onCorrection;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ActionRow({
    required this.item,
    required this.isAdmin,
    required this.onWriteOff,
    required this.onReplenish,
    required this.onTransfer,
    required this.onCondition,
    required this.onCorrection,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isNonConsumable = item.type == MaterialItemType.nonConsumable;

    return Row(
      children: [
        if (!isNonConsumable) ...[
          _ActionBtn(
            icon: Icons.remove,
            label: 'Списати',
            color: Colors.red,
            onTap: onWriteOff,
          ),
          const SizedBox(width: 6),
          _ActionBtn(
            icon: Icons.add,
            label: 'Поповнити',
            color: Colors.green,
            onTap: onReplenish,
          ),
          const SizedBox(width: 6),
          _ActionBtn(
            icon: Icons.swap_horiz,
            label: 'Перенести',
            color: Colors.blue,
            onTap: onTransfer,
          ),
        ] else
          _ActionBtn(
            icon: Icons.build,
            label: 'Стан',
            color: Colors.orange,
            onTap: onCondition,
          ),
        const Spacer(),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, size: 18),
          onSelected: (v) {
            if (v == 'edit') onEdit();
            if (v == 'correction') onCorrection();
            if (v == 'delete') onDelete();
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 16),
                  SizedBox(width: 8),
                  Text('Редагувати'),
                ],
              ),
            ),
            if (!isNonConsumable && isAdmin)
              const PopupMenuItem(
                value: 'correction',
                child: Row(
                  children: [
                    Icon(Icons.tune, size: 16),
                    SizedBox(width: 8),
                    Text('Корекція'),
                  ],
                ),
              ),
            if (isAdmin)
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 16, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Видалити', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 14, color: color),
      label: Text(
        label,
        style: TextStyle(fontSize: 12, color: color),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        side: BorderSide(color: color.withOpacity(0.5)),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

// ── Critical banner ────────────────────────────────────────────────────────

class _CriticalBanner extends StatelessWidget {
  final int count;
  const _CriticalBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.red.shade50,
      child: Row(
        children: [
          const Icon(Icons.warning_amber, color: Colors.red, size: 18),
          const SizedBox(width: 8),
          Text(
            '$count позицій з критичним залишком',
            style: TextStyle(color: Colors.red[700], fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ── Templates bottom sheet ─────────────────────────────────────────────────

class _TemplatesSheet extends StatefulWidget {
  final String journalId;
  final List<MaterialItem> items;
  final List<MaterialTemplate> templates;
  final bool canManage;
  final Future<void> Function(MaterialTemplate) onApply;
  final VoidCallback onChanged;

  const _TemplatesSheet({
    required this.journalId,
    required this.items,
    required this.templates,
    required this.canManage,
    required this.onApply,
    required this.onChanged,
  });

  @override
  State<_TemplatesSheet> createState() => _TemplatesSheetState();
}

class _TemplatesSheetState extends State<_TemplatesSheet> {
  late List<MaterialTemplate> _templates;

  @override
  void initState() {
    super.initState();
    _templates = widget.templates;
  }

  Future<void> _reload() async {
    final groupId = Globals.profileManager.currentGroupId ?? '';
    final templates = await MaterialJournalService().getTemplates(
      groupId,
      widget.journalId,
    );
    if (mounted) setState(() => _templates = templates);
    widget.onChanged();
  }

  Future<void> _deleteTemplate(MaterialTemplate t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Видалити шаблон?'),
        content: Text('Видалити "${t.name}"?'),
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
    if (ok != true) return;
    final groupId = Globals.profileManager.currentGroupId ?? '';
    await MaterialJournalService().deleteTemplate(
      groupId,
      widget.journalId,
      t.id,
    );
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (_, ctrl) => Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Шаблони списання',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (widget.canManage)
                  IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: 'Новий шаблон',
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => TemplateDialog(
                        journalId: widget.journalId,
                        journalItems: widget.items,
                        onSaved: _reload,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _templates.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.auto_awesome_outlined,
                          size: 48,
                          color: Colors.grey.withOpacity(0.5),
                        ),
                        const SizedBox(height: 12),
                        const Text('Шаблонів немає'),
                        if (widget.canManage) ...[
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => showDialog<void>(
                              context: context,
                              builder: (_) => TemplateDialog(
                                journalId: widget.journalId,
                                journalItems: widget.items,
                                onSaved: _reload,
                              ),
                            ),
                            icon: const Icon(Icons.add),
                            label: const Text('Створити шаблон'),
                          ),
                        ],
                      ],
                    ),
                  )
                : ListView.separated(
                    controller: ctrl,
                    padding: const EdgeInsets.all(16),
                    itemCount: _templates.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final t = _templates[i];
                      return Card(
                        elevation: 1,
                        child: ListTile(
                          leading: const Icon(Icons.auto_awesome),
                          title: Text(t.name),
                          subtitle: Text('${t.items.length} позицій'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (widget.canManage) ...[
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 18),
                                  onPressed: () => showDialog<void>(
                                    context: context,
                                    builder: (_) => TemplateDialog(
                                      journalId: widget.journalId,
                                      journalItems: widget.items,
                                      existing: t,
                                      onSaved: _reload,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    size: 18,
                                    color: Colors.red,
                                  ),
                                  onPressed: () => _deleteTemplate(t),
                                ),
                              ],
                              FilledButton(
                                onPressed: () async {
                                  Navigator.of(context).pop();
                                  await widget.onApply(t);
                                },
                                child: const Text('Застосувати'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Journal history page ───────────────────────────────────────────────────

class _JournalHistoryPage extends StatefulWidget {
  final String journalId;
  final String journalName;

  const _JournalHistoryPage({
    required this.journalId,
    required this.journalName,
  });

  @override
  State<_JournalHistoryPage> createState() => _JournalHistoryPageState();
}

class _JournalHistoryPageState extends State<_JournalHistoryPage> {
  final _service = MaterialJournalService();
  List<MaterialHistoryRecord> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final groupId = Globals.profileManager.currentGroupId ?? '';
    final records = await _service.getHistory(
      groupId,
      journalId: widget.journalId,
    );
    if (mounted) setState(() {
      _history = records;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Історія: ${widget.journalName}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
              ? const Center(child: Text('Записів немає'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _history.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) => _HistoryTile(record: _history[i]),
                ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final MaterialHistoryRecord record;
  const _HistoryTile({required this.record});

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Color _actionColor() => switch (record.action) {
    MaterialAction.writeOff => Colors.red,
    MaterialAction.replenish => Colors.green,
    MaterialAction.transfer => Colors.blue,
    MaterialAction.transferReceive => Colors.blue,
    MaterialAction.conditionChange => Colors.orange,
    MaterialAction.correction => Colors.purple,
    MaterialAction.create => Colors.teal,
  };

  @override
  Widget build(BuildContext context) {
    final color = _actionColor();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Text(
                  record.action.label,
                  style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  record.itemName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${record.before}  ${record.change}  →  ${record.after}',
            style: const TextStyle(fontFamily: 'monospace'),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Text(
                record.userName,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const Text(' · ', style: TextStyle(color: Colors.grey)),
              Text(
                _formatDate(record.timestamp),
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
          if (record.comment != null && record.comment!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              record.comment!,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (record.targetJournalName != null) ...[
            const SizedBox(height: 2),
            Text(
              record.action == MaterialAction.transfer
                  ? '→ ${record.targetJournalName}'
                  : '← ${record.targetJournalName}',
              style: TextStyle(fontSize: 12, color: Colors.blue[700]),
            ),
          ],
        ],
      ),
    );
  }
}
