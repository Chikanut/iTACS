import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../globals.dart';
import 'tools_page.dart';
import '../../../mixins/loading_state_mixin.dart';
import '../../../widgets/loading_indicator.dart';

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

class _ToolDialogState extends State<ToolDialog> with LoadingStateMixin {
  final titleController = TextEditingController();
  final fileIdController = TextEditingController();
  final descriptionController = TextEditingController();
  final formKey = GlobalKey<FormState>();
  
  String selectedType = 'tool';
  IconData? selectedIcon;
  bool _fileIdValidated = false;
  String? _fileIdError;

  bool get isEditing => widget.isEditing;
  bool get isFolder => selectedType == 'folder';

  @override
  void initState() {
    super.initState();
    if (isEditing && widget.item != null) {
      final item = widget.item!;
      titleController.text = item['title'] ?? '';
      fileIdController.text = item['fileId'] ?? '';
      descriptionController.text = item['description'] ?? '';
      selectedType = item['type'] ?? 'tool';
      
      // Відновлюємо іконку
      selectedIcon = iconFromData(item, selectedType == 'folder');
    } else {
      // Дефолтні іконки для нових елементів
      selectedIcon = selectedType == 'folder' ? Icons.folder : Icons.web;
    }
    
    // Валідація fileId в реальному часі
    fileIdController.addListener(_validateFileId);
  }

  @override
  void dispose() {
    titleController.dispose();
    fileIdController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  void _validateFileId() {
    if (isFolder) {
      setState(() {
        _fileIdValidated = true;
        _fileIdError = null;
      });
      return;
    }

    final fileId = fileIdController.text.trim();
    if (fileId.isEmpty) {
      setState(() {
        _fileIdValidated = false;
        _fileIdError = null;
      });
      return;
    }

    // Перевіряємо формат Google Drive fileId
    final isValid = RegExp(r'^[a-zA-Z0-9_-]{25,}$').hasMatch(fileId);
    setState(() {
      _fileIdValidated = isValid;
      _fileIdError = isValid ? null : 'Невірний формат fileId';
    });
  }

  Future<void> _pasteFromClipboard() async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      if (clipboardData?.text != null) {
        final text = clipboardData!.text!;
        
        // Якщо це повний URL до Google Drive, витягуємо fileId
        final fileId = Globals.fileManager.extractFileId(text) ?? text;
        fileIdController.text = fileId;
      }
    } catch (e) {
      // Ігноруємо помилки буфера обміну
    }
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
    if (!formKey.currentState!.validate()) return;

    final title = titleController.text.trim();
    final fileId = fileIdController.text.trim();
    final description = descriptionController.text.trim();

    if (!isFolder && !_fileIdValidated) {
      setState(() {
        _fileIdError = 'Невірний формат fileId';
      });
      return;
    }

    try {
      await withLoading('save', () async {
        final groupId = Globals.profileManager.currentGroupId;
        if (groupId == null) {
          throw Exception('Немає активної групи');
        }

        final data = <String, dynamic>{
          'title': title,
          'type': selectedType,
          'parentId': widget.parentId,
          'modifiedAt': DateTime.now().toIso8601String(),
          'authorEmail': Globals.firebaseAuth.currentUser?.email ?? '',
        };

        if (description.isNotEmpty) {
          data['description'] = description;
        }

        if (!isFolder) {
          data['fileId'] = fileId;
        }

        if (selectedIcon != null) {
          data['icon'] = selectedIcon!.codePoint;
          data['iconFontFamily'] = selectedIcon!.fontFamily;
        }

        if (isEditing && widget.item != null) {
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

        if (mounted) {
          Navigator.of(context).pop();
          widget.onSave();
          
          Globals.errorNotificationManager.showSuccess(
            isEditing 
                ? '${isFolder ? 'Папку' : 'Інструмент'} оновлено'
                : '${isFolder ? 'Папку' : 'Інструмент'} створено',
          );
        }
      });
    } catch (e) {
      if (mounted) {
        Globals.errorNotificationManager.showError('Помилка збереження: $e');
      }
    }
  }

  Widget _buildTypeSelector() {
    // При редагуванні не дозволяємо змінювати тип
    if (isEditing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Тип елемента:',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  isFolder ? Icons.folder : Icons.build,
                  color: isFolder ? Colors.amber[700] : Colors.blue[700],
                ),
                const SizedBox(width: 12),
                Text(
                  isFolder ? 'Папка' : 'Інструмент',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'не змінюється',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // При створенні дозволяємо вибирати тип
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Тип елемента:',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: RadioListTile<String>(
                value: 'folder',
                groupValue: selectedType,
                onChanged: isLoading('save') ? null : (value) {
                  setState(() {
                    selectedType = value ?? 'tool';
                    selectedIcon = selectedType == 'folder' 
                        ? Icons.folder 
                        : Icons.web;
                  });
                },
                title: const Row(
                  children: [
                    Icon(Icons.folder, color: Colors.amber),
                    SizedBox(width: 8),
                    Text('Папка'),
                  ],
                ),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            Expanded(
              child: RadioListTile<String>(
                value: 'tool',
                groupValue: selectedType,
                onChanged: isLoading('save') ? null : (value) {
                  setState(() {
                    selectedType = value ?? 'tool';
                    selectedIcon = selectedType == 'folder' 
                        ? Icons.folder 
                        : Icons.web;
                  });
                },
                title: const Row(
                  children: [
                    Icon(Icons.build, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Інструмент'),
                  ],
                ),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildIconSelector() {
    final isSelectingIcon = isLoading('select_icon');
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Іконка:',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: (selectedIcon != null 
                    ? (isFolder ? Colors.amber : Colors.blue) 
                    : Colors.grey).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (selectedIcon != null 
                      ? (isFolder ? Colors.amber : Colors.blue) 
                      : Colors.grey).withOpacity(0.3),
                ),
              ),
              child: isSelectingIcon
                  ? const LoadingIndicator(size: 24)
                  : Icon(
                      selectedIcon ?? Icons.help_outline,
                      size: 28,
                      color: selectedIcon != null 
                          ? (isFolder ? Colors.amber[700] : Colors.blue[700]) 
                          : Colors.grey,
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: isLoading('save') || isSelectingIcon ? null : _selectIcon,
                icon: isSelectingIcon 
                    ? const LoadingIndicator(size: 16)
                    : const Icon(Icons.palette),
                label: Text(isSelectingIcon ? 'Завантаження...' : 'Вибрати іконку'),
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
          Text(isEditing 
              ? isFolder ? 'Редагувати папку' : 'Редагувати інструмент'
              : isFolder ? 'Нова папка' : 'Новий інструмент'),
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
                // Тип елемента
                _buildTypeSelector(),
                
                const SizedBox(height: 20),
                
                // Назва
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
                  textInputAction: TextInputAction.next,
                  enabled: !isSaving,
                ),
                
                const SizedBox(height: 16),
                
                // Опис
                TextFormField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Опис (необов\'язково)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.description),
                  ),
                  maxLines: 2,
                  textInputAction: isFolder ? TextInputAction.done : TextInputAction.next,
                  enabled: !isSaving,
                ),
                
                // FileId для інструментів
                if (!isFolder) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: fileIdController,
                    decoration: InputDecoration(
                      labelText: 'Google Drive File ID *',
                      hintText: '1ABC...xyz',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.link),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_fileIdValidated)
                            const Icon(Icons.check_circle, color: Colors.green)
                          else if (_fileIdError != null)
                            const Icon(Icons.error, color: Colors.red),
                          IconButton(
                            icon: const Icon(Icons.paste),
                            onPressed: isSaving ? null : _pasteFromClipboard,
                            tooltip: 'Вставити з буфера',
                          ),
                        ],
                      ),
                      errorText: _fileIdError,
                    ),
                    validator: (value) {
                      if (value?.trim().isEmpty ?? true) {
                        return 'File ID обов\'язковий для інструментів';
                      }
                      if (!_fileIdValidated) {
                        return 'Невірний формат File ID';
                      }
                      return null;
                    },
                    textInputAction: TextInputAction.done,
                    enabled: !isSaving,
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Підказка
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.blue.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, 
                             size: 16, 
                             color: Colors.blue.shade700),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Можна вставити повне посилання - File ID буде витягнуто автоматично',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                const SizedBox(height: 20),
                
                // Вибір іконки
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