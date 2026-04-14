import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../models/checklist_tool/checklist_tool_models.dart';
import '../../../../utils/template_renderer.dart';
import '../../../../widgets/tool_field_widget.dart';

class MessageTemplateEditorPage extends StatefulWidget {
  const MessageTemplateEditorPage({
    super.key,
    this.template,
    required this.availableGlobalFields,
  });

  final MessageTemplate? template;
  final List<UserField> availableGlobalFields;

  @override
  State<MessageTemplateEditorPage> createState() =>
      _MessageTemplateEditorPageState();
}

class _MessageTemplateEditorPageState extends State<MessageTemplateEditorPage> {
  final Uuid _uuid = const Uuid();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  late TemplateColor _selectedColor;
  late List<TemplateField> _fields;
  final Map<String, String> _previewValues = {};

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.template?.title ?? '',
    );
    _bodyController = TextEditingController(text: widget.template?.body ?? '');
    _selectedColor = widget.template?.buttonColor ?? TemplateColor.blue;
    _fields = List<TemplateField>.from(widget.template?.fields ?? const []);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pop(
      MessageTemplate(
        id: widget.template?.id ?? _uuid.v4(),
        title: _titleController.text.trim(),
        buttonColor: _selectedColor,
        fields: _fields,
        body: _bodyController.text,
      ),
    );
  }

  Future<void> _editField({TemplateField? field}) async {
    final idController = TextEditingController(text: field?.id ?? '');
    final labelController = TextEditingController(text: field?.label ?? '');
    final placeholderController = TextEditingController(
      text: field?.placeholder ?? '',
    );
    var selectedType = field?.fieldType ?? FieldType.text;

    final didSave = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text(field == null ? 'Нове поле шаблону' : 'Редагувати поле'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: idController,
                    decoration: const InputDecoration(
                      labelText: 'ID',
                      hintText: 'target_count',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: labelController,
                    decoration: const InputDecoration(labelText: 'Назва'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<FieldType>(
                    value: selectedType,
                    decoration: const InputDecoration(labelText: 'Тип'),
                    items: FieldType.values
                        .map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(type.displayName),
                          );
                        })
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value != null) {
                        setStateDialog(() {
                          selectedType = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: placeholderController,
                    decoration: const InputDecoration(labelText: 'Placeholder'),
                  ),
                ],
              ),
            ),
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
      ),
    );

    if (didSave != true) {
      return;
    }

    final nextField = TemplateField(
      id: idController.text.trim().isEmpty
          ? _uuid.v4()
          : idController.text.trim(),
      label: labelController.text.trim(),
      fieldType: selectedType,
      placeholder: placeholderController.text.trim().isEmpty
          ? null
          : placeholderController.text.trim(),
    );

    setState(() {
      if (field == null) {
        _fields = [..._fields, nextField];
      } else {
        _fields = _fields
            .map((item) => item.id == field.id ? nextField : item)
            .toList(growable: false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final availablePlaceholders = [
      ...widget.availableGlobalFields.map((field) => field.toTemplateField()),
      ..._fields,
    ];
    final knownIds = availablePlaceholders.map((field) => field.id).toSet();
    final unknownPlaceholders = TemplateRenderer.extractPlaceholders(
      _bodyController.text,
    ).where((id) => !knownIds.contains(id)).toList(growable: false);
    final preview = TemplateRenderer.render(
      _bodyController.text,
      _previewValues,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.template == null ? 'Новий шаблон' : 'Редактор шаблону',
        ),
        actions: [TextButton(onPressed: _save, child: const Text('Зберегти'))],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _editField(),
        child: const Icon(Icons.add),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Назва шаблону',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Вкажіть назву шаблону';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<TemplateColor>(
              value: _selectedColor,
              decoration: const InputDecoration(
                labelText: 'Колір кнопки',
                border: OutlineInputBorder(),
              ),
              items: TemplateColor.values
                  .map((color) {
                    return DropdownMenuItem(
                      value: color,
                      child: Text(color.displayName),
                    );
                  })
                  .toList(growable: false),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedColor = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Поля форми',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            if (_fields.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('Додайте перше поле форми.'),
              )
            else
              ReorderableListView.builder(
                shrinkWrap: true,
                buildDefaultDragHandles: false,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _fields.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    _fields = _reorderList(_fields, oldIndex, newIndex);
                  });
                },
                itemBuilder: (context, index) {
                  final field = _fields[index];
                  return Card(
                    key: ValueKey(field.id),
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: ReorderableDragStartListener(
                        index: index,
                        child: const Icon(Icons.drag_indicator),
                      ),
                      title: Text(field.label),
                      subtitle: Text(
                        '${field.id} • ${field.fieldType.displayName}',
                      ),
                      trailing: Wrap(
                        spacing: 4,
                        children: [
                          IconButton(
                            onPressed: () => _editField(field: field),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _fields = _fields
                                    .where((item) => item.id != field.id)
                                    .toList(growable: false);
                                _previewValues.remove(field.id);
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
            const SizedBox(height: 16),
            Text(
              'Тіло шаблону',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: availablePlaceholders
                  .map((field) {
                    return ActionChip(
                      label: Text('${field.label} → {{${field.id}}}'),
                      onPressed: () {
                        final insertion = '{{${field.id}}}';
                        final text = _bodyController.text;
                        final selection = _bodyController.selection;
                        final start = selection.start >= 0
                            ? selection.start
                            : text.length;
                        final end = selection.end >= 0
                            ? selection.end
                            : text.length;
                        final nextText = text.replaceRange(
                          start,
                          end,
                          insertion,
                        );
                        _bodyController.value = TextEditingValue(
                          text: nextText,
                          selection: TextSelection.collapsed(
                            offset: start + insertion.length,
                          ),
                        );
                        setState(() {});
                      },
                    );
                  })
                  .toList(growable: false),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _bodyController,
              maxLines: 10,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Використовуйте плейсхолдери виду {{field_id}}',
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (unknownPlaceholders.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: unknownPlaceholders
                    .map((placeholder) {
                      return Chip(
                        avatar: const Icon(
                          Icons.warning_amber_outlined,
                          size: 16,
                        ),
                        label: Text('Невідомий: {{$placeholder}}'),
                      );
                    })
                    .toList(growable: false),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'Preview значення',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            if (availablePlaceholders.isEmpty)
              const Text('Додайте поля, щоб побачити preview.')
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 720;
                  final spacing = 12.0;
                  final itemWidth = isWide
                      ? (constraints.maxWidth - spacing) / 2
                      : constraints.maxWidth;

                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: availablePlaceholders
                        .map((field) {
                          return SizedBox(
                            width: itemWidth,
                            child: ToolFieldWidget(
                              field: field,
                              value: _previewValues[field.id],
                              onChanged: (value) {
                                setState(() {
                                  _previewValues[field.id] = value;
                                });
                              },
                            ),
                          );
                        })
                        .toList(growable: false),
                  );
                },
              ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(preview),
            ),
          ],
        ),
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
