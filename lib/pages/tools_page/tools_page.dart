import 'dart:async';

import 'package:flutter/material.dart';

import '../../globals.dart';
import '../../mixins/loading_state_mixin.dart';
import '../../services/tools_service.dart';
import '../../widgets/loading_indicator.dart';
import 'embedded/checklist_builder/checklist_builder_home_page.dart';
import 'embedded/contacts_tool_page.dart';
import 'embedded/schedule_calculator_page.dart';
import 'tool_dialog.dart';
import 'tool_tile.dart';

IconData iconFromData(Map<String, dynamic> item) {
  if (item['icon'] != null && item['iconFontFamily'] != null) {
    try {
      final iconCode = item['icon'];
      final fontFamily = item['iconFontFamily'];

      if (iconCode is int && fontFamily == 'MaterialIcons') {
        return _iconMap[iconCode] ?? Icons.widgets;
      }
    } catch (_) {}
  }
  return Icons.widgets;
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
  0xe8b8: Icons.widgets,
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
    Icons.widgets,
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

  List<Map<String, dynamic>> currentItems = [];
  String? searchQuery;
  final TextEditingController searchController = TextEditingController();

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

  Future<void> fetchItems() async {
    try {
      await withLoading('fetch', () async {
        final groupId = Globals.profileManager.currentGroupId;
        if (groupId == null) {
          return;
        }

        final items = await _toolsService.getItems(
          groupId: groupId,
          parentId: 'root',
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
      parentId: 'root',
    );
    if (cachedItems.isEmpty) {
      return;
    }

    setState(() {
      currentItems = cachedItems;
    });
  }

  void _openEmbeddedTool(String toolKey) {
    final Widget page = switch (toolKey) {
      'checklist_builder' => const ChecklistBuilderHomePage(),
      'contacts' => const ContactsToolPage(),
      'schedule_calculator' => const ScheduleCalculatorPage(),
      _ => Scaffold(
        appBar: AppBar(title: const Text('Інструмент')),
        body: Center(child: Text('Невідомий інструмент: $toolKey')),
      ),
    };
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  Future<void> openTool(Map<String, dynamic> item) async {
    final toolKey = item['toolKey']?.toString() ?? '';
    _openEmbeddedTool(toolKey);
  }

  Future<void> editItem(Map<String, dynamic> item) async {
    await showDialog(
      context: context,
      builder: (_) =>
          ToolDialog(isEditing: true, item: item, onSave: fetchItems),
    );
  }

  Future<void> deleteItem(Map<String, dynamic> item) async {
    try {
      await withLoading('delete_${item['id']}', () async {
        final groupId = Globals.profileManager.currentGroupId;
        final userRole = Globals.profileManager.currentRole;
        final overlayId = item['overlayId']?.toString().trim();
        if (groupId == null || userRole == null || overlayId == null) {
          return;
        }

        final canManageGroupContent =
            userRole == 'admin' || userRole == 'editor';
        if (!canManageGroupContent) {
          throw Exception('Недостатньо прав для видалення інструментів');
        }

        await Globals.firestoreManager.deleteDocumentWhereAllowed(
          docId: overlayId,
          groupId: groupId,
          userRole: userRole,
          collection: 'tools_by_group',
        );

        if (mounted) {
          await fetchItems();
          Globals.errorNotificationManager.showSuccess(
            'Інструмент "${item['title']}" видалено',
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
      builder: (_) => ToolDialog(onSave: fetchItems),
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
    final filteredCount = filteredItems.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            searchQuery != null && searchQuery!.isNotEmpty
                ? 'Знайдено $filteredCount з $totalItems інструментів'
                : '$totalItems вбудованих інструментів',
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
    final canManageTools =
        !isReadOnlyOffline && Globals.profileManager.currentRole != 'viewer';

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.widgets_outlined,
            size: 64,
            color: Colors.grey.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            isReadOnlyOffline
                ? 'Офлайн-копія інструментів відсутня'
                : 'Вбудовані інструменти відсутні',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            isReadOnlyOffline
                ? 'Під час наступного онлайн-сеансу список інструментів буде збережено локально.'
                : 'Додайте перший вбудований інструмент',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
          ),
          if (canManageTools) ...[
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
    final canManageTools =
        !Globals.appRuntimeState.isReadOnlyOffline &&
        Globals.profileManager.currentRole != 'viewer';
    final showBlockingLoader = isLoading('fetch') && currentItems.isEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Інструменти')),
      body: Column(
        children: [
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
                            itemCount: filteredItems.length,
                            itemBuilder: (context, index) {
                              final item = filteredItems[index];
                              return ToolTile(
                                title: item['title']?.toString() ?? '',
                                description: item['description']?.toString(),
                                icon: iconFromData(item),
                                isAdmin: canManageTools,
                                canEdit: true,
                                canDelete: true,
                                itemType: 'embedded',
                                onTap: () async {
                                  await openTool(item);
                                },
                                onEdit: () => editItem(item),
                                onDelete: () => deleteItem(item),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
      floatingActionButton: canManageTools
          ? FloatingActionButton(
              onPressed: showAddDialog,
              tooltip: 'Додати вбудований інструмент',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
