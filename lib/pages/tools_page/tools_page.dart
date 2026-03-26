import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../globals.dart';
import '../../mixins/loading_state_mixin.dart';
import '../../services/tools_service.dart';
import '../../widgets/loading_indicator.dart';
import 'tool_dialog.dart';
import 'tool_tile.dart';

class _ToolPathNode {
  const _ToolPathNode({
    required this.parentId,
    required this.title,
    this.driveFolderId,
  });

  final String parentId;
  final String title;
  final String? driveFolderId;

  bool get isRoot => parentId == 'root';

  _ToolPathNode copyWith({
    String? parentId,
    String? title,
    String? driveFolderId,
  }) {
    return _ToolPathNode(
      parentId: parentId ?? this.parentId,
      title: title ?? this.title,
      driveFolderId: driveFolderId ?? this.driveFolderId,
    );
  }
}

IconData iconFromData(Map<String, dynamic> item, bool isFolder) {
  if (item['icon'] != null && item['iconFontFamily'] != null) {
    try {
      final iconCode = item['icon'];
      final fontFamily = item['iconFontFamily'];

      if (iconCode is int && fontFamily == 'MaterialIcons') {
        return _iconMap[iconCode] ??
            (isFolder ? Icons.folder : _fallbackIconForType(item));
      }
    } catch (_) {}
  }
  return isFolder ? Icons.folder : _fallbackIconForType(item);
}

IconData _fallbackIconForType(Map<String, dynamic> item) {
  final type = (item['type'] ?? 'tool').toString();
  if (type == 'external_link') {
    return Icons.open_in_new;
  }
  return Icons.web;
}

const Map<int, IconData> _iconMap = {
  0xe047: Icons.web,
  0xe86f: Icons.code,
  0xe1ae: Icons.calculate,
  0xe3f6: Icons.lightbulb,
  0xe873: Icons.description,
  0xe192: Icons.access_time,
  0xe5ca: Icons.check_circle,
  0xe80c: Icons.school,
  0xe4e9: Icons.construction,
  0xe412: Icons.camera,
  0xe55b: Icons.map,
  0xe63e: Icons.wifi,
  0xe855: Icons.alarm,
  0xe868: Icons.bug_report,
  0xe865: Icons.book,
  0xe566: Icons.directions_run,
  0xe2c4: Icons.download,
  0xe3c9: Icons.edit,
  0xe87a: Icons.explore,
  0xe173: Icons.file_copy,
  0xe89e: Icons.open_in_new,
};

Future<IconData?> showIconPickerDialog(BuildContext context) async {
  const allIcons = [
    Icons.web,
    Icons.code,
    Icons.calculate,
    Icons.lightbulb,
    Icons.description,
    Icons.access_time,
    Icons.check_circle,
    Icons.school,
    Icons.construction,
    Icons.camera,
    Icons.map,
    Icons.wifi,
    Icons.alarm,
    Icons.bug_report,
    Icons.book,
    Icons.directions_run,
    Icons.download,
    Icons.edit,
    Icons.explore,
    Icons.file_copy,
    Icons.open_in_new,
  ];

  return showDialog<IconData>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.palette),
          SizedBox(width: 8),
          Text('Виберіть іконку'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            childAspectRatio: 1,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: allIcons.length,
          itemBuilder: (context, index) {
            final iconData = allIcons[index];
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Navigator.of(context).pop(iconData),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(iconData, size: 28),
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Скасувати'),
        ),
      ],
    ),
  );
}

class ToolsPage extends StatefulWidget {
  const ToolsPage({super.key});

  @override
  State<ToolsPage> createState() => _ToolsPageState();
}

class _ToolsPageState extends State<ToolsPage> with LoadingStateMixin {
  final ToolsService _toolsService = ToolsService();

  List<_ToolPathNode> _pathStack = const [
    _ToolPathNode(parentId: 'root', title: 'Головна'),
  ];
  List<Map<String, dynamic>> currentItems = [];
  String? searchQuery;
  final TextEditingController searchController = TextEditingController();

  _ToolPathNode get _currentNode => _pathStack.last;

  @override
  void initState() {
    super.initState();
    _hydrateCachedItems();
    unawaited(fetchItems());
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _ensureRootDriveFolderId(String groupId) async {
    if (!_currentNode.isRoot && _currentNode.driveFolderId != null) {
      return;
    }

    final rootDriveFolderId = await _toolsService.getToolsRootFolderId(groupId);
    if (!mounted || rootDriveFolderId == null || !_currentNode.isRoot) {
      return;
    }

    setState(() {
      _pathStack = [
        _pathStack.first.copyWith(driveFolderId: rootDriveFolderId),
        ..._pathStack.skip(1),
      ];
    });
  }

  Future<void> fetchItems() async {
    try {
      await withLoading('fetch', () async {
        final groupId = Globals.profileManager.currentGroupId;
        if (groupId == null) {
          return;
        }

        await _ensureRootDriveFolderId(groupId);
        final currentNode = _currentNode;
        final items = await _toolsService.getItems(
          groupId: groupId,
          parentId: currentNode.parentId,
          driveFolderId: currentNode.driveFolderId,
          forceRefresh: true,
        );

        if (mounted) {
          setState(() {
            currentItems = items;
          });
        }
      });
    } catch (e) {
      debugPrint('[tools] fetchItems ERROR: $e');
      if (mounted) {
        Globals.errorNotificationManager.showError(
          'Помилка завантаження інструментів: $e',
        );
      }
    }
  }

  void _hydrateCachedItems() {
    final groupId = Globals.profileManager.currentGroupId;
    if (groupId == null) {
      return;
    }

    final cachedItems = _toolsService.getCachedItems(
      groupId: groupId,
      parentId: _currentNode.parentId,
    );
    if (cachedItems.isEmpty) {
      return;
    }

    setState(() {
      currentItems = cachedItems;
    });
  }

  Future<void> navigateToFolder(Map<String, dynamic> folderItem) async {
    final driveFolderId = folderItem['driveFolderId']?.toString().trim();
    if (driveFolderId == null || driveFolderId.isEmpty) {
      Globals.errorNotificationManager.showError(
        'Не вдалося визначити Google Drive папку для цього елемента',
      );
      return;
    }

    final overlayId = folderItem['overlayId']?.toString().trim();
    final parentId = overlayId != null && overlayId.isNotEmpty
        ? overlayId
        : '__drive__:$driveFolderId';

    setState(() {
      _pathStack = [
        ..._pathStack,
        _ToolPathNode(
          parentId: parentId,
          title: folderItem['title']?.toString() ?? 'Невідома папка',
          driveFolderId: driveFolderId,
        ),
      ];
    });

    _hydrateCachedItems();
    await fetchItems();
  }

  void goBack() {
    if (_pathStack.length <= 1) {
      return;
    }

    setState(() {
      _pathStack = _pathStack
          .take(_pathStack.length - 1)
          .toList(growable: false);
    });
    _hydrateCachedItems();
    unawaited(fetchItems());
  }

  Future<void> openTool(Map<String, dynamic> item) async {
    final type = (item['type'] ?? 'tool').toString();
    if (type == 'external_link') {
      final rawUrl = (item['url'] ?? '').toString().trim();
      final uri = Uri.tryParse(rawUrl);
      if (uri == null) {
        Globals.errorNotificationManager.showError(
          'Посилання інструмента має некоректний формат',
        );
        return;
      }

      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        Globals.errorNotificationManager.showError(
          'Не вдалося відкрити зовнішнє посилання',
        );
      }
      return;
    }

    final fileId = item['fileId'] as String?;
    if (fileId == null || fileId.trim().isEmpty) {
      return;
    }

    try {
      await withLoading('open_${item['id']}', () async {
        await Globals.fileManager.openFile(fileId);
      });
    } catch (e) {
      if (mounted) {
        Globals.errorNotificationManager.showError(
          'Не вдалося відкрити файл: $e',
        );
      }
    }
  }

  Future<void> editItem(Map<String, dynamic> item) async {
    await showDialog(
      context: context,
      builder: (_) => ToolDialog(
        isEditing: true,
        item: item,
        parentId: _currentNode.parentId,
        currentDriveFolderId: _currentNode.driveFolderId,
        onSave: fetchItems,
      ),
    );
  }

  Future<void> deleteItem(Map<String, dynamic> item) async {
    try {
      await withLoading('delete_${item['id']}', () async {
        final groupId = Globals.profileManager.currentGroupId;
        final userRole = Globals.profileManager.currentRole;
        if (groupId == null || userRole == null) {
          return;
        }

        final overlayId = item['overlayId']?.toString().trim();
        final type = (item['type'] ?? 'tool').toString();

        Future<void> deleteOverlayTree(String docId) async {
          final children = await Globals.firestoreManager.getDocumentsForGroup(
            groupId: groupId,
            collection: 'tools_by_group',
            whereEqual: {'parentId': docId},
          );

          for (final child in children) {
            await deleteOverlayTree(child.id);
          }

          await Globals.firestoreManager.deleteDocumentWhereAllowed(
            docId: docId,
            groupId: groupId,
            userRole: userRole,
            collection: 'tools_by_group',
          );
        }

        Future<void> deleteOverlayChildrenForParent(String parentDocId) async {
          final children = await Globals.firestoreManager.getDocumentsForGroup(
            groupId: groupId,
            collection: 'tools_by_group',
            whereEqual: {'parentId': parentDocId},
          );

          for (final child in children) {
            final childData = Map<String, dynamic>.from(
              child.data() as Map<String, dynamic>,
            );
            final childType = (childData['type'] ?? 'tool').toString();

            if (childType == 'folder') {
              await deleteOverlayTree(child.id);
              continue;
            }

            await Globals.firestoreManager.deleteDocumentWhereAllowed(
              docId: child.id,
              groupId: groupId,
              userRole: userRole,
              collection: 'tools_by_group',
            );
          }
        }

        if (type == 'folder') {
          final driveFolderId = item['driveFolderId']?.toString().trim();
          if (driveFolderId != null && driveFolderId.isNotEmpty) {
            await Globals.googleDriveService.deleteItem(driveFolderId);
          }

          if (overlayId != null && overlayId.isNotEmpty) {
            await deleteOverlayTree(overlayId);
          } else if (driveFolderId != null && driveFolderId.isNotEmpty) {
            await deleteOverlayChildrenForParent('__drive__:$driveFolderId');
          }
        } else if (type == 'external_link') {
          if (overlayId != null && overlayId.isNotEmpty) {
            await Globals.firestoreManager.deleteDocumentWhereAllowed(
              docId: overlayId,
              groupId: groupId,
              userRole: userRole,
              collection: 'tools_by_group',
            );
          }
        } else {
          final fileId = item['fileId']?.toString().trim();
          if (fileId != null && fileId.isNotEmpty) {
            await Globals.googleDriveService.deleteItem(fileId);
          }

          if (overlayId != null && overlayId.isNotEmpty) {
            await Globals.firestoreManager.deleteDocumentWhereAllowed(
              docId: overlayId,
              groupId: groupId,
              userRole: userRole,
              collection: 'tools_by_group',
            );
          }
        }

        if (mounted) {
          await fetchItems();
          Globals.errorNotificationManager.showSuccess(
            '${type == 'folder' ? 'Папку' : 'Інструмент'} "${item['title']}" видалено',
          );
        }
      });
    } catch (e) {
      debugPrint('[tools] deleteItem ERROR: $e');
      if (mounted) {
        Globals.errorNotificationManager.showError('Не вдалося видалити: $e');
      }
    }
  }

  Future<void> showAddDialog() async {
    await showDialog(
      context: context,
      builder: (_) => ToolDialog(
        parentId: _currentNode.parentId,
        currentDriveFolderId: _currentNode.driveFolderId,
        onSave: fetchItems,
      ),
    );
  }

  List<Map<String, dynamic>> get filteredItems {
    if (searchQuery == null || searchQuery!.isEmpty) {
      return currentItems;
    }

    final query = searchQuery!.toLowerCase();
    return currentItems
        .where((item) {
          final title = (item['title'] ?? '').toString().toLowerCase();
          final description = (item['description'] ?? '')
              .toString()
              .toLowerCase();
          return title.contains(query) || description.contains(query);
        })
        .toList(growable: false);
  }

  Widget _buildBreadcrumbs() {
    final parts = <Widget>[];

    for (int i = 0; i < _pathStack.length; i++) {
      final node = _pathStack[i];
      final isLast = i == _pathStack.length - 1;

      if (i > 0) {
        parts.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Icon(Icons.chevron_right, size: 16, color: Colors.grey[600]),
          ),
        );
      }

      parts.add(
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isLast || isLoading('navigate')
                ? null
                : () {
                    setState(() {
                      _pathStack = _pathStack
                          .take(i + 1)
                          .toList(growable: false);
                    });
                    _hydrateCachedItems();
                    unawaited(fetchItems());
                  },
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (i == 0) ...[
                    Icon(Icons.home, size: 16, color: Colors.blue[700]),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    node.title,
                    style: TextStyle(
                      color: Colors.blue[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.05),
        border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.2))),
      ),
      child: Row(
        children: [
          Icon(Icons.folder_open, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: parts),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: searchController,
        decoration: InputDecoration(
          hintText: 'Пошук інструментів...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: searchQuery != null && searchQuery!.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      searchQuery = null;
                      searchController.clear();
                    });
                  },
                )
              : null,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        onChanged: (value) {
          setState(() {
            searchQuery = value.trim().isEmpty ? null : value.trim();
          });
        },
      ),
    );
  }

  Widget _buildStatsInfo() {
    final totalItems = currentItems.length;
    final folders = currentItems
        .where((item) => (item['type'] ?? 'tool') == 'folder')
        .length;
    final tools = totalItems - folders;
    final filteredCount = filteredItems.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          if (searchQuery != null && searchQuery!.isNotEmpty)
            Text(
              'Знайдено $filteredCount з $totalItems елементів',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            )
          else
            Text(
              '$folders папок • $tools інструментів',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    if (searchQuery != null && searchQuery!.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Нічого не знайдено',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Спробуйте змінити пошуковий запит',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    final isReadOnlyOffline = Globals.appRuntimeState.isReadOnlyOffline;
    final isAdmin =
        !isReadOnlyOffline && Globals.profileManager.currentRole != 'viewer';

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.build_circle,
            size: 64,
            color: Colors.grey.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            isReadOnlyOffline
                ? 'Офлайн-копія інструментів відсутня'
                : 'Інструменти відсутні',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            isReadOnlyOffline
                ? 'Під час наступного онлайн-сеансу каталог буде збережено для швидкого відкриття.'
                : 'Додайте перший інструмент або папку',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
          ),
          if (isAdmin) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: showAddDialog,
              icon: const Icon(Icons.add),
              label: const Text('Додати інструмент'),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin =
        !Globals.appRuntimeState.isReadOnlyOffline &&
        Globals.profileManager.currentRole != 'viewer';
    final isNavigating = isLoading('navigate');
    final showBlockingLoader = isLoading('fetch') && currentItems.isEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Інструменти')),
      body: Column(
        children: [
          _buildBreadcrumbs(),
          _buildSearchBar(),
          _buildStatsInfo(),
          Expanded(
            child: showBlockingLoader
                ? const Center(
                    child: LoadingIndicator(
                      message: 'Завантаження інструментів...',
                      showBackground: true,
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: fetchItems,
                    child: filteredItems.isEmpty
                        ? _buildEmptyState()
                        : GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount:
                                      MediaQuery.of(context).size.width > 600
                                      ? 3
                                      : 2,
                                  childAspectRatio: 1.1,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                ),
                            itemCount:
                                filteredItems.length +
                                (_pathStack.length > 1 ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (_pathStack.length > 1 && index == 0) {
                                return Card(
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: isNavigating ? null : goBack,
                                      borderRadius: BorderRadius.circular(12),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Container(
                                              width: 48,
                                              height: 48,
                                              decoration: BoxDecoration(
                                                color: Colors.grey.withOpacity(
                                                  0.1,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: isNavigating
                                                  ? const LoadingIndicator(
                                                      size: 24,
                                                    )
                                                  : const Icon(
                                                      Icons.arrow_back,
                                                      size: 24,
                                                    ),
                                            ),
                                            const SizedBox(height: 8),
                                            const Text(
                                              'Назад',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }

                              final itemIndex = _pathStack.length > 1
                                  ? index - 1
                                  : index;
                              final item = filteredItems[itemIndex];
                              final itemType = (item['type'] ?? 'tool')
                                  .toString();
                              final isFolder = itemType == 'folder';
                              final hasDriveBacking = isFolder
                                  ? (item['driveFolderId']
                                            ?.toString()
                                            .trim()
                                            .isNotEmpty ==
                                        true)
                                  : (item['fileId']
                                            ?.toString()
                                            .trim()
                                            .isNotEmpty ==
                                        true);
                              final canEditItem =
                                  itemType == 'external_link' ||
                                  hasDriveBacking;
                              final canDeleteItem =
                                  itemType == 'external_link' ||
                                  hasDriveBacking;

                              return ToolTile(
                                title: item['title']?.toString() ?? '',
                                description: item['description']?.toString(),
                                icon: iconFromData(item, isFolder),
                                isFolder: isFolder,
                                itemType: itemType,
                                isAdmin: isAdmin,
                                canEdit: canEditItem,
                                canDelete: canDeleteItem,
                                fileId: isFolder
                                    ? null
                                    : item['fileId']?.toString(),
                                linkUrl: itemType == 'external_link'
                                    ? item['url']?.toString()
                                    : null,
                                isFileLoading: isLoading('open_${item['id']}'),
                                onTap: () async {
                                  if (isFolder) {
                                    await navigateToFolder(item);
                                  } else {
                                    await openTool(item);
                                    await fetchItems();
                                  }
                                },
                                onEdit: canEditItem
                                    ? () => editItem(item)
                                    : null,
                                onDelete: canDeleteItem
                                    ? () => deleteItem(item)
                                    : null,
                                onStatusChanged: () => setState(() {}),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              onPressed: showAddDialog,
              tooltip: 'Додати інструмент або папку',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
