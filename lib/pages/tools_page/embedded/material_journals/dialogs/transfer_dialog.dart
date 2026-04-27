import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../globals.dart';
import '../../../../../models/material_journal/material_item.dart';
import '../../../../../models/material_journal/material_journal.dart';
import '../../../../../services/material_journal_service.dart';

class TransferDialog extends StatefulWidget {
  final String fromJournalId;
  final MaterialItem fromItem;
  final VoidCallback onTransferred;

  const TransferDialog({
    super.key,
    required this.fromJournalId,
    required this.fromItem,
    required this.onTransferred,
  });

  @override
  State<TransferDialog> createState() => _TransferDialogState();
}

class _TransferDialogState extends State<TransferDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _commentCtrl = TextEditingController();

  List<MaterialJournal> _journals = [];
  List<MaterialItem> _targetItems = [];
  MaterialJournal? _targetJournal;
  MaterialItem? _targetItem;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadJournals();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadJournals() async {
    final groupId = Globals.profileManager.currentGroupId;
    if (groupId == null) return;
    final journals = await MaterialJournalService().getJournals(groupId);
    setState(() {
      _journals = journals
          .where((j) => j.id != widget.fromJournalId)
          .toList();
      _loading = false;
    });
  }

  Future<void> _onJournalSelected(MaterialJournal journal) async {
    setState(() {
      _targetJournal = journal;
      _targetItem = null;
      _targetItems = [];
    });
    final groupId = Globals.profileManager.currentGroupId!;
    final items = await MaterialJournalService().getItems(groupId, journal.id);
    setState(() {
      _targetItems = items
          .where((i) => i.name == widget.fromItem.name)
          .toList();
    });
  }

  String _fmt(double v) {
    if (v == v.truncateToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(2);
  }

  Future<void> _transfer() async {
    if (!_formKey.currentState!.validate()) return;
    if (_targetJournal == null || _targetItem == null) return;
    final groupId = Globals.profileManager.currentGroupId;
    if (groupId == null) return;

    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    final comment = _commentCtrl.text.trim().isEmpty
        ? null
        : _commentCtrl.text.trim();
    final userName = Globals.profileManager.currentUserName;

    setState(() => _saving = true);
    try {
      await MaterialJournalService().transfer(
        groupId,
        widget.fromJournalId,
        widget.fromItem,
        _targetJournal!.id,
        _targetItem!,
        amount,
        comment,
        userName,
      );
      if (mounted) {
        Navigator.of(context).pop();
        widget.onTransferred();
      }
    } catch (e) {
      if (mounted) {
        Globals.errorNotificationManager.showError('Помилка переносу: $e');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unit = widget.fromItem.unit.label;
    return AlertDialog(
      title: Text('Перенести: ${widget.fromItem.name}'),
      content: _loading
          ? const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            )
          : SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Доступно: ${_fmt(widget.fromItem.quantity)} $unit',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<MaterialJournal>(
                      value: _targetJournal,
                      decoration: const InputDecoration(
                        labelText: 'Журнал призначення *',
                        border: OutlineInputBorder(),
                      ),
                      items: _journals
                          .map(
                            (j) => DropdownMenuItem(
                              value: j,
                              child: Text(j.name),
                            ),
                          )
                          .toList(),
                      onChanged: (j) {
                        if (j != null) _onJournalSelected(j);
                      },
                      validator: (v) => v == null ? 'Оберіть журнал' : null,
                    ),
                    if (_targetJournal != null) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<MaterialItem>(
                        value: _targetItem,
                        decoration: const InputDecoration(
                          labelText: 'Елемент у журналі *',
                          border: OutlineInputBorder(),
                        ),
                        items: _targetItems.isEmpty
                            ? []
                            : _targetItems
                                  .map(
                                    (i) => DropdownMenuItem(
                                      value: i,
                                      child: Text(
                                        '${i.name} (${_fmt(i.quantity)} ${i.unit.label})',
                                      ),
                                    ),
                                  )
                                  .toList(),
                        onChanged: (i) => setState(() => _targetItem = i),
                        validator: (v) =>
                            v == null ? 'Оберіть елемент' : null,
                        hint: _targetItems.isEmpty
                            ? const Text('Немає збігів за назвою')
                            : null,
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _amountCtrl,
                      decoration: InputDecoration(
                        labelText: 'Кількість ($unit) *',
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d*'),
                        ),
                      ],
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Введіть кількість';
                        }
                        final d = double.tryParse(v.trim());
                        if (d == null || d <= 0) return 'Невірне значення';
                        if (d > widget.fromItem.quantity) {
                          return 'Не вистачає (є ${_fmt(widget.fromItem.quantity)})';
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
          onPressed: _saving || _targetJournal == null || _targetItem == null
              ? null
              : _transfer,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Перенести'),
        ),
      ],
    );
  }
}
