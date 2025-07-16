import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../globals.dart';
import '../../../mixins/loading_state_mixin.dart';
import '../../../widgets/loading_indicator.dart';

class MaterialDialog extends StatefulWidget {
  final Map<String, dynamic>? material; // null для створення нового
  final VoidCallback onRefresh;

  const MaterialDialog({
    super.key,
    this.material,
    required this.onRefresh,
  });

  @override
  State<MaterialDialog> createState() => _MaterialDialogState();
}

class _MaterialDialogState extends State<MaterialDialog> with LoadingStateMixin {
  late final TextEditingController titleController;
  late final TextEditingController urlController;
  late final TextEditingController tagsController;
  
  final formKey = GlobalKey<FormState>();
  bool _urlValidated = false;
  String? _urlError;
  List<String> _suggestedTags = [];
  
  bool get isEditing => widget.material != null;

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController(text: widget.material?['title'] ?? '');
    urlController = TextEditingController(text: widget.material?['url'] ?? '');
    tagsController = TextEditingController(
      text: (widget.material?['tags'] as List<dynamic>?)?.join(', ') ?? '',
    );
    
    // Додаємо лістенер для валідації URL в реальному часі
    urlController.addListener(_validateUrl);
    
    // Завантажуємо популярні теги для автокомплиту
    _loadSuggestedTags();
  }

  @override
  void dispose() {
    titleController.dispose();
    urlController.dispose();
    tagsController.dispose();
    super.dispose();
  }

  Future<void> _loadSuggestedTags() async {
    try {
      final groupId = Globals.profileManager.currentGroupId;
      if (groupId == null) return;

      final docs = await Globals.firestoreManager.getDocumentsForGroup(
        groupId: groupId,
        collection: 'materials',
      );

      final allTags = <String>{};
      for (final doc in docs) {
        final data = doc.data() as Map<String, dynamic>;
        final tags = data['tags'] as List<dynamic>? ?? [];
        allTags.addAll(tags.cast<String>());
      }

      if (mounted) {
        setState(() {
          _suggestedTags = allTags.toList()..sort();
        });
      }
    } catch (e) {
      // Ігноруємо помилки завантаження тегів
    }
  }

  void _validateUrl() {
    final url = urlController.text.trim();
    if (url.isEmpty) {
      setState(() {
        _urlValidated = false;
        _urlError = null;
      });
      return;
    }

    final fileId = Globals.fileManager.extractFileId(url);
    setState(() {
      _urlValidated = fileId != null;
      _urlError = fileId == null ? 'Невалідне посилання на Google Drive' : null;
    });
  }

  Future<void> _pasteFromClipboard() async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      if (clipboardData?.text != null) {
        urlController.text = clipboardData!.text!;
      }
    } catch (e) {
      // Ігноруємо помилки буфера обміну
    }
  }

  Future<void> _saveMaterial() async {
    if (!formKey.currentState!.validate()) return;

    final title = titleController.text.trim();
    final url = urlController.text.trim();
    final tagsText = tagsController.text.trim();
    final tags = tagsText.isEmpty 
        ? <String>[]
        : tagsText.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    final fileId = Globals.fileManager.extractFileId(url);
    if (fileId == null) {
      setState(() {
        _urlError = 'Невалідне посилання на Google Drive';
      });
      return;
    }

    try {
      await withLoading('save', () async {
        final modifiedTime = DateTime.now().toIso8601String();
        final data = {
          'title': title,
          'url': url,
          'fileId': fileId,
          'tags': tags,
          'modifiedAt': modifiedTime,
        };

        if (isEditing) {
          // Отримуємо метадані для оновлення
          try {
            final metadata = await Globals.fileManager.getFileMetadata(fileId);
            data['modifiedAt'] = metadata.modifiedDate ?? modifiedTime;
          } catch (e) {
            // Якщо не вдалося отримати метадані, використовуємо поточний час
          }

          await Globals.firestoreManager.updateDocument(
            groupId: Globals.profileManager.currentGroupId!,
            collection: 'materials',
            docId: widget.material!['id'],
            data: data,
          );
        } else {
          await Globals.firestoreManager.createDocument(
            groupId: Globals.profileManager.currentGroupId!,
            collection: 'materials',
            data: data,
          );
        }

        if (mounted) {
          Navigator.pop(context);
          widget.onRefresh();
          
          Globals.errorNotificationManager.showSuccess(
            isEditing ? 'Матеріал оновлено' : 'Матеріал додано',
          );
        }
      });
    } catch (e) {
      if (mounted) {
        Globals.errorNotificationManager.showError(
          'Помилка збереження: $e',
        );
      }
    }
  }

  Widget _buildTagsField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: tagsController,
          decoration: const InputDecoration(
            labelText: 'Теги',
            hintText: 'через кому: навчання, методичка, презентація',
            border: OutlineInputBorder(),
            suffixIcon: Icon(Icons.local_offer_outlined),
          ),
          maxLines: 2,
          textInputAction: TextInputAction.done,
        ),
        if (_suggestedTags.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text(
            'Популярні теги:',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: _suggestedTags.take(10).map((tag) {
              return ActionChip(
                label: Text(tag),
                onPressed: () {
                  final currentTags = tagsController.text.trim();
                  final newTags = currentTags.isEmpty 
                      ? tag 
                      : '$currentTags, $tag';
                  tagsController.text = newTags;
                },
              );
            }).toList(),
          ),
        ],
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
          Text(isEditing ? 'Редагувати матеріал' : 'Додати матеріал'),
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
                // Назва
                TextFormField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Назва матеріалу *',
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
                
                // URL
                TextFormField(
                  controller: urlController,
                  decoration: InputDecoration(
                    labelText: 'Посилання на Google Drive *',
                    hintText: 'https://drive.google.com/file/d/...',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.link),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_urlValidated)
                          const Icon(Icons.check_circle, color: Colors.green)
                        else if (_urlError != null)
                          const Icon(Icons.error, color: Colors.red),
                        IconButton(
                          icon: const Icon(Icons.paste),
                          onPressed: isSaving ? null : _pasteFromClipboard,
                          tooltip: 'Вставити з буфера',
                        ),
                      ],
                    ),
                    errorText: _urlError,
                  ),
                  validator: (value) {
                    if (value?.trim().isEmpty ?? true) {
                      return 'Посилання обов\'язкове';
                    }
                    if (!_urlValidated) {
                      return 'Невалідне посилання на Google Drive';
                    }
                    return null;
                  },
                  textInputAction: TextInputAction.next,
                  enabled: !isSaving,
                ),
                
                const SizedBox(height: 16),
                
                // Теги
                _buildTagsField(),
                
                const SizedBox(height: 8),
                
                // Підказка
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, 
                           size: 16, 
                           color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Переконайтеся що файл має публічний доступ або доступ за посиланням',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: isSaving ? null : () => Navigator.pop(context),
          child: const Text('Скасувати'),
        ),
        ElevatedButton(
          onPressed: isSaving ? null : _saveMaterial,
          child: isSaving
              ? const LoadingIndicator(size: 16)
              : Text(isEditing ? 'Зберегти' : 'Додати'),
        ),
      ],
    );
  }
}

// Wrapper функції для зворотної сумісності
Future<void> showAddMaterialDialog(BuildContext context, VoidCallback onRefresh) async {
  return showDialog(
    context: context,
    builder: (context) => MaterialDialog(onRefresh: onRefresh),
  );
}

Future<void> showEditMaterialDialog(
  BuildContext context, 
  Map<String, dynamic> material, 
  VoidCallback onRefresh,
) async {
  return showDialog(
    context: context,
    builder: (context) => MaterialDialog(
      material: material,
      onRefresh: onRefresh,
    ),
  );
}