import 'package:flutter/material.dart';

import '../../../../../globals.dart';
import '../../../../../services/material_journal_service.dart';

class JournalDialog extends StatefulWidget {
  final String? journalId;
  final String? initialName;
  final String? initialDescription;
  final VoidCallback onSaved;

  const JournalDialog({
    super.key,
    this.journalId,
    this.initialName,
    this.initialDescription,
    required this.onSaved,
  });

  bool get isEditing => journalId != null;

  @override
  State<JournalDialog> createState() => _JournalDialogState();
}

class _JournalDialogState extends State<JournalDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName ?? '');
    _descCtrl = TextEditingController(text: widget.initialDescription ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final groupId = Globals.profileManager.currentGroupId;
    if (groupId == null) return;

    setState(() => _saving = true);
    try {
      final service = MaterialJournalService();
      if (widget.isEditing) {
        await service.updateJournal(
          groupId,
          widget.journalId!,
          _nameCtrl.text.trim(),
          _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        );
      } else {
        await service.createJournal(
          groupId,
          _nameCtrl.text.trim(),
          _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        );
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
    return AlertDialog(
      title: Text(widget.isEditing ? 'Редагувати журнал' : 'Новий журнал'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Назва локації *',
                hintText: 'напр. Псих-смуга',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Введіть назву' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'Опис (необов\'язково)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
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
