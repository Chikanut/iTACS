import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../globals.dart';
import '../../mixins/loading_state_mixin.dart';
import '../../services/local_file_picker_service.dart';
import '../../widgets/loading_indicator.dart';
import 'tools_page.dart';

class ToolDialog extends StatefulWidget {
  const ToolDialog({
    super.key,
    this.isEditing = false,
    this.item,
    required this.parentId,
    this.currentDriveFolderId,
    required this.onSave,
  });

  final bool isEditing;
  final Map<String, dynamic>? item;
  final String parentId;
  final String? currentDriveFolderId;
  final VoidCallback onSave;

  @override
  State<ToolDialog> createState() => _ToolDialogState();
}

class _ToolDialogState extends State<ToolDialog> with LoadingStateMixin {
  final LocalFilePickerService _filePickerService = LocalFilePickerService();
  final formKey = GlobalKey<FormState>();

  final titleController = TextEditingController();
  final fileIdController = TextEditingController();
  final urlController = TextEditingController();
  final descriptionController = TextEditingController();

  String selectedType = 'tool';
  String _selectedToolKey = 'contacts';
  IconData? selectedIcon;
  bool _fileIdValidated = false;
  String? _fileIdError;
  bool _useManualFileId = false;
  XFile? _selectedFile;

  bool get isEditing => widget.isEditing;
  bool get isFolder => selectedType == 'folder';
  bool get isExternalLink => selectedType == 'external_link';
  bool get isToolFile => selectedType == 'tool';
  bool get isEmbedded => selectedType == 'embedded';

  String? get _existingFileId {
    final item = widget.item;
    if (item == null) {
      return null;
    }

    final directFileId = item['fileId']?.toString().trim();
    if (directFileId != null && directFileId.isNotEmpty) {
      return directFileId;
    }

    return Globals.fileManager.extractFileId((item['url'] ?? '').toString());
  }

  String? get _existingDriveFolderId =>
      widget.item?['driveFolderId']?.toString().trim();

  bool get _canUploadToCurrentDriveFolder =>
      widget.currentDriveFolderId != null &&
      widget.currentDriveFolderId!.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (isEditing && widget.item != null) {
      final item = widget.item!;
      titleController.text = item['title']?.toString() ?? '';
      fileIdController.text = item['fileId']?.toString() ?? '';
      urlController.text = item['url']?.toString() ?? '';
      descriptionController.text = item['description']?.toString() ?? '';
      selectedType = item['type']?.toString() ?? 'tool';
      selectedIcon = iconFromData(item, selectedType == 'folder');
      if (selectedType == 'embedded') {
        _selectedToolKey = item['toolKey']?.toString() ?? 'contacts';
      }
      _useManualFileId =
          selectedType == 'tool' &&
          (!_canUploadToCurrentDriveFolder || (_existingFileId == null));
    } else {
      selectedIcon = Icons.web;
      _useManualFileId = !_canUploadToCurrentDriveFolder;
    }

    fileIdController.addListener(_validateFileId);
    _validateFileId();
  }

  @override
  void dispose() {
    titleController.dispose();
    fileIdController.dispose();
    urlController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  void _validateFileId() {
    if (!isToolFile) {
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

    final isValid = RegExp(r'^[a-zA-Z0-9_-]{25,}$').hasMatch(fileId);
    setState(() {
      _fileIdValidated = isValid;
      _fileIdError = isValid ? null : 'Невірний формат fileId';
    });
  }

  Future<void> _pasteFromClipboard() async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      if (clipboardData?.text == null) {
        return;
      }

      final text = clipboardData!.text!;
      if (isExternalLink) {
        urlController.text = text;
        return;
      }

      final fileId = Globals.fileManager.extractFileId(text) ?? text;
      fileIdController.text = fileId;
    } catch (_) {}
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
          'type': selectedType,
          'parentId': widget.parentId,
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

        if (isFolder) {
          String? driveFolderId = _existingDriveFolderId;
          if (!isEditing) {
            if (!_canUploadToCurrentDriveFolder) {
              throw Exception(
                'Для створення папки потрібен активний Google Drive folder id у каталозі групи',
              );
            }

            final createdFolder = await Globals.googleDriveService.createFolder(
              parentFolderId: widget.currentDriveFolderId!,
              name: title,
            );
            driveFolderId = createdFolder.id;
            data['modifiedAt'] =
                createdFolder.modifiedTime ?? data['modifiedAt'];
          } else if (driveFolderId != null && driveFolderId.isNotEmpty) {
            final updatedFolder = await Globals.googleDriveService
                .updateFileMetadata(fileId: driveFolderId, name: title);
            data['modifiedAt'] =
                updatedFolder.modifiedTime ?? data['modifiedAt'];
          }

          if (driveFolderId != null && driveFolderId.isNotEmpty) {
            data['driveFolderId'] = driveFolderId;
          }
        } else if (isToolFile) {
          String? fileId = _existingFileId;
          if (_useManualFileId || !_canUploadToCurrentDriveFolder) {
            final manualFileId = fileIdController.text.trim();
            if (manualFileId.isNotEmpty) {
              fileId = manualFileId;
            }

            if (fileId == null || fileId.isEmpty) {
              throw Exception(
                'Потрібно вказати fileId або вибрати локальний файл',
              );
            }

            data['fileId'] = fileId;
            data['url'] = Globals.googleDriveService.buildLegacyViewUrl(fileId);
          } else {
            if (_selectedFile != null) {
              final file = _selectedFile!;
              final bytes = await file.readAsBytes();
              final mimeType = _filePickerService.inferMimeType(file.name);

              final driveFile = isEditing && fileId != null && fileId.isNotEmpty
                  ? await Globals.googleDriveService.updateFileContent(
                      fileId: fileId,
                      fileName: file.name,
                      bytes: bytes,
                      mimeType: mimeType,
                    )
                  : await Globals.googleDriveService.uploadFile(
                      parentFolderId: widget.currentDriveFolderId!,
                      fileName: file.name,
                      bytes: bytes,
                      mimeType: mimeType,
                    );

              fileId = driveFile.id;
              data['modifiedAt'] = driveFile.modifiedTime ?? data['modifiedAt'];
            } else if (!isEditing || fileId == null || fileId.isEmpty) {
              throw Exception(
                'Оберіть локальний файл для завантаження або ввімкніть ручний fileId',
              );
            }

            data['fileId'] = fileId;
            data['url'] = Globals.googleDriveService.buildLegacyViewUrl(fileId);
          }
        } else if (isExternalLink) {
          final url = urlController.text.trim();
          final uri = Uri.tryParse(url);
          if (uri == null || !uri.hasScheme) {
            throw Exception('Для зовнішнього інструмента потрібне валідне URL');
          }

          data['url'] = url;
          data.remove('fileId');
        } else if (isEmbedded) {
          data['toolKey'] = _selectedToolKey;
          data.remove('fileId');
          data.remove('url');
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

          final label = isFolder
              ? 'Папку'
              : isEmbedded
              ? 'Вбудований інструмент'
              : 'Інструмент';
          Globals.errorNotificationManager.showSuccess(
            isEditing ? '$label оновлено' : '$label створено',
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
    if (isEditing) {
      final label = switch (selectedType) {
        'folder' => 'Папка',
        'external_link' => 'Зовнішнє посилання',
        'embedded' => 'Вбудований інструмент',
        _ => 'Інструмент',
      };

      final icon = switch (selectedType) {
        'folder' => Icons.folder,
        'external_link' => Icons.open_in_new,
        'embedded' => Icons.widgets,
        _ => Icons.build,
      };

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
                Icon(icon),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Тип елемента:',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Column(
          children: [
            RadioListTile<String>(
              value: 'folder',
              groupValue: selectedType,
              onChanged: isLoading('save')
                  ? null
                  : (value) {
                      setState(() {
                        selectedType = value ?? 'tool';
                        selectedIcon = Icons.folder;
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
            RadioListTile<String>(
              value: 'tool',
              groupValue: selectedType,
              onChanged: isLoading('save')
                  ? null
                  : (value) {
                      setState(() {
                        selectedType = value ?? 'tool';
                        selectedIcon = Icons.web;
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
            RadioListTile<String>(
              value: 'external_link',
              groupValue: selectedType,
              onChanged: isLoading('save')
                  ? null
                  : (value) {
                      setState(() {
                        selectedType = value ?? 'external_link';
                        selectedIcon = Icons.open_in_new;
                      });
                    },
              title: const Row(
                children: [
                  Icon(Icons.open_in_new, color: Colors.teal),
                  SizedBox(width: 8),
                  Text('Зовнішнє посилання'),
                ],
              ),
              contentPadding: EdgeInsets.zero,
            ),
            RadioListTile<String>(
              value: 'embedded',
              groupValue: selectedType,
              onChanged: isLoading('save')
                  ? null
                  : (value) {
                      setState(() {
                        selectedType = value ?? 'embedded';
                        selectedIcon = Icons.widgets;
                      });
                    },
              title: const Row(
                children: [
                  Icon(Icons.widgets, color: Colors.purple),
                  SizedBox(width: 8),
                  Text('Вбудований інструмент'),
                ],
              ),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmbeddedControls() {
    const availableTools = [
      ('checklist_builder', 'Конструктор чеклістів занять', Icons.check_circle),
      ('contacts', 'Корисні контакти', Icons.contacts),
      ('schedule_calculator', 'Калькулятор розкладу', Icons.calculate),
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
                : (v) => setState(() => _selectedToolKey = v ?? 'contacts'),
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
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.purple.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.purple.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: Colors.purple[700]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Вбудований інструмент відкривається у вигляді вбудованого екрана всередині додатку.',
                  style: TextStyle(fontSize: 12, color: Colors.purple[800]),
                ),
              ),
            ],
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

  Widget _buildToolSourceControls() {
    final existingFileId = _existingFileId;
    final isPicking = isLoading('pick_file');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile.adaptive(
          value: _useManualFileId,
          contentPadding: EdgeInsets.zero,
          title: const Text('Використати ручний fileId'),
          subtitle: Text(
            _canUploadToCurrentDriveFolder
                ? 'За замовчуванням файл вантажиться в поточну Google Drive папку.'
                : 'Поточна Drive папка не визначена, тому доступний лише legacy fallback.',
          ),
          onChanged: (!_canUploadToCurrentDriveFolder && !_useManualFileId)
              ? null
              : (value) {
                  setState(() {
                    _useManualFileId = value;
                  });
                },
        ),
        const SizedBox(height: 8),
        if (_useManualFileId) ...[
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
                    onPressed: isLoading('save') ? null : _pasteFromClipboard,
                    tooltip: 'Вставити з буфера',
                  ),
                ],
              ),
              errorText: _fileIdError,
            ),
            validator: (value) {
              if (!_useManualFileId) {
                return null;
              }

              if ((value?.trim().isEmpty ?? true) &&
                  !(isEditing &&
                      existingFileId != null &&
                      existingFileId.isNotEmpty)) {
                return 'File ID обов\'язковий для legacy-режиму';
              }
              if (value!.trim().isNotEmpty && !_fileIdValidated) {
                return 'Невірний формат File ID';
              }
              return null;
            },
            enabled: !isLoading('save'),
          ),
        ] else ...[
          Container(
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
                            ? 'Файл уже прив\'язаний до інструмента'
                            : 'Локальний файл ще не обрано',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    if (_selectedFile != null)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: isPicking
                            ? null
                            : () {
                                setState(() {
                                  _selectedFile = null;
                                });
                              },
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: isPicking ? null : _pickLocalFile,
                  icon: isPicking
                      ? const LoadingIndicator(size: 16)
                      : const Icon(Icons.folder_open),
                  label: Text(
                    _selectedFile != null || existingFileId != null
                        ? 'Замінити файл'
                        : 'Обрати файл',
                  ),
                ),
              ],
            ),
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
          Text(
            isEditing
                ? isFolder
                      ? 'Редагувати папку'
                      : isEmbedded
                      ? 'Редагувати вбудований інструмент'
                      : 'Редагувати інструмент'
                : 'Новий елемент',
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
                _buildTypeSelector(),
                const SizedBox(height: 20),
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
                if (isToolFile) ...[
                  const SizedBox(height: 16),
                  _buildToolSourceControls(),
                ],
                if (isExternalLink) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: urlController,
                    decoration: InputDecoration(
                      labelText: 'URL *',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.link),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.paste),
                        onPressed: isSaving ? null : _pasteFromClipboard,
                        tooltip: 'Вставити з буфера',
                      ),
                    ),
                    validator: (value) {
                      if (!isExternalLink) {
                        return null;
                      }

                      final text = value?.trim() ?? '';
                      final uri = Uri.tryParse(text);
                      if (text.isEmpty) {
                        return 'URL обов\'язковий';
                      }
                      if (uri == null || !uri.hasScheme) {
                        return 'Вкажіть валідний URL';
                      }
                      return null;
                    },
                    enabled: !isSaving,
                  ),
                ],
                if (isEmbedded) ...[
                  const SizedBox(height: 16),
                  _buildEmbeddedControls(),
                ],
                if (isFolder &&
                    !_canUploadToCurrentDriveFolder &&
                    !isEditing) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Для створення папки потрібно, щоб для поточної групи був налаштований toolsRootFolderId або батьківська Drive папка.',
                    style: TextStyle(fontSize: 12, color: Colors.orange[800]),
                  ),
                ],
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
