import 'package:flutter/material.dart';
import '../../../globals.dart';
import 'tools_page.dart';

class ToolDialog extends StatefulWidget {
  final bool isEditing;
  final Map<String, dynamic>? item;
  final String parentId;
  final VoidCallback onSave;

  const ToolDialog({
    super.key,
    this.isEditing = false,
    this.item,
    required this.parentId,
    required this.onSave,
  });

  @override
  State<ToolDialog> createState() => _ToolDialogState();
}

class _ToolDialogState extends State<ToolDialog> {
  final titleController = TextEditingController();
  final fileIdController = TextEditingController();
  String selectedType = 'tool';
  IconData? selectedIcon;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing && widget.item != null) {
      final item = widget.item!;
      titleController.text = item['title'] ?? '';
      fileIdController.text = item['fileId'] ?? '';
      selectedType = item['type'] ?? 'tool';
      if (item['icon'] != null && item['iconFontFamily'] != null) {
        selectedIcon = IconData(item['icon'], fontFamily: item['iconFontFamily']);
      }
    }
  }

  Future<void> save() async {
    final title = titleController.text.trim();
    final fileId = fileIdController.text.trim();

    if (title.isEmpty || (selectedType == 'tool' && fileId.isEmpty)) {
      Globals.errorNotificationManager.showWarning("Заповніть усі обов'язкові поля");
      return;
    }

    final groupId = Globals.profileManager.currentGroupId;
    if (groupId == null) return;

    final data = <String, dynamic>{
      'title': title,
      'type': selectedType,
      'parentId': widget.parentId,
      'modifiedAt': DateTime.now().toIso8601String(),
      'authorEmail': Globals.firebaseAuth.currentUser?.email ?? '',
    };

    if (selectedType == 'tool') {
      data['fileId'] = fileId;
      if (selectedIcon != null) {
        data['icon'] = selectedIcon!.codePoint;
        data['iconFontFamily'] = selectedIcon!.fontFamily;
      }
    }

    try {
      if (widget.isEditing && widget.item != null) {
        await Globals.firestoreManager.updateDocument(
          groupId: groupId,
          collection: 'tools_by_group',
          docId: widget.item!['id'],
          data: data,
        );
      } else {
        await Globals.firestoreManager.createDocument(
          groupId: groupId,
          collection: 'tools_by_group',
          data: data,
        );
      }

      widget.onSave();
      Navigator.of(context).pop();
    } catch (e) {
      Globals.errorNotificationManager.showError("Помилка збереження: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isEditing ? 'Редагувати елемент' : 'Новий елемент'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: titleController,
            decoration: const InputDecoration(labelText: 'Назва'),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: selectedType,
            decoration: const InputDecoration(labelText: 'Тип'),
            items: const [
              DropdownMenuItem(value: 'tool', child: Text('Інструмент')),
              DropdownMenuItem(value: 'folder', child: Text('Папка')),
            ],
            onChanged: (value) {
              setState(() {
                selectedType = value ?? 'tool';
              });
            },
          ),
          if (selectedType == 'tool') ...[
            const SizedBox(height: 8),
            TextField(
              controller: fileIdController,
              decoration: const InputDecoration(labelText: 'fileId (Google Drive)'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Іконка:'),
                const SizedBox(width: 10),
                Icon(selectedIcon ?? Icons.web),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () async {
                    final icon = await showIconPickerDialog(context);
                    if (icon != null) {
                      setState(() {
                        selectedIcon = icon;
                      });
                    }
                  },
                  child: const Text('Вибрати'),
                )
              ],
            ),
          ]
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Скасувати'),
        ),
        ElevatedButton(
          onPressed: save,
          child: const Text('Зберегти'),
        ),
      ],
    );
  }
}