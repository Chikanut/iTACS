import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../globals.dart';
import '../../../../../models/material_journal/material_item.dart';
import '../../../../../models/material_journal/material_template.dart';
import '../../../../../services/material_journal_service.dart';

class TemplateDialog extends StatefulWidget {
  final String journalId;
  final List<MaterialItem> journalItems;
  final MaterialTemplate? existing;
  final VoidCallback onSaved;

  const TemplateDialog({
    super.key,
    required this.journalId,
    required this.journalItems,
    this.existing,
    required this.onSaved,
  });

  bool get isEditing => existing != null;

  @override
  State<TemplateDialog> createState() => _TemplateDialogState();
}

class _TemplateDialogState extends State<TemplateDialog> {
  final _nameCtrl = TextEditingController();
  final Map<String, TextEditingController> _qtyCtrls = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = widget.existing?.name ?? '';
    for (final item in widget.journalItems) {
      if (item.type == MaterialItemType.nonConsumable) continue;
      final existingLine = widget.existing?.items
          .where((l) => l.itemId == item.id)
          .firstOrNull;
      _qtyCtrls[item.id] = TextEditingController(
        text: existingLine != null ? _fmt(existingLine.quantity) : '',
      );
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    for (final c in _qtyCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _fmt(double v) {
    if (v == v.truncateToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(2);
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      Globals.errorNotificationManager.showError('Введіть назву шаблону');
      return;
    }
    final lines = <TemplateLineItem>[];
    for (final item in widget.journalItems) {
      if (item.type == MaterialItemType.nonConsumable) continue;
      final ctrl = _qtyCtrls[item.id];
      if (ctrl == null) continue;
      final qty = double.tryParse(ctrl.text.trim()) ?? 0;
      if (qty > 0) {
        lines.add(
          TemplateLineItem(itemId: item.id, itemName: item.name, quantity: qty),
        );
      }
    }
    if (lines.isEmpty) {
      Globals.errorNotificationManager.showError(
        'Додайте хоча б один елемент з кількістю > 0',
      );
      return;
    }

    final groupId = Globals.profileManager.currentGroupId;
    if (groupId == null) return;
    final email = Globals.profileManager.currentUserEmail ?? '';

    setState(() => _saving = true);
    try {
      final template = MaterialTemplate(
        id: widget.existing?.id ?? '',
        name: _nameCtrl.text.trim(),
        items: lines,
        createdAt: widget.existing?.createdAt ?? DateTime.now(),
        authorEmail: email,
      );
      final service = MaterialJournalService();
      if (widget.isEditing) {
        await service.updateTemplate(groupId, widget.journalId, template);
      } else {
        await service.createTemplate(groupId, widget.journalId, template);
      }
      if (mounted) {
        Navigator.of(context).pop();
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        Globals.errorNotificationManager.showError('Помилка збереження: $e');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final consumableItems = widget.journalItems
        .where((i) => i.type != MaterialItemType.nonConsumable)
        .toList();

    return AlertDialog(
      title: Text(widget.isEditing ? 'Редагувати шаблон' : 'Новий шаблон'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Назва шаблону *',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Кількість для кожного елемента (0 = не включати):'),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: consumableItems.length,
                itemBuilder: (context, i) {
                  final item = consumableItems[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${item.name} (є: ${_fmt(item.quantity)} ${item.unit.label})',
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 90,
                          child: TextField(
                            controller: _qtyCtrls[item.id],
                            decoration: InputDecoration(
                              suffixText: item.unit.label,
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d*'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Скасувати'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.isEditing ? 'Зберегти' : 'Створити'),
        ),
      ],
    );
  }
}
