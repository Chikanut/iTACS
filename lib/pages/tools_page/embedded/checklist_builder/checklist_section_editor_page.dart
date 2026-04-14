import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../models/checklist_tool/checklist_tool_models.dart';

class ChecklistSectionEditorPage extends StatefulWidget {
  const ChecklistSectionEditorPage({super.key, required this.section});

  final ChecklistSection section;

  @override
  State<ChecklistSectionEditorPage> createState() =>
      _ChecklistSectionEditorPageState();
}

class _ChecklistSectionEditorPageState
    extends State<ChecklistSectionEditorPage> {
  final Uuid _uuid = const Uuid();
  late final TextEditingController _titleController;
  late final TextEditingController _emojiController;
  late List<ChecklistItem> _items;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.section.title);
    _emojiController = TextEditingController(text: widget.section.emoji ?? '');
    _items = List<ChecklistItem>.from(widget.section.items);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _emojiController.dispose();
    super.dispose();
  }

  void _save() {
    Navigator.of(context).pop(
      widget.section.copyWith(
        title: _titleController.text.trim(),
        emoji: _emojiController.text.trim().isEmpty
            ? null
            : _emojiController.text.trim(),
        items: _items,
      ),
    );
  }

  Future<void> _editItem({ChecklistItem? item}) async {
    final controller = TextEditingController(text: item?.text ?? '');
    final didSave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item == null ? 'Новий пункт' : 'Редагувати пункт'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Текст пункту'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Скасувати'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Зберегти'),
          ),
        ],
      ),
    );

    if (didSave != true) {
      return;
    }

    final nextItem = ChecklistItem(
      id: item?.id ?? _uuid.v4(),
      text: controller.text.trim(),
    );

    setState(() {
      if (item == null) {
        _items = [..._items, nextItem];
      } else {
        _items = _items
            .map((existing) => existing.id == item.id ? nextItem : existing)
            .toList(growable: false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Редактор секції'),
        actions: [TextButton(onPressed: _save, child: const Text('Зберегти'))],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _editItem(),
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Назва секції',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emojiController,
            decoration: const InputDecoration(
              labelText: 'Emoji',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          if (_items.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('Додайте перший пункт секції.'),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              buildDefaultDragHandles: false,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _items.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  _items = _reorderList(_items, oldIndex, newIndex);
                });
              },
              itemBuilder: (context, index) {
                final item = _items[index];
                return Card(
                  key: ValueKey(item.id),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: ReorderableDragStartListener(
                      index: index,
                      child: const Icon(Icons.drag_indicator),
                    ),
                    title: Text(item.text),
                    trailing: Wrap(
                      spacing: 4,
                      children: [
                        IconButton(
                          onPressed: () => _editItem(item: item),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _items = _items
                                  .where((existing) => existing.id != item.id)
                                  .toList(growable: false);
                            });
                          },
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

List<T> _reorderList<T>(List<T> source, int oldIndex, int newIndex) {
  final list = List<T>.from(source);
  if (newIndex > oldIndex) {
    newIndex -= 1;
  }
  final item = list.removeAt(oldIndex);
  list.insert(newIndex, item);
  return list;
}
