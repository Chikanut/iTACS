import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'material_tile.dart';
import 'material_dialogs.dart';

import '../../globals.dart';
import '../../mixins/loading_state_mixin.dart';
import '../../services/materials_service.dart';
import '../../widgets/loading_indicator.dart';

class MaterialsPage extends StatefulWidget {
  const MaterialsPage({super.key});

  @override
  State<MaterialsPage> createState() => _MaterialsPageState();
}

class _MaterialsPageState extends State<MaterialsPage> with LoadingStateMixin {
  final MaterialsService _materialsService = MaterialsService();
  List<Map<String, dynamic>> materials = [];
  List<String> selectedTags = [];
  Set<String> allTags = {};

  String userRole = 'viewer';
  bool canEdit = false;

  bool isSearching = false;
  String searchQuery = '';
  final searchController = TextEditingController();
  final FocusNode searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _hydrateCachedMaterials();
    unawaited(fetchMaterials());
  }

  @override
  void dispose() {
    searchController.dispose();
    searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> fetchMaterials() async {
    try {
      await withLoading('fetch_materials', () async {
        final groupId = Globals.profileManager.currentGroupId;
        if (groupId == null) return;

        final data = await _materialsService.getMaterials(
          groupId: groupId,
          forceRefresh: true,
        );
        final currentUserRole = Globals.profileManager.currentRole ?? 'viewer';

        // Збираємо всі теги і сортуємо за популярністю
        final tagCounts = <String, int>{};
        for (var item in data) {
          final tagsList = List<String>.from(item['tags'] ?? []);
          for (final tag in tagsList) {
            tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
          }
        }

        final sortedTags = tagCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        if (mounted) {
          setState(() {
            materials = data;
            allTags = sortedTags.map((e) => e.key).toSet();
            userRole = currentUserRole;
            canEdit =
                !Globals.appRuntimeState.isReadOnlyOffline &&
                (currentUserRole == 'admin' || currentUserRole == 'editor');
          });
        }
      });
    } catch (e) {
      if (mounted) {
        Globals.errorNotificationManager.showError(
          'Помилка завантаження матеріалів: $e',
        );
      }
    }
  }

  void _hydrateCachedMaterials() {
    final groupId = Globals.profileManager.currentGroupId;
    if (groupId == null) {
      return;
    }

    final cachedMaterials = _materialsService.getCachedMaterials(
      groupId: groupId,
    );
    if (cachedMaterials.isEmpty) {
      return;
    }

    final tagCounts = <String, int>{};
    for (final item in cachedMaterials) {
      final tagsList = List<String>.from(item['tags'] ?? const []);
      for (final tag in tagsList) {
        tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
      }
    }

    final sortedTags = tagCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    setState(() {
      materials = cachedMaterials;
      allTags = sortedTags.map((entry) => entry.key).toSet();
      userRole = Globals.profileManager.currentRole ?? 'viewer';
      canEdit =
          !Globals.appRuntimeState.isReadOnlyOffline &&
          (userRole == 'admin' || userRole == 'editor');
    });
  }

  void toggleTag(String tag) {
    setState(() {
      if (selectedTags.contains(tag)) {
        selectedTags.remove(tag);
      } else {
        selectedTags.add(tag);
      }
    });
  }

  void clearAllFilters() {
    setState(() {
      selectedTags.clear();
      searchQuery = '';
      searchController.clear();
      isSearching = false;
    });
    searchFocusNode.unfocus();
  }

  void toggleSearch() {
    setState(() {
      isSearching = !isSearching;
      if (!isSearching) {
        searchQuery = '';
        searchController.clear();
      }
    });

    if (isSearching) {
      // Фокус на поле пошуку з невеликою затримкою
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          searchFocusNode.requestFocus();
        }
      });
    } else {
      searchFocusNode.unfocus();
    }
  }

  bool matchesTags(List<String> itemTags) {
    if (selectedTags.isEmpty) return true;
    return selectedTags.any((tag) => itemTags.contains(tag));
  }

  List<Map<String, dynamic>> get filteredMaterials {
    return materials.where((m) {
      final tags = List<String>.from(m['tags'] ?? []);
      final title = (m['title'] ?? '').toString().toLowerCase();
      final matchTags = matchesTags(tags);
      final matchSearch =
          searchQuery.isEmpty || title.contains(searchQuery.toLowerCase());
      return matchTags && matchSearch;
    }).toList();
  }

  bool get hasActiveFilters {
    return selectedTags.isNotEmpty || searchQuery.isNotEmpty;
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        height: isSearching ? 56 : 48,
        child: isSearching
            ? TextField(
                controller: searchController,
                focusNode: searchFocusNode,
                decoration: InputDecoration(
                  hintText: 'Пошук матеріалів...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (searchQuery.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              searchQuery = '';
                              searchController.clear();
                            });
                          },
                          tooltip: 'Очистити пошук',
                        ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: toggleSearch,
                        tooltip: 'Закрити пошук',
                      ),
                    ],
                  ),
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                onChanged: (value) =>
                    setState(() => searchQuery = value.toLowerCase()),
                textInputAction: TextInputAction.search,
              )
            : Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: toggleSearch,
                    tooltip: 'Пошук',
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${materials.length} матеріалів',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  if (hasActiveFilters)
                    TextButton.icon(
                      onPressed: clearAllFilters,
                      icon: const Icon(Icons.filter_alt_off, size: 16),
                      label: const Text('Очистити'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildTagsFilter() {
    if (allTags.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.local_offer_outlined,
                size: 16,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 8),
              Text(
                'Фільтр за тегами:',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
              ),
              const Spacer(),
              if (selectedTags.isNotEmpty)
                TextButton(
                  onPressed: () => setState(() => selectedTags.clear()),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                  ),
                  child: const Text('Очистити'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: allTags.length,
              itemBuilder: (context, index) {
                final tag = allTags.elementAt(index);
                final isSelected = selectedTags.contains(tag);

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(tag),
                    selected: isSelected,
                    onSelected: (_) => toggleTag(tag),
                    showCheckmark: false,
                    selectedColor: Theme.of(
                      context,
                    ).colorScheme.primaryContainer,
                    backgroundColor: const Color.fromARGB(255, 37, 36, 36),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsInfo() {
    final filteredCount = filteredMaterials.length;
    final totalCount = materials.length;

    if (!hasActiveFilters) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.filter_list, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            'Показано $filteredCount з $totalCount матеріалів',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canEditNow =
        !Globals.appRuntimeState.isReadOnlyOffline &&
        (userRole == 'admin' || userRole == 'editor');
    final showBlockingLoader =
        isLoading('fetch_materials') && materials.isEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Методичні матеріали')),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildTagsFilter(),
          _buildResultsInfo(),

          // Список матеріалів
          Expanded(
            child: showBlockingLoader
                ? const Center(
                    child: LoadingIndicator(
                      message: 'Завантаження матеріалів...',
                      showBackground: true,
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: fetchMaterials,
                    child: filteredMaterials.isEmpty
                        ? _buildEmptyState()
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: filteredMaterials.length,
                            separatorBuilder: (context, index) => const Divider(
                              height: 1,
                              indent: 72,
                              endIndent: 16,
                            ),
                            itemBuilder: (context, index) => MaterialTile(
                              material: filteredMaterials[index],
                              onRefresh: fetchMaterials,
                              isWeb: kIsWeb,
                              userRole: canEditNow ? userRole : 'viewer',
                            ),
                          ),
                  ),
          ),
        ],
      ),
      floatingActionButton: canEditNow
          ? FloatingActionButton(
              onPressed: () => showAddMaterialDialog(context, fetchMaterials),
              tooltip: 'Додати матеріал',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildEmptyState() {
    final canEditNow =
        !Globals.appRuntimeState.isReadOnlyOffline &&
        (userRole == 'admin' || userRole == 'editor');
    final isReadOnlyOffline = Globals.appRuntimeState.isReadOnlyOffline;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              materials.isEmpty ? Icons.folder_open : Icons.search_off,
              size: 64,
              color: Colors.grey.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              materials.isEmpty
                  ? isReadOnlyOffline
                        ? 'Офлайн-копія матеріалів відсутня'
                        : 'Матеріали відсутні'
                  : hasActiveFilters
                  ? 'Нічого не знайдено'
                  : 'Матеріали не завантажилися',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              materials.isEmpty
                  ? isReadOnlyOffline
                        ? 'Під час наступного онлайн-сеансу матеріали збережуться для швидкого відкриття.'
                        : 'Додайте перший методичний матеріал'
                  : hasActiveFilters
                  ? 'Спробуйте змінити критерії пошуку'
                  : 'Потягніть вниз для оновлення',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            if (hasActiveFilters) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: clearAllFilters,
                icon: const Icon(Icons.filter_alt_off),
                label: const Text('Очистити фільтри'),
              ),
            ],
            if (materials.isEmpty && canEditNow) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => showAddMaterialDialog(context, fetchMaterials),
                icon: const Icon(Icons.add),
                label: const Text('Додати матеріал'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
