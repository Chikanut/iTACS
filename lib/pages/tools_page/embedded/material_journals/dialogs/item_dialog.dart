import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../globals.dart';
import '../../../../../models/material_journal/material_item.dart';
import '../../../../../services/material_journal_service.dart';

class ItemDialog extends StatefulWidget {
  final String journalId;
  final MaterialItem? existing;
  final VoidCallback onSaved;
  final List<String> availableGroups;

  const ItemDialog({
    super.key,
    required this.journalId,
    this.existing,
    required this.onSaved,
    this.availableGroups = const [],
  });

  bool get isEditing => existing != null;

  @override
  State<ItemDialog> createState() => _ItemDialogState();
}

class _ItemDialogState extends State<ItemDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _quantityCtrl;
  late final TextEditingController _minCtrl;
  late final TextEditingController _countCtrl;
  late final TextEditingController _commentCtrl;
  late final TextEditingController _groupCtrl;

  MaterialItemType _type = MaterialItemType.consumable;
  MaterialUnit _unit = MaterialUnit.pcs;
  ItemCondition _condition = ItemCondition.working;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _type = e?.type ?? MaterialItemType.consumable;
    _unit = e?.unit ?? MaterialUnit.pcs;
    _condition = e?.condition ?? ItemCondition.working;
    _quantityCtrl = TextEditingController(
      text: e?.quantity != null ? _fmt(e!.quantity) : '',
    );
    _minCtrl = TextEditingController(
      text: e?.minQuantity != null ? _fmt(e!.minQuantity) : '',
    );
    _countCtrl = TextEditingController(
      text: e?.count != null ? e!.count.toString() : '',
    );
    _commentCtrl = TextEditingController(text: e?.conditionComment ?? '');
    _groupCtrl = TextEditingController(text: e?.group ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _quantityCtrl.dispose();
    _minCtrl.dispose();
    _countCtrl.dispose();
    _commentCtrl.dispose();
    _groupCtrl.dispose();
    super.dispose();
  }

  String _fmt(double v) {
    if (v == v.truncateToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(2);
  }

  void _onTypeChanged(MaterialItemType? v) {
    if (v == null || v == _type) return;
    if (widget.isEditing) {
      _confirmTypeChange(v);
    } else {
      setState(() => _type = v);
    }
  }

  Future<void> _confirmTypeChange(MaterialItemType newType) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Змінити тип елемента?'),
        content: const Text(
          'Зміна типу призведе до того, що деякі дані (кількість або стан) будуть скинуті. Продовжити?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Скасувати'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Змінити'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) setState(() => _type = newType);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final groupId = Globals.profileManager.currentGroupId;
    if (groupId == null) return;

    final userName = Globals.profileManager.currentUserName;
    final group = _groupCtrl.text.trim();
    setState(() => _saving = true);
    try {
      final service = MaterialJournalService();
      MaterialItem item;

      if (_type == MaterialItemType.nonConsumable) {
        item = MaterialItem(
          id: widget.existing?.id ?? '',
          name: _nameCtrl.text.trim(),
          type: _type,
          modifiedAt: DateTime.now(),
          modifiedBy: userName,
          group: group,
          count: int.tryParse(_countCtrl.text.trim()) ?? 0,
          condition: _condition,
          conditionComment: _commentCtrl.text.trim(),
        );
      } else {
        final qty = double.tryParse(_quantityCtrl.text.trim()) ?? 0;
        final min = double.tryParse(_minCtrl.text.trim()) ?? 0;
        item = MaterialItem(
          id: widget.existing?.id ?? '',
          name: _nameCtrl.text.trim(),
          type: _type,
          modifiedAt: DateTime.now(),
          modifiedBy: userName,
          group: group,
          quantity: qty,
          unit: _unit,
          minQuantity: min,
          status: ItemStatusX.compute(qty, min),
        );
      }

      if (widget.isEditing) {
        await service.updateItemMeta(groupId, widget.journalId, item);
      } else {
        await service.createItem(groupId, widget.journalId, item, userName);
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
    final groups =
        widget.availableGroups.where((g) => g.isNotEmpty).toSet().toList()
          ..sort();

    return AlertDialog(
      title: Text(widget.isEditing ? 'Редагувати елемент' : 'Новий елемент'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Назва *',
                  hintText: 'напр. Дими',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Введіть назву' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<MaterialItemType>(
                value: _type,
                decoration: const InputDecoration(
                  labelText: 'Тип',
                  border: OutlineInputBorder(),
                ),
                items: MaterialItemType.values
                    .map(
                      (t) => DropdownMenuItem(value: t, child: Text(t.label)),
                    )
                    .toList(),
                onChanged: _onTypeChanged,
              ),
              const SizedBox(height: 12),
              if (_type == MaterialItemType.nonConsumable) ...[
                TextFormField(
                  controller: _countCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Кількість (шт)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<ItemCondition>(
                  value: _condition,
                  decoration: const InputDecoration(
                    labelText: 'Стан',
                    border: OutlineInputBorder(),
                  ),
                  items: ItemCondition.values
                      .map(
                        (c) => DropdownMenuItem(value: c, child: Text(c.label)),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _condition = v!),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _commentCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Коментар до стану',
                    border: OutlineInputBorder(),
                  ),
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _quantityCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Кількість',
                          border: OutlineInputBorder(),
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
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 90,
                      child: DropdownButtonFormField<MaterialUnit>(
                        value: _unit,
                        decoration: const InputDecoration(
                          labelText: 'Од.',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 12,
                          ),
                        ),
                        items: MaterialUnit.values
                            .map(
                              (u) => DropdownMenuItem(
                                value: u,
                                child: Text(u.label),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _unit = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _minCtrl,
                  decoration: InputDecoration(
                    labelText: 'Мінімальний залишок (${_unit.label})',
                    border: const OutlineInputBorder(),
                    helperText: 'При досягненні — статус "Мало"',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _groupCtrl,
                decoration: const InputDecoration(
                  labelText: 'Група (необов\'язково)',
                  hintText: 'напр. Резерв, Медикаменти',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.folder_outlined, size: 18),
                ),
              ),
              if (groups.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final g in groups)
                      ActionChip(
                        avatar: const Icon(Icons.folder, size: 14),
                        label: Text(g, style: const TextStyle(fontSize: 12)),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => setState(() => _groupCtrl.text = g),
                      ),
                  ],
                ),
              ],
            ],
          ),
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
              : Text(widget.isEditing ? 'Зберегти' : 'Додати'),
        ),
      ],
    );
  }
}
