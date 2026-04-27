import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../models/material_journal/material_item.dart';

enum QuantityActionType { writeOff, replenish, correction }

class QuantityActionDialog extends StatefulWidget {
  final MaterialItem item;
  final QuantityActionType actionType;

  const QuantityActionDialog({
    super.key,
    required this.item,
    required this.actionType,
  });

  @override
  State<QuantityActionDialog> createState() => _QuantityActionDialogState();
}

class _QuantityActionDialogState extends State<QuantityActionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _commentCtrl = TextEditingController();

  @override
  void dispose() {
    _amountCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  String get _title => switch (widget.actionType) {
    QuantityActionType.writeOff => 'Списати',
    QuantityActionType.replenish => 'Поповнити',
    QuantityActionType.correction => 'Корекція залишку',
  };

  String get _amountLabel => switch (widget.actionType) {
    QuantityActionType.writeOff => 'Кількість для списання',
    QuantityActionType.replenish => 'Кількість для поповнення',
    QuantityActionType.correction => 'Нова кількість',
  };

  String _fmt(double v) {
    if (v == v.truncateToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(2);
  }

  void _confirm() {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    final comment = _commentCtrl.text.trim().isEmpty
        ? null
        : _commentCtrl.text.trim();
    Navigator.of(context).pop((amount: amount, comment: comment));
  }

  @override
  Widget build(BuildContext context) {
    final unit = widget.item.unit.label;
    final current = widget.item.quantity;

    return AlertDialog(
      title: Text('$_title: ${widget.item.name}'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Поточний залишок: ${_fmt(current)} $unit',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountCtrl,
              decoration: InputDecoration(
                labelText: '$_amountLabel ($unit)',
                border: const OutlineInputBorder(),
              ),
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Введіть кількість';
                final d = double.tryParse(v.trim());
                if (d == null || d < 0) return 'Невірне значення';
                if (widget.actionType == QuantityActionType.writeOff &&
                    d > current) {
                  return 'Не можна списати більше, ніж є (${_fmt(current)})';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _commentCtrl,
              decoration: const InputDecoration(
                labelText: 'Коментар (необов\'язково)',
                border: OutlineInputBorder(),
              ),
            ),
            if (widget.actionType == QuantityActionType.correction)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Корекція — адміністративна правка залишку.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.orange[700],
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Скасувати'),
        ),
        FilledButton(
          onPressed: _confirm,
          child: Text(_title),
        ),
      ],
    );
  }
}
