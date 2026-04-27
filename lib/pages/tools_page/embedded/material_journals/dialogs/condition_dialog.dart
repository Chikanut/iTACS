import 'package:flutter/material.dart';

import '../../../../../models/material_journal/material_item.dart';

class ConditionDialog extends StatefulWidget {
  final MaterialItem item;

  const ConditionDialog({super.key, required this.item});

  @override
  State<ConditionDialog> createState() => _ConditionDialogState();
}

class _ConditionDialogState extends State<ConditionDialog> {
  late ItemCondition _condition;
  final _commentCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _condition = widget.item.condition;
    _commentCtrl.text = widget.item.conditionComment;
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Стан: ${widget.item.name}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...ItemCondition.values.map(
            (c) => RadioListTile<ItemCondition>(
              value: c,
              groupValue: _condition,
              title: Text(c.label),
              onChanged: (v) => setState(() => _condition = v!),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _commentCtrl,
            decoration: const InputDecoration(
              labelText: 'Коментар (необов\'язково)',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Скасувати'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop((
            condition: _condition,
            comment: _commentCtrl.text.trim().isEmpty
                ? null
                : _commentCtrl.text.trim(),
          )),
          child: const Text('Зберегти'),
        ),
      ],
    );
  }
}
