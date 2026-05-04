import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../globals.dart';
import '../../../../models/material_journal/material_history_record.dart';
import '../../../../models/material_journal/material_item.dart';
import '../../../../services/material_journal_service.dart';

class MaterialItemDetailPage extends StatefulWidget {
  final String journalId;
  final String journalName;
  final MaterialItem item;

  const MaterialItemDetailPage({
    super.key,
    required this.journalId,
    required this.journalName,
    required this.item,
  });

  @override
  State<MaterialItemDetailPage> createState() => _MaterialItemDetailPageState();
}

class _MaterialItemDetailPageState extends State<MaterialItemDetailPage> {
  final _service = MaterialJournalService();
  List<MaterialHistoryRecord> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_fetch());
  }

  Future<void> _fetch() async {
    final groupId = Globals.profileManager.currentGroupId ?? '';
    final records = await _service.getHistory(
      groupId,
      journalId: widget.journalId,
      itemId: widget.item.id,
    );
    if (mounted) {
      setState(() {
        _history = records;
        _loading = false;
      });
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _fmt(double v) {
    if (v == v.truncateToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(2);
  }

  Color _statusColor() {
    if (widget.item.type == MaterialItemType.nonConsumable) {
      return switch (widget.item.condition) {
        ItemCondition.working => Colors.green,
        ItemCondition.damaged => Colors.orange,
        ItemCondition.inRepair => Colors.blue,
        ItemCondition.writtenOff => Colors.grey,
      };
    }
    return switch (widget.item.status) {
      ItemStatus.normal => Colors.green,
      ItemStatus.low => Colors.orange,
      ItemStatus.critical => Colors.red,
    };
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isNonConsumable = item.type == MaterialItemType.nonConsumable;
    final statusColor = _statusColor();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.name),
            Text(
              widget.journalName,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Info card
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.type.label,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 4),
                            if (isNonConsumable) ...[
                              Text(
                                '${item.count} шт',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: statusColor,
                                    ),
                              ),
                              Text(
                                item.condition.label,
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (item.conditionComment.isNotEmpty)
                                Text(
                                  item.conditionComment,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                            ] else ...[
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    _fmt(item.quantity),
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: statusColor,
                                        ),
                                  ),
                                  const SizedBox(width: 4),
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      item.unit.label,
                                      style: TextStyle(
                                        color: statusColor,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    margin: const EdgeInsets.only(right: 4),
                                    decoration: BoxDecoration(
                                      color: statusColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  Text(
                                    item.status.label,
                                    style: TextStyle(color: statusColor),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (!isNonConsumable && item.minQuantity > 0)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Мінімум',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: Colors.grey[600]),
                            ),
                            Text(
                              '${_fmt(item.minQuantity)} ${item.unit.label}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  if (item.modifiedBy.isNotEmpty) ...[
                    const Divider(height: 20),
                    Text(
                      'Змінено: ${item.modifiedBy} · ${_formatDate(item.modifiedAt)}',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Історія змін',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _history.isEmpty
                ? Center(
                    child: Text(
                      'Записів ще немає',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _fetch,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _history.length,
                      separatorBuilder: (_, index) => const Divider(height: 1),
                      itemBuilder: (_, i) => _HistoryRow(record: _history[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final MaterialHistoryRecord record;
  const _HistoryRow({required this.record});

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
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(_actionIcon(), size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      record.action.label,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: color,
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _formatDate(record.timestamp),
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${record.before}  ${record.change}  →  ${record.after}',
                  style: const TextStyle(fontSize: 13),
                ),
                Text(
                  record.userName,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                if (record.comment != null && record.comment!.isNotEmpty)
                  Text(
                    record.comment!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                if (record.targetJournalName != null)
                  Text(
                    record.action == MaterialAction.transfer
                        ? '→ ${record.targetJournalName}'
                        : '← ${record.targetJournalName}',
                    style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _actionIcon() => switch (record.action) {
    MaterialAction.writeOff => Icons.remove_circle_outline,
    MaterialAction.replenish => Icons.add_circle_outline,
    MaterialAction.transfer => Icons.arrow_forward,
    MaterialAction.transferReceive => Icons.arrow_back,
    MaterialAction.conditionChange => Icons.build_outlined,
    MaterialAction.correction => Icons.tune,
    MaterialAction.create => Icons.fiber_new,
  };
}
