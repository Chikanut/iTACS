import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../models/checklist_tool/checklist_tool_models.dart';
import '../../../../services/checklist_tool_service.dart';
import '../../../../utils/template_renderer.dart';
import 'checklist_section_editor_page.dart';
import 'message_template_editor_page.dart';

class ChecklistConfigEditorPage extends StatefulWidget {
  const ChecklistConfigEditorPage({super.key, this.initialConfig});

  final ChecklistToolConfig? initialConfig;

  @override
  State<ChecklistConfigEditorPage> createState() =>
      _ChecklistConfigEditorPageState();
}

class _ChecklistConfigEditorPageState extends State<ChecklistConfigEditorPage> {
  final ChecklistToolService _service = ChecklistToolService();
  final Uuid _uuid = const Uuid();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _emojiController;

  late List<UserField> _userFields;
  late List<ChecklistSection> _sections;
  late List<InfoCard> _infoCards;
  late List<MessageTemplate> _templates;
  bool _isSaving = false;

  bool get _isEditing => widget.initialConfig != null;
  String get _configId => widget.initialConfig?.id ?? _uuid.v4();

  @override
  void initState() {
    super.initState();
    final config = widget.initialConfig;
    _titleController = TextEditingController(text: config?.title ?? '');
    _emojiController = TextEditingController(text: config?.emoji ?? '');
    _userFields = List<UserField>.from(config?.userFields ?? const []);
    _sections = List<ChecklistSection>.from(config?.sections ?? const []);
    _infoCards = List<InfoCard>.from(config?.infoCards ?? const []);
    _templates = List<MessageTemplate>.from(config?.templates ?? const []);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _emojiController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final config = ChecklistToolConfig(
      id: _configId,
      title: _titleController.text.trim(),
      emoji: _emojiController.text.trim().isEmpty
          ? null
          : _emojiController.text.trim(),
      userFields: _userFields,
      sections: _sections,
      infoCards: _infoCards,
      templates: _templates,
    );

    await _service.saveConfig(config);
    if (!mounted) {
      return;
    }

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Редактор конфігурації' : 'Нова конфігурація заняття',
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Зберегти'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildGeneralSection(context),
            const SizedBox(height: 16),
            _buildChecklistSection(context),
            const SizedBox(height: 16),
            _buildInfoSection(context),
            const SizedBox(height: 16),
            _buildTemplatesSection(context),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneralSection(BuildContext context) {
    return _EditorSection(
      title: '8а — Загальне',
      action: FilledButton.icon(
        onPressed: _addOrEditUserField,
        icon: const Icon(Icons.add),
        label: const Text('Поле'),
      ),
      child: Column(
        children: [
          TextFormField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Назва заняття',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Вкажіть назву заняття';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _emojiController,
            decoration: const InputDecoration(
              labelText: 'Emoji',
              hintText: '📋',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          if (_userFields.isEmpty)
            const _EditorHint(
              text:
                  'Додайте глобальні поля, наприклад ПІБ, звання або підрозділ.',
            )
          else
            Column(
              children: _userFields
                  .map((field) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(field.label),
                        subtitle: Text(
                          '${field.id} • ${field.fieldType.displayName}${field.isGlobal ? ' • зберігати локально' : ''}',
                        ),
                        trailing: Wrap(
                          spacing: 4,
                          children: [
                            IconButton(
                              onPressed: () =>
                                  _addOrEditUserField(field: field),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  _userFields = _userFields
                                      .where((item) => item.id != field.id)
                                      .toList(growable: false);
                                });
                              },
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      ),
                    );
                  })
                  .toList(growable: false),
            ),
        ],
      ),
    );
  }

  Widget _buildChecklistSection(BuildContext context) {
    return _EditorSection(
      title: '8б — Редактор чеклістів',
      action: FilledButton.icon(
        onPressed: _addSection,
        icon: const Icon(Icons.add),
        label: const Text('Секція'),
      ),
      child: _sections.isEmpty
          ? const _EditorHint(
              text: 'Додайте першу секцію та наповніть її пунктами чекліста.',
            )
          : ReorderableListView.builder(
              shrinkWrap: true,
              buildDefaultDragHandles: false,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _sections.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  _sections = _reorderList(_sections, oldIndex, newIndex);
                });
              },
              itemBuilder: (context, index) {
                final section = _sections[index];
                return Card(
                  key: ValueKey(section.id),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: ReorderableDragStartListener(
                      index: index,
                      child: const Icon(Icons.drag_indicator),
                    ),
                    title: Text(
                      '${section.emoji?.trim().isNotEmpty == true ? '${section.emoji} ' : ''}${section.title}',
                    ),
                    subtitle: Text('${section.items.length} пунктів'),
                    onTap: () => _editSection(section),
                    trailing: Wrap(
                      spacing: 4,
                      children: [
                        IconButton(
                          onPressed: () => _editSection(section),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _sections = _sections
                                  .where((item) => item.id != section.id)
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
    );
  }

  Widget _buildInfoSection(BuildContext context) {
    return _EditorSection(
      title: '8в — Редактор довідки',
      action: FilledButton.icon(
        onPressed: _addOrEditInfoCard,
        icon: const Icon(Icons.add),
        label: const Text('Картка'),
      ),
      child: _infoCards.isEmpty
          ? const _EditorHint(
              text:
                  'Додайте картки довідки з текстом, який можна розгорнути та скопіювати.',
            )
          : ReorderableListView.builder(
              shrinkWrap: true,
              buildDefaultDragHandles: false,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _infoCards.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  _infoCards = _reorderList(_infoCards, oldIndex, newIndex);
                });
              },
              itemBuilder: (context, index) {
                final card = _infoCards[index];
                return Card(
                  key: ValueKey(card.id),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: ReorderableDragStartListener(
                      index: index,
                      child: const Icon(Icons.drag_indicator),
                    ),
                    title: Text(card.title),
                    subtitle: Text(
                      card.content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Wrap(
                      spacing: 4,
                      children: [
                        IconButton(
                          onPressed: () => _addOrEditInfoCard(card: card),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _infoCards = _infoCards
                                  .where((item) => item.id != card.id)
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
    );
  }

  Widget _buildTemplatesSection(BuildContext context) {
    return _EditorSection(
      title: '8г — Редактор шаблонів',
      action: FilledButton.icon(
        onPressed: _editTemplate,
        icon: const Icon(Icons.add),
        label: const Text('Шаблон'),
      ),
      child: _templates.isEmpty
          ? const _EditorHint(
              text:
                  'Створіть шаблон повідомлення з полями та плейсхолдерами {{fieldId}}.',
            )
          : ReorderableListView.builder(
              shrinkWrap: true,
              buildDefaultDragHandles: false,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _templates.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  _templates = _reorderList(_templates, oldIndex, newIndex);
                });
              },
              itemBuilder: (context, index) {
                final template = _templates[index];
                final placeholders = TemplateRenderer.extractPlaceholders(
                  template.body,
                );
                return Card(
                  key: ValueKey(template.id),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: ReorderableDragStartListener(
                      index: index,
                      child: const Icon(Icons.drag_indicator),
                    ),
                    title: Text(template.title),
                    subtitle: Text(
                      '${template.fields.length} полів • ${placeholders.length} плейсхолдерів',
                    ),
                    onTap: () => _editTemplate(template: template),
                    trailing: Wrap(
                      spacing: 4,
                      children: [
                        IconButton(
                          onPressed: () => _editTemplate(template: template),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _templates = _templates
                                  .where((item) => item.id != template.id)
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
    );
  }

  Future<void> _addOrEditUserField({UserField? field}) async {
    final idController = TextEditingController(text: field?.id ?? '');
    final labelController = TextEditingController(text: field?.label ?? '');
    final placeholderController = TextEditingController(
      text: field?.placeholder ?? '',
    );
    var selectedType = field?.fieldType ?? FieldType.text;
    var isGlobal = field?.isGlobal ?? true;

    final didSave = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text(field == null ? 'Нове поле' : 'Редагувати поле'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: idController,
                    decoration: const InputDecoration(
                      labelText: 'ID поля',
                      hintText: 'full_name',
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
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Зберігати значення між сесіями'),
                    value: isGlobal,
                    onChanged: (value) {
                      setStateDialog(() {
                        isGlobal = value;
                      });
                    },
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

    final nextField = UserField(
      id: idController.text.trim().isEmpty
          ? _uuid.v4()
          : idController.text.trim(),
      label: labelController.text.trim(),
      fieldType: selectedType,
      placeholder: placeholderController.text.trim().isEmpty
          ? null
          : placeholderController.text.trim(),
      isGlobal: isGlobal,
    );

    setState(() {
      if (field == null) {
        _userFields = [..._userFields, nextField];
      } else {
        _userFields = _userFields
            .map((item) => item.id == field.id ? nextField : item)
            .toList(growable: false);
      }
    });
  }

  Future<void> _addSection() async {
    final titleController = TextEditingController();
    final emojiController = TextEditingController();

    final didCreate = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Нова секція'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Назва секції'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emojiController,
              decoration: const InputDecoration(labelText: 'Emoji'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Скасувати'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Створити'),
          ),
        ],
      ),
    );

    if (didCreate != true) {
      return;
    }

    final section = ChecklistSection(
      id: _uuid.v4(),
      title: titleController.text.trim(),
      emoji: emojiController.text.trim().isEmpty
          ? null
          : emojiController.text.trim(),
      items: const [],
    );
    await _editSection(section, isNew: true);
  }

  Future<void> _editSection(
    ChecklistSection section, {
    bool isNew = false,
  }) async {
    final editedSection = await Navigator.of(context).push<ChecklistSection>(
      MaterialPageRoute(
        builder: (_) => ChecklistSectionEditorPage(section: section),
      ),
    );

    if (editedSection == null) {
      return;
    }

    setState(() {
      if (isNew) {
        _sections = [..._sections, editedSection];
      } else {
        _sections = _sections
            .map((item) => item.id == editedSection.id ? editedSection : item)
            .toList(growable: false);
      }
    });
  }

  Future<void> _addOrEditInfoCard({InfoCard? card}) async {
    final titleController = TextEditingController(text: card?.title ?? '');
    final contentController = TextEditingController(text: card?.content ?? '');
    final colorController = TextEditingController(
      text: card?.accentColor?.toRadixString(16).toUpperCase() ?? '2E7D32',
    );

    final didSave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          card == null ? 'Нова картка довідки' : 'Редагувати довідку',
        ),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Назва'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: colorController,
                  decoration: const InputDecoration(
                    labelText: 'Accent color (HEX)',
                    hintText: '2E7D32',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contentController,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: 'Вміст',
                    alignLabelWithHint: true,
                  ),
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
    );

    if (didSave != true) {
      return;
    }

    final normalizedHex = colorController.text.trim().replaceAll('#', '');
    final parsedColor = int.tryParse(normalizedHex, radix: 16);
    final nextCard = InfoCard(
      id: card?.id ?? _uuid.v4(),
      title: titleController.text.trim(),
      content: contentController.text.trim(),
      accentColor: parsedColor == null ? null : (0xFF000000 | parsedColor),
    );

    setState(() {
      if (card == null) {
        _infoCards = [..._infoCards, nextCard];
      } else {
        _infoCards = _infoCards
            .map((item) => item.id == card.id ? nextCard : item)
            .toList(growable: false);
      }
    });
  }

  Future<void> _editTemplate({MessageTemplate? template}) async {
    final editedTemplate = await Navigator.of(context).push<MessageTemplate>(
      MaterialPageRoute(
        builder: (_) => MessageTemplateEditorPage(
          template: template,
          availableGlobalFields: _userFields,
        ),
      ),
    );

    if (editedTemplate == null) {
      return;
    }

    setState(() {
      if (template == null) {
        _templates = [..._templates, editedTemplate];
      } else {
        _templates = _templates
            .map((item) => item.id == editedTemplate.id ? editedTemplate : item)
            .toList(growable: false);
      }
    });
  }
}

class _EditorSection extends StatelessWidget {
  const _EditorSection({required this.title, required this.child, this.action});

  final String title;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (action != null) action!,
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _EditorHint extends StatelessWidget {
  const _EditorHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text),
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
