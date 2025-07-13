import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'material_tile.dart';
import 'material_dialogs.dart';

import '../../../globals.dart';

class MaterialsPage extends StatefulWidget {
  const MaterialsPage({super.key});

  @override
  State<MaterialsPage> createState() => _MaterialsPageState();
}

class _MaterialsPageState extends State<MaterialsPage> {
  List<Map<String, dynamic>> materials = [];
  List<String> selectedTags = ['всі'];
  Set<String> allTags = {'всі'};

  String userRole = 'viewer';
  bool canEdit = false;

  bool isSearching = false;
  String searchQuery = '';
  final searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchMaterials();
  }

  Future<void> fetchMaterials() async {
    final user = Globals.firebaseAuth.currentUser;
    if (user == null) return;

    final email = user.email!;
    final userData = await Globals.firestoreManager.getOrCreateUserData();
    if (userData == null) return;

    final groupId = Globals.profileManager.currentGroupId;
    if (groupId == null) return;

    final docs = await Globals.firestoreManager.getDocumentsForGroup(
      groupId: groupId,
      collection: 'materials',
    );
    final data = docs.map((doc) {
      final d = doc.data() as Map<String, dynamic>;
      d['id'] = doc.id;
      return d;
    }).toList();

    final roles = await Globals.firestoreManager.getUserRolesPerGroup(email);
    final userRole = roles[groupId] ?? 'viewer';

    final tags = <String>{'всі'};
    for (var item in data) {
      final tagsList = List<String>.from(item['tags'] ?? []);
      tags.addAll(tagsList);
    }

    setState(() {
      materials = data;
      allTags = tags;
      canEdit = userRole == 'admin' || userRole == 'editor';
    });
  }

  void toggleTag(String tag) {
    setState(() {
      if (tag == 'всі') {
        selectedTags = ['всі'];
      } else {
        selectedTags.remove('всі');
        if (selectedTags.contains(tag)) {
          selectedTags.remove(tag);
        } else {
          selectedTags.add(tag);
        }
        if (selectedTags.isEmpty) selectedTags = ['всі'];
      }
    });
  }

  bool matchesTags(List<String> itemTags) {
    if (selectedTags.contains('всі')) return true;
    return selectedTags.every((tag) => itemTags.contains(tag));
  }

  @override
  Widget build(BuildContext context) {
    final filtered = materials.where((m) {
      final tags = List<String>.from(m['tags'] ?? []);
      final title = (m['title'] ?? '').toString().toLowerCase();
      final matchTags = matchesTags(tags);
      final matchSearch = searchQuery.isEmpty || title.contains(searchQuery.toLowerCase());
      return matchTags && matchSearch;
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Методичні матеріали')),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: isSearching ? 200 : 48,
                  child: isSearching
                      ? TextField(
                          controller: searchController,
                          decoration: const InputDecoration(
                            hintText: 'Пошук...',
                            contentPadding: EdgeInsets.symmetric(horizontal: 8),
                          ),
                          onChanged: (value) => setState(() => searchQuery = value),
                        )
                      : IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: () => setState(() => isSearching = true),
                        ),
                ),
                if (!isSearching) const SizedBox(width: 4),
                Expanded(
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: allTags.map((tag) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: FilterChip(
                        label: Text(tag),
                        selected: selectedTags.contains(tag),
                        onSelected: (_) => toggleTag(tag),
                      ),
                    )).toList(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (context, index) => MaterialTile(
                material: filtered[index],
                onRefresh: fetchMaterials,
                isWeb: kIsWeb,
                userRole: userRole,
              ),
            ),
          ),
        ],
      ),
     floatingActionButton: canEdit
    ? FloatingActionButton(
        onPressed: () => showAddMaterialDialog(context, fetchMaterials),
        child: const Icon(Icons.add),
      )
    : null,
    );
  }
}
