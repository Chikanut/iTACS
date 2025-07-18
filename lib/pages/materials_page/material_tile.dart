import 'package:flutter/material.dart';

import 'material_dialogs.dart';
import '../../../globals.dart';
import '../../../mixins/loading_state_mixin.dart';
import '../../../widgets/loading_indicator.dart';

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

class _MaterialTileState extends State<MaterialTile> with LoadingStateMixin {
  late bool isSaved = false;
  late String? fileId;
  DateTime? _lastModified;

  @override
  void initState() {
    super.initState();
    final url = widget.material['url'] ?? '';
    fileId = Globals.fileManager.extractFileId(url);
    _lastModified = _parseModifiedDate();
    _checkDownloaded();
  }

  DateTime? _parseModifiedDate() {
    final modifiedAt = widget.material['modifiedAt'];
    if (modifiedAt is String) {
      try {
        return DateTime.parse(modifiedAt);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  String get _formattedDate {
    if (_lastModified == null) return '';
    
    final now = DateTime.now();
    final difference = now.difference(_lastModified!);
    
    if (difference.inDays == 0) {
      return 'сьогодні';
    } else if (difference.inDays == 1) {
      return 'вчора';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} днів тому';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? 'тиждень' : 'тижні'} тому';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months ${months == 1 ? 'місяць' : 'місяці'} тому';
    } else {
      final years = (difference.inDays / 365).floor();
      return '$years ${years == 1 ? 'рік' : 'роки'} тому';
    }
  }

  Future<void> _checkDownloaded() async {
    if (fileId != null) {
      final saved = await Globals.fileManager.isCached(fileId!);
      if (mounted) {
        setState(() {
          isSaved = saved;
        });
      }
    }
  }

  Future<void> _downloadFile() async {
    if (fileId == null) {
      Globals.errorNotificationManager.showError('Неможливо знайти файл для завантаження.');
      return;
    }
    
    try {
      await withLoading('download_$fileId', () async {
        await Globals.fileManager.cacheFile(fileId!);
        
        if (mounted) {
          Globals.errorNotificationManager.showSuccess('Файл збережено локально');
          await _checkDownloaded();
          widget.onRefresh();
        }
      });
    } catch (e) {
      if (mounted) {
        Globals.errorNotificationManager.showError('Помилка завантаження: $e');
      }
    }
  }

  Future<void> _openFile() async {
    if (fileId == null) return;
    
    try {
      await withLoading('open_$fileId', () async {
        await Globals.fileManager.openFile(fileId!);
        
        if (mounted) {
          await _checkDownloaded();
        }
      });
    } catch (e) {
      if (mounted) {
        Globals.errorNotificationManager.showError('Помилка відкриття файлу: $e');
      }
    }
  }

  Future<void> _deleteFile() async {
    if (fileId == null) return;
    
    try {
      await withLoading('delete_$fileId', () async {
        await Globals.fileManager.removeFromCache(fileId!);
        
        if (mounted) {
          await _checkDownloaded();
          widget.onRefresh();
          Globals.errorNotificationManager.showSuccess('Локальний файл видалено');
        }
      });
    } catch (e) {
      if (mounted) {
        Globals.errorNotificationManager.showError('Помилка видалення файлу: $e');
      }
    }
  }

  Future<void> _deleteGlobally() async {
    final confirmed = await _showDeleteConfirmation();
    if (!confirmed) return;

    try {
      await withLoading('delete_global_$fileId', () async {
        final docId = widget.material['id'];
        final result = await Globals.firestoreManager.deleteDocumentWhereAllowed(
          docId: docId,
          groupId: Globals.profileManager.currentGroupId!,
          userRole: widget.userRole,
          collection: 'materials',
        );

        final deleted = (result['deleted'] as List);
        final skipped = (result['skipped'] as List);

        if (mounted) {
          if (deleted.isNotEmpty) {
            Globals.errorNotificationManager.showSuccess(
              'Видалено з ${deleted.length} ${deleted.length == 1 ? 'групи' : 'груп'}',
            );
          }

          if (skipped.isNotEmpty) {
            Globals.errorNotificationManager.showInfo(
              'Залишився в ${skipped.length} ${skipped.length == 1 ? 'групі' : 'групах'} (немає прав)',
            );
          }
          
          widget.onRefresh();
        }
      });
    } catch (e) {
      if (mounted) {
        Globals.errorNotificationManager.showError('Помилка видалення: $e');
      }
    }
  }

  Future<bool> _showDeleteConfirmation() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Підтвердження'),
        content: const Text(
          'Видалити цей матеріал з усіх груп де у вас є права адміністратора?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Скасувати'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Видалити'),
          ),
        ],
      ),
    ) ?? false;
  }

  IconData _getFileIcon() {
    final title = widget.material['title']?.toString().toLowerCase() ?? '';
    final url = widget.material['url']?.toString().toLowerCase() ?? '';
    
    // Визначаємо тип файлу за назвою або URL
    if (title.contains('презентац') || url.contains('presentation')) {
      return Icons.slideshow;
    } else if (title.contains('документ') || url.contains('document')) {
      return Icons.description;
    } else if (title.contains('таблиц') || url.contains('spreadsheets')) {
      return Icons.table_chart;
    } else if (title.contains('відео') || title.contains('video')) {
      return Icons.play_circle_outline;
    } else if (title.contains('зображен') || title.contains('фото')) {
      return Icons.image;
    } else {
      return Icons.insert_drive_file;
    }
  }

  Color _getStatusColor() {
    if (isSaved) return Colors.green;
    if (widget.isWeb) return Colors.blue;
    return Colors.grey;
  }

  Widget _buildStatusChip() {
    if (widget.isWeb) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.blue.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud, size: 12, color: Colors.blue[700]),
            const SizedBox(width: 2),
            Text(
              'онлайн',
              style: TextStyle(
                fontSize: 10,
                color: Colors.blue[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    } else if (isSaved) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.green.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.offline_pin, size: 12, color: Colors.green[700]),
            const SizedBox(width: 2),
            Text(
              'локально',
              style: TextStyle(
                fontSize: 10,
                color: Colors.green[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.material['title'] ?? 'Без назви';
    final tags = List<String>.from(widget.material['tags'] ?? []);
    final canEdit = widget.userRole == 'admin' || widget.userRole == 'editor';
    final isAdmin = widget.userRole == 'admin';

    final isDownloading = isLoading('download_$fileId');
    final isOpening = isLoading('open_$fileId');
    final isDeleting = isLoading('delete_$fileId');
    final isDeletingGlobal = isLoading('delete_global_$fileId');
    final isAnyLoading = isDownloading || isOpening || isDeleting || isDeletingGlobal;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: isAnyLoading ? 0.5 : 1,
      child: InkWell(
        onTap: isAnyLoading ? null : _openFile,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Іконка файлу з індикатором завантаження
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _getStatusColor().withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getFileIcon(),
                      color: _getStatusColor(),
                    ),
                  ),
                  if (isOpening)
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const LoadingIndicator(size: 20),
                    ),
                ],
              ),
              
              const SizedBox(width: 16),
              
              // Контент
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Заголовок
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: isAnyLoading ? Colors.grey : null,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    const SizedBox(height: 4),
                    
                    // Теги та статус
                    Row(
                      children: [
                        if (tags.isNotEmpty) ...[
                          Expanded(
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: tags.take(3).map((tag) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  tag,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isAnyLoading ? Colors.grey : Colors.grey[700],
                                  ),
                                ),
                              )).toList(),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        _buildStatusChip(),
                      ],
                    ),
                    
                    // Дата модифікації
                    if (_formattedDate.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Оновлено $_formattedDate',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              // Дії
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Кнопка завантаження
                  if (!widget.isWeb && !isSaved)
                    isDownloading
                        ? const Padding(
                            padding: EdgeInsets.all(8),
                            child: LoadingIndicator(size: 20),
                          )
                        : IconButton(
                            icon: const Icon(Icons.download),
                            onPressed: isAnyLoading ? null : _downloadFile,
                            tooltip: 'Завантажити локально',
                          ),
                  
                  // Меню дій
                  if (isSaved || canEdit)
                    isDeletingGlobal || isDeleting
                        ? const Padding(
                            padding: EdgeInsets.all(8),
                            child: LoadingIndicator(size: 20),
                          )
                        : PopupMenuButton<String>(
                            enabled: !isAnyLoading,
                            onSelected: (value) async {
                              switch (value) {
                                case 'edit':
                                  await showEditMaterialDialog(
                                    context,
                                    widget.material,
                                    widget.onRefresh,
                                  );
                                  break;
                                case 'delete':
                                  await _deleteFile();
                                  break;
                                case 'delete_global':
                                  await _deleteGlobally();
                                  break;
                              }
                            },
                            itemBuilder: (context) => [
                              if (canEdit)
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: ListTile(
                                    leading: Icon(Icons.edit),
                                    title: Text('Редагувати'),
                                    contentPadding: EdgeInsets.zero,
                                    dense: true,
                                  ),
                                ),
                              if (isAdmin)
                                const PopupMenuItem(
                                  value: 'delete_global',
                                  child: ListTile(
                                    leading: Icon(Icons.delete_forever, color: Colors.red),
                                    title: Text('Видалити з усіх груп'),
                                    contentPadding: EdgeInsets.zero,
                                    dense: true,
                                  ),
                                ),
                              if (isSaved)
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: ListTile(
                                    leading: Icon(Icons.delete_outline),
                                    title: Text('Видалити локально'),
                                    contentPadding: EdgeInsets.zero,
                                    dense: true,
                                  ),
                                ),
                            ],
                          ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}