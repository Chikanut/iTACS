import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../globals.dart';
import '../../../mixins/loading_state_mixin.dart';
import '../../../widgets/loading_indicator.dart';
import 'tool_dialog.dart';
import 'tool_tile.dart';

IconData iconFromData(Map<String, dynamic> item, bool isFolder) {
  if (item['icon'] != null && item['iconFontFamily'] != null) {
    try {
      final iconCode = item['icon'];
      final fontFamily = item['iconFontFamily'];
      
      if (iconCode is int && fontFamily == 'MaterialIcons') {
        // Повертаємо константну іконку з Map
        return _iconMap[iconCode] ?? (isFolder ? Icons.folder : Icons.web);
      }
    } catch (e) {
      // Fallback
    }
  }
  return isFolder ? Icons.folder : Icons.web;
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
  List<String> pathStack = ['root'];
  List<Map<String, dynamic>> pathMeta = [];
  List<Map<String, dynamic>> currentItems = [];
  String? searchQuery;
  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchItems();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> fetchItems() async {
    try {
      await withLoading('fetch', () async {
        final groupId = Globals.profileManager.currentGroupId;
        final parentId = pathStack.last;

        debugPrint('[tools] fetchItems: groupId=$groupId, parentId=$parentId');

        if (groupId == null) return;

        final docs = await Globals.firestoreManager.getDocumentsForGroup(
          groupId: groupId,
          collection: 'tools_by_group',
          whereEqual: {'parentId': parentId},
          orderBy: 'modifiedAt',
        );

        if (mounted) {
          setState(() {
            currentItems = docs
                .map((d) => {
                      ...d.data() as Map<String, dynamic>,
                      'id': d.id,
                    })
                .toList();
          });

          debugPrint('[tools] documents loaded: ${currentItems.length}');
        }
      });
    } catch (e) {
      debugPrint('[tools] fetchItems ERROR: $e');
      if (mounted) {
        Globals.errorNotificationManager.showError('Помилка завантаження інструментів: $e');
      }
    }
  }

  Future<void> navigateToFolder(String folderId) async {
    try {
      await withLoading('navigate', () async {
        pathStack.add(folderId);

        final groupId = Globals.profileManager.currentGroupId;
        if (groupId != null) {
          final snapshot = await FirebaseFirestore.instance
              .collection('tools_by_group')
              .doc(groupId)
              .collection('items')
              .doc(folderId)
              .get();

          if (snapshot.exists) {
            pathMeta.add({'id': folderId, 'title': snapshot['title']});
          } else {
            pathMeta.add({'id': folderId, 'title': 'Невідома папка'});
          }
        }

        await fetchItems();
      });
    } catch (e) {
      if (mounted) {
        Globals.errorNotificationManager.showError('Помилка навігації: $e');
      }
    }
  }

  void goBack() {
    if (pathStack.length > 1) {
      pathStack.removeLast();
      pathMeta.removeLast();
      fetchItems();
    }
  }

  Future<void> openTool(Map<String, dynamic> item) async {
    final fileId = item['fileId'] as String?;
    if (fileId == null) return;

    try {
      await withLoading('open_${item['id']}', () async {
        await Globals.fileManager.openFile(fileId);
      });
    } catch (e) {
      if (mounted) {
        Globals.errorNotificationManager.showError("Не вдалося відкрити файл: $e");
      }
    }
  }

  Future<void> editItem(Map<String, dynamic> item) async {
    await showDialog(
      context: context,
      builder: (_) => ToolDialog(
        isEditing: true,
        item: item,
        parentId: pathStack.last,
        onSave: fetchItems,
      ),
    );
  }

  Future<void> deleteItem(Map<String, dynamic> item) async {
    try {
      await withLoading('delete_${item['id']}', () async {
        final groupId = Globals.profileManager.currentGroupId;
        final userRole = Globals.profileManager.currentRole;
        if (groupId == null || userRole == null) return;

        debugPrint('[tools] deleteItem: id=${item['id']}, groupId=$groupId, role=$userRole');

        Future<void> deleteRecursively(String docId) async {
          final children = await Globals.firestoreManager.getDocumentsForGroup(
            groupId: groupId,
            collection: 'tools_by_group',
            whereEqual: {'parentId': docId},
          );

          for (final child in children) {
            final childData = child.data() as Map<String, dynamic>;
            final childId = child.id;
            if (childData['type'] == 'folder') {
              await deleteRecursively(childId);
            }
            await Globals.firestoreManager.deleteDocumentWhereAllowed(
              docId: childId,
              groupId: groupId,
              userRole: userRole,
              collection: 'tools_by_group',
            );
            debugPrint('[tools] deleted child: ${childData['title']}');
          }

          await Globals.firestoreManager.deleteDocumentWhereAllowed(
            docId: docId,
            groupId: groupId,
            userRole: userRole,
            collection: 'tools_by_group',
          );
        }

        await deleteRecursively(item['id']);
        debugPrint('[tools] deleteItem success: ${item['title']}');
        
        if (mounted) {
          await fetchItems();
          Globals.errorNotificationManager.showSuccess(
            '${item['type'] == 'folder' ? 'Папку' : 'Інструмент'} "${item['title']}" видалено',
          );
        }
      });
    } catch (e) {
      debugPrint('[tools] deleteItem ERROR: $e');
      if (mounted) {
        Globals.errorNotificationManager.showError("Не вдалося видалити: $e");
      }
    }
  }

  Future<void> showAddDialog() async {
    await showDialog(
      context: context,
      builder: (_) => ToolDialog(
        parentId: pathStack.last,
        onSave: fetchItems,
      ),
    );
  }

  List<Map<String, dynamic>> get filteredItems {
    if (searchQuery == null || searchQuery!.isEmpty) {
      return currentItems;
    }
    
    return currentItems.where((item) {
      final title = (item['title'] ?? '').toString().toLowerCase();
      final description = (item['description'] ?? '').toString().toLowerCase();
      final query = searchQuery!.toLowerCase();
      
      return title.contains(query) || description.contains(query);
    }).toList();
  }

  Widget _buildBreadcrumbs() {
    final List<Widget> parts = [];

    parts.add(
      Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading('navigate') ? null : () {
            pathStack = ['root'];
            pathMeta = [];
            fetchItems();
          },
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.home, size: 16, color: Colors.blue[700]),
                const SizedBox(width: 4),
                Text(
                  'Головна',
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

    for (int i = 0; i < pathMeta.length; i++) {
      parts.add(Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Icon(Icons.chevron_right, size: 16, color: Colors.grey[600]),
      ));
      
      parts.add(
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isLoading('navigate') ? null : () {
              pathStack = ['root', ...pathMeta.take(i + 1).map((e) => e['id']!)];
              pathMeta = pathMeta.take(i + 1).toList();
              fetchItems();
            },
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                pathMeta[i]['title'] ?? '?',
                style: TextStyle(
                  color: Colors.blue[700],
                  fontWeight: FontWeight.w500,
                ),
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
        border: Border(
          bottom: BorderSide(color: Colors.grey.withOpacity(0.2)),
        ),
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
    final folders = currentItems.where((item) => item['type'] == 'folder').length;
    final tools = totalItems - folders;
    final filteredCount = filteredItems.length;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          if (searchQuery != null && searchQuery!.isNotEmpty) ...[
            Text(
              'Знайдено $filteredCount з $totalItems елементів',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ] else ...[
            Text(
              '$folders ${folders == 1 ? 'папка' : 'папок'} • $tools ${tools == 1 ? 'інструмент' : 'інструментів'}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
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
            Icon(Icons.search_off, size: 64, color: Colors.grey.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(
              'Нічого не знайдено',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Спробуйте змінити пошуковий запит',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    final isAdmin = Globals.profileManager.currentRole != 'viewer';
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.build_circle, size: 64, color: Colors.grey.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
            'Інструменти відсутні',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Додайте перший інструмент або папку',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[500],
            ),
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
    final isAdmin = Globals.profileManager.currentRole != 'viewer';
    final isNavigating = isLoading('navigate');

    return Scaffold(
      appBar: AppBar(
        title: const Text("Інструменти"),
      ),
      body: Column(
        children: [
          _buildBreadcrumbs(),
          _buildSearchBar(),
          _buildStatsInfo(),
          
          Expanded(
            child: isLoading('fetch')
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
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
                              childAspectRatio: 1.1,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                            itemCount: filteredItems.length + (pathStack.length > 1 ? 1 : 0),
                            itemBuilder: (context, index) {
                              // Кнопка "Назад"
                              if (pathStack.length > 1 && index == 0) {
                                return Card(
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: isNavigating ? null : goBack,
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Container(
                                              width: 48,
                                              height: 48,
                                              decoration: BoxDecoration(
                                                color: Colors.grey.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: isNavigating
                                                  ? const LoadingIndicator(size: 24)
                                                  : const Icon(Icons.arrow_back, size: 24),
                                            ),
                                            const SizedBox(height: 8),
                                            const Text(
                                              'Назад',
                                              style: TextStyle(fontWeight: FontWeight.w500),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }

                              // Інструменти та папки
                              final itemIndex = pathStack.length > 1 ? index - 1 : index;
                              final item = filteredItems[itemIndex];
                              final isFolder = item['type'] == 'folder';
                              final icon = iconFromData(item, isFolder);

                          return ToolTile(
                            title: item['title'] ?? '',
                            description: item['description'],
                            icon: icon,
                            isFolder: isFolder,
                            isAdmin: isAdmin,
                            fileId: isFolder ? null : item['fileId'],
                            isFileLoading: isLoading('open_${item['id']}'), // 👈 Передаємо стан
                            onTap: () async {
                              if (isFolder) {
                                await navigateToFolder(item['id']);
                              } else {
                                await openTool(item);
                                await fetchItems(); 
                              }
                            },
                            onEdit: () => editItem(item),
                            onDelete: () => deleteItem(item),
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