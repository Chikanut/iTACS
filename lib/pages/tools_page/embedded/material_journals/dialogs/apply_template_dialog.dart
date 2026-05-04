import 'package:flutter/material.dart';

import '../../../../../models/material_journal/material_item.dart';
import '../../../../../models/material_journal/material_template.dart';

enum TemplateLineStatus { ok, low, missing }

class ApplyTemplateDialog extends StatefulWidget {
  final MaterialTemplate template;
  final Map<String, MaterialItem> itemsById;

  const ApplyTemplateDialog({
    super.key,
    required this.template,
    required this.itemsById,
  });

  @override
  State<ApplyTemplateDialog> createState() => _ApplyTemplateDialogState();
}

class _ApplyTemplateDialogState extends State<ApplyTemplateDialog> {
  final _commentCtrl = TextEditingController();

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  String _fmt(double v) {
    if (v == v.truncateToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(2);
  }

  TemplateLineStatus _lineStatus(TemplateLineItem line) {
    final item = widget.itemsById[line.itemId];
    if (item == null) return TemplateLineStatus.missing;
    if (item.quantity < line.quantity) return TemplateLineStatus.low;
    return TemplateLineStatus.ok;
  }

  @override
  Widget build(BuildContext context) {
    final lines = widget.template.items;
    final anyProblem = lines.any(
      (l) => _lineStatus(l) != TemplateLineStatus.ok,
    );

    return AlertDialog(
      title: Text('Застосувати: ${widget.template.name}'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Буде списано:'),
            const SizedBox(height: 8),
            ...lines.map((line) {
              final item = widget.itemsById[line.itemId];
              final status = _lineStatus(line);
              final unit = item?.unit.label ?? 'шт';
              final available = item != null ? _fmt(item.quantity) : '?';

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Text(switch (status) {
                      TemplateLineStatus.ok => '🟢',
                      TemplateLineStatus.low => '🟡',
                      TemplateLineStatus.missing => '🔴',
                    }),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${line.itemName}: потрібно ${_fmt(line.quantity)} $unit, є $available $unit',
                        style: TextStyle(
                          color: switch (status) {
                            TemplateLineStatus.ok => null,
                            TemplateLineStatus.low => Colors.orange[700],
                            TemplateLineStatus.missing => Colors.red[700],
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (anyProblem) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: const Text(
                  '🟡 — буде списано доступну кількість\n'
                  '🔴 — елемент відсутній або не знайдено, буде пропущено',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _commentCtrl,
              decoration: const InputDecoration(
                labelText: 'Коментар (необов\'язково)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          // pop with null → caller treats as "cancelled"
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Скасувати'),
        ),
        FilledButton(
          // pop with a record → caller knows it was confirmed
          onPressed: () => Navigator.of(context).pop((
            confirmed: true,
            comment: _commentCtrl.text.trim().isEmpty
                ? null
                : _commentCtrl.text.trim(),
          )),
          child: const Text('Підтвердити списання'),
        ),
      ],
    );
  }
}
