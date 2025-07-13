import 'package:flutter/material.dart';
import '../../../globals.dart';

Future<void> showAddMaterialDialog(BuildContext context, VoidCallback onRefresh) async {
  final titleController = TextEditingController();
  final urlController = TextEditingController();
  final tagsController = TextEditingController();

  final user = Globals.firebaseAuth.currentUser;
  if (user == null) return;

  await showDialog(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Додати матеріал'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Назва')),
              TextField(controller: urlController, decoration: const InputDecoration(labelText: 'Посилання')),
              TextField(controller: tagsController, decoration: const InputDecoration(labelText: 'Теги через кому')),
              const SizedBox(height: 12),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Скасувати')),
          ElevatedButton(
            onPressed: () async {
              final title = titleController.text.trim();
              final url = urlController.text.trim();
              final tags = tagsController.text.trim().split(',').map((e) => e.trim()).toList();

              if (title.isEmpty || url.isEmpty) return;

              final fileId = Globals.fileManager.extractFileId(url);
              if (fileId == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Невалідне посилання на Google Drive')),
                );
                return;
              }

              final modifiedTime = DateTime.now().toIso8601String();

              await Globals.firestoreManager.createDocument(
                groupId: Globals.profileManager.currentGroupId!,
                collection: 'materials',
                data: {
                  'title': title,
                  'url': url,
                  'fileId': fileId,
                  'tags': tags,
                  'modifiedAt': modifiedTime,
                },
              );

              Navigator.pop(context);
              onRefresh();
            },
            child: const Text('Додати'),
          ),
        ],
      ),
    ),
  );
}

Future<void> showEditMaterialDialog(BuildContext context, Map<String, dynamic> material, VoidCallback onRefresh) async {
  final titleController = TextEditingController(text: material['title'] ?? '');
  final urlController = TextEditingController(text: material['url'] ?? '');
  final tagsController = TextEditingController(text: (material['tags'] as List<dynamic>?)?.join(', ') ?? '');

  final String docId = material['id'];

  await showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Редагувати матеріал'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Назва')),
            TextField(controller: urlController, decoration: const InputDecoration(labelText: 'Посилання')),
            TextField(controller: tagsController, decoration: const InputDecoration(labelText: 'Теги через кому')),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Скасувати')),
        ElevatedButton(
          onPressed: () async {
            final title = titleController.text.trim();
            final url = urlController.text.trim();
            final tags = tagsController.text.trim().split(',').map((e) => e.trim()).toList();

            if (title.isEmpty || url.isEmpty) return;

            final fileId = Globals.fileManager.extractFileId(url);
            if (fileId == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Невалідне посилання на Google Drive')),
              );
              return;
            }

            final metadata = await Globals.fileManager.getFileMetadata(fileId);
            if (metadata == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Не вдалося завантажити метадані файлу')),
              );
              return;
            }

            final modifiedTime = metadata.lastModified ?? DateTime.now().toIso8601String();

            await Globals.firestoreManager.updateDocument(
              groupId: Globals.profileManager.currentGroupId!,
              collection: 'materials',
              docId: docId,
              data: {
                'title': title,
                'url': url,
                'fileId': fileId,
                'tags': tags,
                'modifiedAt': modifiedTime,
              },
            );

            Navigator.pop(context);
            onRefresh();
          },
          child: const Text('Зберегти'),
        ),
      ],
    ),
  );
}