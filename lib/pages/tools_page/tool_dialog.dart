import 'package:flutter/material.dart';

import '../../globals.dart';
import '../../mixins/loading_state_mixin.dart';
import '../../widgets/loading_indicator.dart';
import 'tools_page.dart';

class ToolDialog extends StatefulWidget {
  const ToolDialog({
    super.key,
    this.isEditing = false,
    this.item,
    required this.onSave,
  });

  final bool isEditing;
  final Map<String, dynamic>? item;
  final VoidCallback onSave;

  @override
  State<ToolDialog> createState() => _ToolDialogState();
}

class _ToolDialogState extends State<ToolDialog> with LoadingStateMixin {
  final formKey = GlobalKey<FormState>();
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();

  String _selectedToolKey = 'contacts';
  IconData? selectedIcon;

  bool get isEditing => widget.isEditing;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    if (isEditing && item != null) {
      titleController.text = item['title']?.toString() ?? '';
      descriptionController.text = item['description']?.toString() ?? '';
      _selectedToolKey = item['toolKey']?.toString() ?? 'contacts';
      selectedIcon = iconFromData(item);
    } else {
      selectedIcon = Icons.widgets;
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectIcon() async {
    try {
      await withLoading('select_icon', () async {
        final icon = await showIconPickerDialog(context);
        if (icon != null && mounted) {
          setState(() {
            selectedIcon = icon;
          });
        }
      });
    } catch (e) {
      if (mounted) {
        Globals.errorNotificationManager.showError('Помилка вибору іконки: $e');
      }
    }
  }

  Future<void> _save() async {
    if (!formKey.currentState!.validate()) {
      return;
    }

    final title = titleController.text.trim();
    final description = descriptionController.text.trim();

    try {
      await withLoading('save', () async {
        final groupId = Globals.profileManager.currentGroupId;
        if (groupId == null) {
          throw Exception('Немає активної групи');
        }

        final data = <String, dynamic>{
          'title': title,
          'type': 'embedded',
          'toolKey': _selectedToolKey,
          'parentId': 'root',
          'modifiedAt': DateTime.now().toIso8601String(),
          'authorEmail': Globals.firebaseAuth.currentUser?.email ?? '',
        };

        if (description.isNotEmpty) {
          data['description'] = description;
        }

        if (selectedIcon != null) {
          data['icon'] = selectedIcon!.codePoint;
          data['iconFontFamily'] = selectedIcon!.fontFamily;
        }

        final overlayId = widget.item?['overlayId']?.toString().trim();
        final hasOverlayId = overlayId != null && overlayId.isNotEmpty;

        if (isEditing && hasOverlayId) {
          await Globals.firestoreManager.updateDocument(
            groupId: groupId,
            collection: 'tools_by_group',
            docId: overlayId,
            data: data,
          );
        } else {
          await Globals.firestoreManager.createDocument(
            groupId: groupId,
            collection: 'tools_by_group',
            data: data,
          );
        }

        if (mounted) {
          Navigator.of(context).pop();
          widget.onSave();
          Globals.errorNotificationManager.showSuccess(
            isEditing
                ? 'Вбудований інструмент оновлено'
                : 'Вбудований інструмент створено',
          );
        }
      });
    } catch (e) {
      if (mounted) {
        Globals.errorNotificationManager.showError('Помилка збереження: $e');
      }
    }
  }

  Widget _buildEmbeddedControls() {
    const availableTools = [
      ('checklist_builder', 'Конструктор чеклістів занять', Icons.check_circle),
      ('contacts', 'Корисні контакти', Icons.contacts),
      ('schedule_calculator', 'Калькулятор розкладу', Icons.calculate),
      ('material_journals', 'Журнали матбази', Icons.inventory_2),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Тип вбудованого інструмента:',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        ...availableTools.map(
          (tool) => RadioListTile<String>(
            value: tool.$1,
            groupValue: _selectedToolKey,
            onChanged: isLoading('save')
                ? null
                : (value) =>
                      setState(() => _selectedToolKey = value ?? 'contacts'),
            title: Row(
              children: [
                Icon(tool.$3, color: Colors.purple),
                const SizedBox(width: 8),
                Text(tool.$2),
              ],
            ),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  Widget _buildIconSelector() {
    final isSelectingIcon = isLoading('select_icon');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Іконка:', style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: (selectedIcon != null ? Colors.blue : Colors.grey)
                    .withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (selectedIcon != null ? Colors.blue : Colors.grey)
                      .withOpacity(0.3),
                ),
              ),
              child: isSelectingIcon
                  ? const LoadingIndicator(size: 24)
                  : Icon(
                      selectedIcon ?? Icons.help_outline,
                      size: 28,
                      color: selectedIcon != null
                          ? Colors.blue[700]
                          : Colors.grey,
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: isLoading('save') || isSelectingIcon
                    ? null
                    : _selectIcon,
                icon: isSelectingIcon
                    ? const LoadingIndicator(size: 16)
                    : const Icon(Icons.palette),
                label: Text(
                  isSelectingIcon ? 'Завантаження...' : 'Вибрати іконку',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = isLoading('save');

    return AlertDialog(
      title: Row(
        children: [
          Icon(isEditing ? Icons.edit : Icons.add),
          const SizedBox(width: 8),
          Text(
            isEditing
                ? 'Редагувати вбудований інструмент'
                : 'Новий вбудований інструмент',
          ),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Назва *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.title),
                  ),
                  validator: (value) {
                    if (value?.trim().isEmpty ?? true) {
                      return 'Назва обов\'язкова';
                    }
                    return null;
                  },
                  enabled: !isSaving,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Опис (необов\'язково)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.description),
                  ),
                  maxLines: 2,
                  enabled: !isSaving,
                ),
                const SizedBox(height: 16),
                _buildEmbeddedControls(),
                const SizedBox(height: 20),
                _buildIconSelector(),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Скасувати'),
        ),
        ElevatedButton(
          onPressed: isSaving ? null : _save,
          child: isSaving
              ? const LoadingIndicator(size: 16)
              : Text(isEditing ? 'Зберегти' : 'Створити'),
        ),
      ],
    );
  }
}
