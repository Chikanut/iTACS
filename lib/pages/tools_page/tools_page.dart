import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../globals.dart';
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
      title: const Text('Виберіть іконку'),
      content: SizedBox(
        width: double.maxFinite,
        height: 300,
        child: GridView.count(
          crossAxisCount: 4,
          children: allIcons.map((iconData) {
            return IconButton(
              icon: Icon(iconData, size: 30),
              onPressed: () {
                Navigator.of(context).pop(iconData);
              },
            );
          }).toList(),
        ),
      ),
    ),
  );
}

class ToolsPage extends StatefulWidget {
  const ToolsPage({super.key});

  @override
  State<ToolsPage> createState() => _ToolsPageState();
}

class _ToolsPageState extends State<ToolsPage> {
  List<String> pathStack = ['root'];
  List<Map<String, dynamic>> pathMeta = [];
  List<Map<String, dynamic>> currentItems = [];

  @override
  void initState() {
    super.initState();
    fetchItems();
  }

  Future<void> fetchItems() async {
    final groupId = Globals.profileManager.currentGroupId;
    final parentId = pathStack.last;

    debugPrint('[tools] fetchItems: groupId=$groupId, parentId=$parentId');

    if (groupId == null) return;

    try {
      final docs = await Globals.firestoreManager.getDocumentsForGroup(
        groupId: groupId,
        collection: 'tools_by_group',
        whereEqual: {'parentId': parentId},
        orderBy: 'modifiedAt',
      );

      setState(() {
        currentItems = docs
            .map((d) => {
                  ...d.data() as Map<String, dynamic>,
                  'id': d.id,
                })
            .toList();
      });

      debugPrint('[tools] documents loaded: ${currentItems.length}');
      for (var item in currentItems) {
        debugPrint('[tools] ${item['title']} (${item['type']})');
      }
    } catch (e) {
      debugPrint('[tools] fetchItems ERROR: $e');
      Globals.errorNotificationManager.showError('Помилка завантаження інструментів');
    }
  }

  Future<void> navigateToFolder(String folderId) async {
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
        pathMeta.add({'id': folderId, 'title': '???'});
      }
    }

    fetchItems();
  }

  void goBack() {
    if (pathStack.length > 1) {
      pathStack.removeLast();
      pathMeta.removeLast();
      fetchItems();
    }
  }

  Widget buildBreadcrumbs() {
    final List<Widget> parts = [];

    parts.add(
      GestureDetector(
        onTap: () {
          pathStack = ['root'];
          pathMeta = [];
          fetchItems();
        },
        child: const Text('Головна', style: TextStyle(color: Colors.blue)),
      ),
    );

    for (int i = 0; i < pathMeta.length; i++) {
      parts.add(const Text(' / '));
      parts.add(
        GestureDetector(
          onTap: () {
            pathStack = ['root', ...pathMeta.take(i + 1).map((e) => e['id']!)];
            pathMeta = pathMeta.take(i + 1).toList();
            fetchItems();
          },
          child: Text(pathMeta[i]['title'] ?? '?', style: const TextStyle(color: Colors.blue)),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: parts),
        ),
      ),
    );
  }

  Future<void> openTool(Map<String, dynamic> item) async {
    final fileId = item['fileId'] as String?;
    if (fileId == null) return;

    try {
      await Globals.fileManager.openFile(fileId);
    } catch (e) {
      Globals.errorNotificationManager.showError("Не вдалося відкрити файл: $e");
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

    try {
      await deleteRecursively(item['id']);
      debugPrint('[tools] deleteItem success: ${item['title']}');
      await fetchItems();
    } catch (e) {
      debugPrint('[tools] deleteItem ERROR: $e');
      Globals.errorNotificationManager.showError("Не вдалося видалити: $e");
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

  @override
  Widget build(BuildContext context) {
    final isAdmin = Globals.profileManager.currentRole != 'viewer';

    return Scaffold(
      appBar: AppBar(title: const Text("Інструменти")),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              onPressed: showAddDialog,
              tooltip: 'Додати інструмент або папку',
              child: const Icon(Icons.add),
            )
          : null,
      body: Column(
        children: [
          buildBreadcrumbs(),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              children: [
                if (pathStack.length > 1)
                  ToolTile(title: "⬅️ Назад", icon: Icons.arrow_back, onTap: goBack),
                ...currentItems.map((item) {
                  final isFolder = item['type'] == 'folder';
                  final icon = iconFromData(item, isFolder);
                  return ToolTile(
                    title: item['title'] ?? '',
                    icon: icon,
                    onTap: () {
                      if (isFolder) {
                        navigateToFolder(item['id']);
                      } else {
                        openTool(item);
                      }
                    },
                    isAdmin: isAdmin,
                    onEdit: () => editItem(item),
                    onDelete: () => deleteItem(item),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
