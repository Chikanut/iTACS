import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../globals.dart';
import '../../mixins/loading_state_mixin.dart';
import '../../services/local_file_picker_service.dart';
import '../../widgets/loading_indicator.dart';

class MaterialDialog extends StatefulWidget {
  const MaterialDialog({super.key, this.material, required this.onRefresh});

  final Map<String, dynamic>? material;
  final VoidCallback onRefresh;

  @override
  State<MaterialDialog> createState() => _MaterialDialogState();
}

class _MaterialDialogState extends State<MaterialDialog>
    with LoadingStateMixin {
  final LocalFilePickerService _filePickerService = LocalFilePickerService();
  final formKey = GlobalKey<FormState>();

  late final TextEditingController titleController;
  late final TextEditingController urlController;
  late final TextEditingController tagsController;

  XFile? _selectedFile;
  String? _materialsFolderId;
  bool _useManualLink = false;
  bool _urlValidated = false;
  String? _urlError;
  List<String> _suggestedTags = [];

  bool get isEditing => widget.material != null;

  String? get _existingFileId {
    final material = widget.material;
    if (material == null) {
      return null;
    }

    final directFileId = material['fileId']?.toString().trim();
    if (directFileId != null && directFileId.isNotEmpty) {
      return directFileId;
    }

    return Globals.fileManager.extractFileId(
      (material['url'] ?? '').toString(),
    );
  }

  bool get _canUseDriveUpload =>
      _materialsFolderId != null && _materialsFolderId!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController(
      text: widget.material?['title']?.toString() ?? '',
    );
    urlController = TextEditingController(
      text: widget.material?['url']?.toString() ?? '',
    );
    tagsController = TextEditingController(
      text: (widget.material?['tags'] as List<dynamic>?)?.join(', ') ?? '',
    );

    urlController.addListener(_validateUrl);
    _loadSuggestedTags();
    _loadCatalogConfig();
    _validateUrl();
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
      if (groupId == null) {
        return;
      }

      final docs = await Globals.firestoreManager.getDocumentsForGroup(
        groupId: groupId,
        collection: 'materials',
      );

      final allTags = <String>{};
      for (final doc in docs) {
        final data = doc.data() as Map<String, dynamic>;
        final tags = data['tags'] as List<dynamic>? ?? const [];
        allTags.addAll(tags.cast<String>());
      }

      if (mounted) {
        setState(() {
          _suggestedTags = allTags.toList()..sort();
        });
      }
    } catch (e) {
      debugPrint('MaterialDialog: failed to load suggested tags: $e');
    }
  }

  Future<void> _loadCatalogConfig() async {
    try {
      final groupId = Globals.profileManager.currentGroupId;
      if (groupId == null) {
        return;
      }

      final config = await Globals.driveCatalogService.getConfig(groupId);
      if (!mounted) {
        return;
      }

      setState(() {
        _materialsFolderId = config?.materialsFolderId;
        if (!_canUseDriveUpload && !isEditing) {
          _useManualLink = true;
        }
      });
    } catch (e) {
      debugPrint('MaterialDialog: failed to load catalog config: $e');
      if (mounted) setState(() => _useManualLink = true);
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

  Future<void> _pickLocalFile() async {
    try {
      await withLoading('pick_file', () async {
        final file = await _filePickerService.pickSingleFile();
        if (file == null || !mounted) {
          return;
        }

        setState(() {
          _selectedFile = file;
          if (titleController.text.trim().isEmpty) {
            titleController.text = _filePickerService.titleFromFileName(
              file.name,
            );
          }
        });
      });
    } catch (e) {
      if (mounted) {
        Globals.errorNotificationManager.showError(
          'Не вдалося вибрати файл: $e',
        );
      }
    }
  }

  Future<void> _pasteFromClipboard() async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      if (clipboardData?.text != null) {
        urlController.text = clipboardData!.text!;
      }
    } catch (e) {
      debugPrint('MaterialDialog: clipboard read failed: $e');
    }
  }

  Future<void> _saveMaterial() async {
    if (!formKey.currentState!.validate()) {
      return;
    }

    final title = titleController.text.trim();
    final tags = tagsController.text
        .split(',')
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toList(growable: false);

    try {
      await withLoading('save', () async {
        final groupId = Globals.profileManager.currentGroupId;
        if (groupId == null) {
          throw Exception('Немає активної групи');
        }

        String? fileId = _existingFileId;
        String? url = urlController.text.trim().isEmpty
            ? null
            : urlController.text.trim();
        String modifiedAt = DateTime.now().toIso8601String();

        if (!_useManualLink && _canUseDriveUpload) {
          if (_selectedFile != null) {
            final pickedFile = _selectedFile!;
            final bytes = await pickedFile.readAsBytes();
            final mimeType = _filePickerService.inferMimeType(pickedFile.name);

            final driveFile = isEditing && fileId != null && fileId.isNotEmpty
                ? await Globals.googleDriveService.updateFileContent(
                    fileId: fileId,
                    fileName: pickedFile.name,
                    bytes: bytes,
                    mimeType: mimeType,
                  )
                : await Globals.googleDriveService.uploadFile(
                    parentFolderId: _materialsFolderId!,
                    fileName: pickedFile.name,
                    bytes: bytes,
                    mimeType: mimeType,
                  );

            fileId = driveFile.id;
            url = Globals.googleDriveService.buildLegacyViewUrl(driveFile.id);
            modifiedAt = driveFile.modifiedTime ?? modifiedAt;
          } else if (!isEditing || fileId == null || fileId.isEmpty) {
            throw Exception(
              'Оберіть локальний файл для завантаження або ввімкніть legacy-посилання',
            );
          } else {
            url = Globals.googleDriveService.buildLegacyViewUrl(fileId);
            try {
              final metadata = await Globals.fileManager.getFileMetadata(
                fileId,
              );
              modifiedAt = metadata.modifiedDate;
            } catch (e) {
              debugPrint(
                'MaterialDialog: could not fetch file metadata for $fileId: $e',
              );
              // modifiedAt stays as DateTime.now() — acceptable fallback
            }
          }
        } else {
          final manualUrl = urlController.text.trim();
          if (manualUrl.isNotEmpty) {
            fileId = Globals.fileManager.extractFileId(manualUrl);
            if (fileId == null) {
              throw Exception('Невалідне посилання на Google Drive');
            }
            url = manualUrl;
          } else if (fileId != null && fileId.isNotEmpty) {
            url = Globals.googleDriveService.buildLegacyViewUrl(fileId);
          } else {
            throw Exception('Потрібно вказати посилання на файл');
          }

          try {
            final metadata = await Globals.fileManager.getFileMetadata(fileId);
            modifiedAt = metadata.modifiedDate;
          } catch (e) {
            debugPrint(
              'MaterialDialog: could not fetch metadata for manual url: $e',
            );
            // modifiedAt stays as DateTime.now() — acceptable fallback
          }
        }

        final data = <String, dynamic>{
          'title': title,
          'fileId': fileId,
          'url': url,
          'tags': tags,
          'modifiedAt': modifiedAt,
        };

        final overlayId = widget.material?['overlayId']?.toString().trim();
        final hasOverlayId = overlayId != null && overlayId.isNotEmpty;

        if (isEditing && hasOverlayId) {
          await Globals.firestoreManager.updateDocument(
            groupId: groupId,
            collection: 'materials',
            docId: overlayId,
            data: data,
          );
        } else {
          await Globals.firestoreManager.createDocument(
            groupId: groupId,
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
        Globals.errorNotificationManager.showError('Помилка збереження: $e');
      }
    }
  }

  Widget _buildUploadModeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Джерело файлу:',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        SwitchListTile.adaptive(
          value: _useManualLink,
          contentPadding: EdgeInsets.zero,
          title: const Text('Використати legacy-посилання'),
          subtitle: Text(
            _canUseDriveUpload
                ? 'За замовчуванням файл вантажиться напряму в Google Drive папку групи.'
                : 'Drive folder config не знайдено, тому доступний лише legacy fallback.',
          ),
          onChanged: (!_canUseDriveUpload && !_useManualLink)
              ? null
              : (value) {
                  setState(() {
                    _useManualLink = value;
                  });
                },
        ),
      ],
    );
  }

  Widget _buildFilePickerCard() {
    final existingFileId = _existingFileId;
    final isPickingFile = isLoading('pick_file');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.upload_file),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _selectedFile != null
                      ? _selectedFile!.name
                      : existingFileId != null
                      ? 'Файл уже прив\'язаний до матеріалу'
                      : 'Локальний файл ще не обрано',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              if (_selectedFile != null)
                IconButton(
                  onPressed: isPickingFile
                      ? null
                      : () {
                          setState(() {
                            _selectedFile = null;
                          });
                        },
                  icon: const Icon(Icons.clear),
                  tooltip: 'Очистити вибір',
                ),
            ],
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: isPickingFile ? null : _pickLocalFile,
            icon: isPickingFile
                ? const LoadingIndicator(size: 16)
                : const Icon(Icons.folder_open),
            label: Text(
              _selectedFile != null || existingFileId != null
                  ? 'Замінити файл'
                  : 'Обрати файл',
            ),
          ),
          if (!_canUseDriveUpload) ...[
            const SizedBox(height: 8),
            Text(
              'Щоб працював прямий upload, додайте `materialsFolderId` у `drive_catalog_by_group/{groupId}`.',
              style: TextStyle(fontSize: 12, color: Colors.orange[800]),
            ),
          ],
        ],
      ),
    );
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
            children: _suggestedTags
                .take(10)
                .map((tag) {
                  return ActionChip(
                    label: Text(tag),
                    onPressed: () {
                      final currentTags = tagsController.text.trim();
                      tagsController.text = currentTags.isEmpty
                          ? tag
                          : '$currentTags, $tag';
                    },
                  );
                })
                .toList(growable: false),
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
                _buildUploadModeSelector(),
                const SizedBox(height: 16),
                TextFormField(
                  controller: titleController,
                  enabled: !isSaving,
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
                ),
                const SizedBox(height: 16),
                if (_useManualLink) ...[
                  TextFormField(
                    controller: urlController,
                    enabled: !isSaving,
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
                      if (!_useManualLink) {
                        return null;
                      }
                      if (value?.trim().isEmpty ?? true) {
                        return 'Посилання обов\'язкове в legacy-режимі';
                      }
                      if (!_urlValidated) {
                        return 'Невалідне посилання на Google Drive';
                      }
                      return null;
                    },
                  ),
                ] else ...[
                  _buildFilePickerCard(),
                ],
                const SizedBox(height: 16),
                _buildTagsField(),
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

Future<void> showAddMaterialDialog(
  BuildContext context,
  VoidCallback onRefresh,
) async {
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
    builder: (context) =>
        MaterialDialog(material: material, onRefresh: onRefresh),
  );
}
