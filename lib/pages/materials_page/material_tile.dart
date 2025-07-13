import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'material_dialogs.dart';
import '../../../globals.dart';

class MaterialTile extends StatefulWidget {
  final Map<String, dynamic> material;
  final VoidCallback onRefresh;
  final bool isWeb;
  final String userRole;

  const MaterialTile({
    super.key,
    required this.material,
    required this.onRefresh,
    required this.isWeb,
    required this.userRole,
  });

  @override
  State<MaterialTile> createState() => _MaterialTileState();
}

class _MaterialTileState extends State<MaterialTile> {
  late bool isSaved = false;
  late String? fileId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final url = widget.material['url'] ?? '';
    fileId = Globals.fileManager.extractFileId(url);
    _checkDownloaded();
  }

  Future<void> _checkDownloaded() async {
    debugPrint('🔍 Перевірка чи файл завантажено: $fileId');
    final saved = await Globals.fileManager.isFileCached(fileId!);
    setState(() {
      isSaved = saved;
    });
  }

  Future<void> _downloadFile() async {
    if (fileId == null) {
      debugPrint('⚠️ Неможливо витягнути fileId з URL');
      Globals.errorNotificationManager.showError('Неможливо знайти файл для завантаження.');
      return;
    }
    debugPrint('⬇️ Запит на завантаження: ${widget.material['url']} (fileId: $fileId)');
    setState(() => _isLoading = true);
    try {
      await Globals.fileManager.downloadFile(fileId!);
      debugPrint('✅ Файл успішно завантажено');
      Globals.errorNotificationManager.showSuccess('Файл успішно завантажено');
      await _checkDownloaded();
      widget.onRefresh();
    } catch (e, stack) {
      debugPrint('❌ Помилка при завантаженні: $e');
      Globals.errorNotificationManager.showCriticalError(
        title: 'Помилка завантаження',
        message: 'Не вдалося завантажити файл.',
        details: e.toString(),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteFile() async {
    debugPrint('🗑 Видалення локального файлу: $fileId');
    await Globals.fileManager.removeCachedData(fileId!);
    await _checkDownloaded();
    widget.onRefresh();
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.material['url'] ?? '';
    final title = widget.material['title'] ?? 'файл';
    final tags = List<String>.from(widget.material['tags'] ?? []);
    final userRole = widget.userRole;
    final canEdit = userRole == 'admin' || userRole == 'editor';
    final isAdmin = userRole == 'admin';

    return ListTile(
      title: Text(title),
      subtitle: Text(tags.join(', ')),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!widget.isWeb)
            _isLoading
                ? const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    icon: Icon(isSaved ? Icons.system_update : Icons.download),
                    onPressed: _downloadFile,
                  ),
      if ((isSaved || canEdit))
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'edit' && canEdit) {
                debugPrint('✏️ Редагування матеріалу');
                await showEditMaterialDialog(context, widget.material, widget.onRefresh);
              } else if (value == 'delete') {
                await _deleteFile();
              } else if (value == 'delete_global' && isAdmin) {
              final docId = widget.material['id'];
            final result = await Globals.firestoreManager.deleteDocumentWhereAllowed(
              docId: docId,
              groupId: Globals.profileManager.currentGroupId!,
              userRole: widget.userRole,
              collection: 'materials',
            );

              final deleted = (result['deleted'] as List).join(', ');
              final skipped = (result['skipped'] as List).join(', ');

              if (deleted.isNotEmpty) {
                Globals.errorNotificationManager.showSuccess('Видалено з груп: $deleted');
              }

              if (skipped.isNotEmpty) {
                Globals.errorNotificationManager.showInfo(
                  'Файл залишився в групах: $skipped (немає прав admin)',
                );
              }
              widget.onRefresh();
            }
            },
            itemBuilder: (context) => [
              if (canEdit)
                const PopupMenuItem(value: 'edit', child: Text('Редагувати')),
              if (isAdmin)
                const PopupMenuItem(value: 'delete_global', child: Text('Видалити з усіх груп')),
              if (isSaved)
                const PopupMenuItem(value: 'delete', child: Text('Видалити локальні файли')),
            ],
          ),
        ],
      ),
      onTap: () async {
        debugPrint('📂 Відкриття файлу або посилання');
        await Globals.fileManager.openFile(fileId!);
      },
    );
  }
}
