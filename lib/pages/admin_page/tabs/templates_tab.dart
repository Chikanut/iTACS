import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../globals.dart';
import '../../../models/custom_field_model.dart';
import '../../../models/lesson_progress_reminder.dart';
import '../../../services/templates_service.dart';
import '../../../widgets/custom_fields_dialogs.dart';
import '../../../widgets/lesson_progress_reminder_editor.dart';

class TemplatesTab extends StatefulWidget {
  const TemplatesTab({super.key});

  @override
  State<TemplatesTab> createState() => _TemplatesTabState();
}

class _TemplatesTabState extends State<TemplatesTab> {
  final GroupTemplatesService _templatesService = Globals.groupTemplatesService;

  bool _isLoading = true;
  bool _isSaving = false;
  List<GroupTemplate> _templates = [];

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    await _templatesService.ensureInitializedForCurrentGroup();
    final templates = _templatesService.getTemplates()
      ..sort((a, b) {
        if (a.isDefault != b.isDefault) {
          return a.isDefault ? -1 : 1;
        }
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });

    if (!mounted) return;
    setState(() {
      _templates = templates;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isCompactLayout = MediaQuery.of(context).size.width < 600;

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, isCompactLayout ? 12 : 16, 16, 8),
          child: isCompactLayout
              ? Row(
                  children: [
                    Expanded(
                      child: _TemplateStatCard(
                        icon: Icons.description_outlined,
                        title: 'Шаблони',
                        value: '${_templates.length}',
                        subtitle: 'Для поточної групи',
                        compact: true,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _isSaving
                            ? null
                            : () => _openTemplateDialog(),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Новий'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          minimumSize: const Size(0, 48),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Оновити',
                      visualDensity: VisualDensity.compact,
                      onPressed: _isLoading ? null : _loadTemplates,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                )
              : Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _TemplateStatCard(
                      icon: Icons.description_outlined,
                      title: 'Шаблони',
                      value: '${_templates.length}',
                      subtitle: 'Для поточної групи',
                    ),
                    FilledButton.icon(
                      onPressed: _isSaving ? null : () => _openTemplateDialog(),
                      icon: const Icon(Icons.add),
                      label: const Text('Новий шаблон'),
                    ),
                    IconButton(
                      tooltip: 'Оновити',
                      onPressed: _isLoading ? null : _loadTemplates,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadTemplates,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    children: [
                      if (_templates.isEmpty) ...[
                        const _TemplatesEmptyState(),
                        const SizedBox(height: 12),
                      ] else ...[
                        ..._templates.map(
                          (template) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildTemplateCard(template),
                          ),
                        ),
                      ],
                      _buildAutocompleteEditorCard(),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildTemplateCard(GroupTemplate template) {
    final updatedAt = DateFormat('dd.MM.yyyy HH:mm').format(template.updatedAt);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(child: Text(template.type.emoji)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            template.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Chip(
                            label: Text(template.type.displayName),
                            visualDensity: VisualDensity.compact,
                          ),
                          if (template.isDefault)
                            const Chip(
                              label: Text('Базовий'),
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Тривалість: ${template.durationMinutes} хв • Оновлено: $updatedAt',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (template.description.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(template.description),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (template.location.trim().isNotEmpty)
                  Chip(
                    avatar: const Icon(Icons.location_on_outlined, size: 18),
                    label: Text(template.location),
                  ),
                if (template.unit.trim().isNotEmpty)
                  Chip(
                    avatar: const Icon(Icons.military_tech_outlined, size: 18),
                    label: Text(template.unit),
                  ),
                ...template.tags.map(
                  (tag) => Chip(
                    label: Text(tag),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                if (template.customFieldDefinitions.isNotEmpty)
                  Chip(
                    avatar: const Icon(Icons.tune, size: 18),
                    label: Text(
                      'Параметрів: ${template.customFieldDefinitions.length}',
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isSaving
                        ? null
                        : () => _confirmSyncTemplateLessons(template),
                    icon: const Icon(Icons.sync_alt),
                    label: const Text('Оновити заняття за шаблоном'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isSaving
                        ? null
                        : () => _confirmMigrateTemplateLessons(template),
                    icon: const Icon(Icons.link),
                    label: const Text('Міграція старих занять'),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isSaving
                            ? null
                            : () => _openTemplateDialog(template: template),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Редагувати'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isSaving
                            ? null
                            : () => _confirmDeleteTemplate(template),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Видалити'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAutocompleteEditorCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Autocomplete дані',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Тут редагуються `locations`, `units` і `tags`, які використовуються у формах заняття та шаблонів.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 16),
            _buildAutocompleteSection(
              title: 'Локації',
              values: _templatesService.allLocations,
              onAdd: () =>
                  _showAddAutocompleteValueDialog('Локація', 'location'),
              onDelete: (value) => _removeAutocompleteValue('location', value),
            ),
            const SizedBox(height: 16),
            _buildAutocompleteSection(
              title: 'Підрозділи',
              values: _templatesService.allUnits,
              onAdd: () => _showAddAutocompleteValueDialog('Підрозділ', 'unit'),
              onDelete: (value) => _removeAutocompleteValue('unit', value),
            ),
            const SizedBox(height: 16),
            _buildAutocompleteSection(
              title: 'Теги',
              values: _templatesService.allTags,
              onAdd: () => _showAddAutocompleteValueDialog('Тег', 'tag'),
              onDelete: (value) => _removeAutocompleteValue('tag', value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAutocompleteSection({
    required String title,
    required List<String> values,
    required VoidCallback onAdd,
    required ValueChanged<String> onDelete,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: _isSaving ? null : onAdd,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Додати'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (values.isEmpty)
          Text('Поки порожньо', style: TextStyle(color: Colors.grey.shade600))
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: values
                .map(
                  (value) => InputChip(
                    label: Text(value),
                    onDeleted: _isSaving ? null : () => onDelete(value),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }

  Future<void> _openTemplateDialog({GroupTemplate? template}) async {
    final result = await showDialog<GroupTemplate>(
      context: context,
      builder: (context) => _TemplateEditorDialog(template: template),
    );

    if (result == null || !mounted) return;

    setState(() => _isSaving = true);
    try {
      final success = await _templatesService.saveTemplate(result);
      if (!mounted) return;

      if (success) {
        await _loadTemplates();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              template == null ? 'Шаблон створено' : 'Шаблон оновлено',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не вдалося зберегти шаблон'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _confirmDeleteTemplate(GroupTemplate template) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Видалити шаблон?'),
        content: Text('Шаблон "${template.title}" буде видалено безповоротно.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Скасувати'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Видалити'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isSaving = true);
    try {
      final success = await _templatesService.deleteTemplate(template.id);
      if (!mounted) return;

      if (success) {
        await _loadTemplates();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Шаблон видалено'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не вдалося видалити шаблон'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _confirmSyncTemplateLessons(GroupTemplate template) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Оновити пов’язані заняття?'),
        content: Text(
          'Будуть оновлені всі заняття, які прив’язані до шаблону "${template.title}".\n\n'
          'Оновляться: тип, опис, тривалість, нагадування, теги та кастомні параметри.\n\n'
          'Кастомні параметри з однаковим id у заняттях не будуть перезаписані.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Скасувати'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.sync_alt),
            label: const Text('Оновити'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isSaving = true);
    try {
      final result = await _templatesService.syncLessonsFromTemplate(template);
      if (!mounted) return;

      if (result.linkedLessons == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Для цього шаблону ще немає пов’язаних занять'),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Оновлено ${result.updatedLessons} занять за шаблоном "${template.title}"',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Не вдалося оновити заняття: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _confirmMigrateTemplateLessons(GroupTemplate template) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Мігрувати старі заняття?'),
        content: Text(
          'Будуть знайдені незавершені заняття без прив’язки до шаблону, '
          'у яких назва точно збігається з шаблоном "${template.title}".\n\n'
          'Для таких занять буде записано `templateId` і одразу застосовано '
          'оновлення типу, опису, тривалості, нагадувань, тегів та кастомних параметрів.\n\n'
          'Це одноразова дія для швидкого backfill старих занять.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Скасувати'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.link),
            label: const Text('Запустити міграцію'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isSaving = true);
    try {
      final result = await _templatesService.migrateUnlinkedLessonsForTemplate(
        template,
      );
      if (!mounted) return;

      if (result.matchedLessons == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Старих занять для міграції не знайдено. Перевіряються лише незавершені заняття з такою самою назвою.',
            ),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Міграція завершена: прив’язано та оновлено ${result.migratedLessons} занять',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Не вдалося виконати міграцію: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _showAddAutocompleteValueDialog(
    String label,
    String type,
  ) async {
    final controller = TextEditingController();

    final shouldSubmit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Додати: $label'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Скасувати'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Додати'),
          ),
        ],
      ),
    );

    if (shouldSubmit != true || !mounted) {
      controller.dispose();
      return;
    }

    setState(() => _isSaving = true);
    try {
      final value = controller.text.trim();
      if (value.isEmpty) return;

      switch (type) {
        case 'location':
          await _templatesService.addLocation(value);
          break;
        case 'unit':
          await _templatesService.addUnit(value);
          break;
        case 'tag':
          await _templatesService.addTag(value);
          break;
      }

      await _loadTemplates();
    } finally {
      controller.dispose();
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _removeAutocompleteValue(String type, String value) async {
    setState(() => _isSaving = true);
    try {
      switch (type) {
        case 'location':
          await _templatesService.removeLocation(value);
          break;
        case 'unit':
          await _templatesService.removeUnit(value);
          break;
        case 'tag':
          await _templatesService.removeTag(value);
          break;
      }

      await _loadTemplates();
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}

class _TemplateEditorDialog extends StatefulWidget {
  final GroupTemplate? template;

  const _TemplateEditorDialog({this.template});

  @override
  State<_TemplateEditorDialog> createState() => _TemplateEditorDialogState();
}

class _TemplateEditorDialogState extends State<_TemplateEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _locationController;
  late final TextEditingController _unitController;
  late final TextEditingController _durationController;
  late final TextEditingController _tagsController;

  late TemplateType _selectedType;
  late bool _isDefault;
  late List<LessonCustomFieldDefinition> _customFieldDefinitions;
  late List<LessonProgressReminder> _progressReminders;

  @override
  void initState() {
    super.initState();
    final template = widget.template;
    _titleController = TextEditingController(text: template?.title ?? '');
    _descriptionController = TextEditingController(
      text: template?.description ?? '',
    );
    _locationController = TextEditingController(text: template?.location ?? '');
    _unitController = TextEditingController(text: template?.unit ?? '');
    _durationController = TextEditingController(
      text: (template?.durationMinutes ?? 90).toString(),
    );
    _tagsController = TextEditingController(
      text: (template?.tags ?? const <String>[]).join(', '),
    );
    _selectedType = template?.type ?? TemplateType.lesson;
    _isDefault = template?.isDefault ?? false;
    _customFieldDefinitions = List<LessonCustomFieldDefinition>.from(
      template?.customFieldDefinitions ?? const <LessonCustomFieldDefinition>[],
    );
    _progressReminders = List<LessonProgressReminder>.from(
      template?.progressReminders ?? const <LessonProgressReminder>[],
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _unitController.dispose();
    _durationController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.template != null;

    return AlertDialog(
      title: Text(isEditing ? 'Редагувати шаблон' : 'Новий шаблон'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Назва шаблону *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Вкажіть назву';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<TemplateType>(
                  value: _selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Тип',
                    border: OutlineInputBorder(),
                  ),
                  items: TemplateType.values
                      .map(
                        (type) => DropdownMenuItem<TemplateType>(
                          value: type,
                          child: Text('${type.emoji} ${type.displayName}'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedType = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Опис',
                    border: OutlineInputBorder(),
                  ),
                  minLines: 3,
                  maxLines: 5,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _locationController,
                        decoration: const InputDecoration(
                          labelText: 'Місце',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _unitController,
                        decoration: const InputDecoration(
                          labelText: 'Підрозділ',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _durationController,
                  decoration: const InputDecoration(
                    labelText: 'Тривалість у хвилинах *',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    final duration = int.tryParse(value?.trim() ?? '');
                    if (duration == null || duration <= 0) {
                      return 'Вкажіть коректну тривалість';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                LessonProgressReminderEditor(
                  reminders: _progressReminders,
                  onChanged: (reminders) {
                    setState(() {
                      _progressReminders = reminders;
                    });
                  },
                  durationMinutes: int.tryParse(
                    _durationController.text.trim(),
                  ),
                  emptyText:
                      'Шаблон може містити типові нагадування, які скопіюються в заняття.',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _tagsController,
                  decoration: const InputDecoration(
                    labelText: 'Теги',
                    hintText: 'тактика, теорія, практика',
                    border: OutlineInputBorder(),
                    helperText: 'Розділяйте комами',
                  ),
                ),
                const SizedBox(height: 16),
                _buildCustomFieldsSection(),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _isDefault,
                  title: const Text('Позначити як базовий шаблон'),
                  onChanged: (value) => setState(() => _isDefault = value),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Скасувати'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(isEditing ? 'Зберегти' : 'Створити'),
        ),
      ],
    );
  }

  Widget _buildCustomFieldsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Кастомні параметри',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            TextButton.icon(
              onPressed: _addCustomFieldDefinition,
              icon: const Icon(Icons.add),
              label: const Text('Додати параметр'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_customFieldDefinitions.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Параметри цього шаблону ще не налаштовані.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          )
        else
          Column(
            children: _customFieldDefinitions.map((definition) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            definition.label,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${definition.code} • ${definition.type.displayName}',
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _editCustomFieldDefinition(definition),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      onPressed: () => _removeCustomFieldDefinition(definition),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Future<void> _addCustomFieldDefinition() async {
    final definition = await showCustomFieldDefinitionDialog(
      context,
      existingDefinitions: _customFieldDefinitions,
    );
    if (definition == null) return;

    setState(() {
      _customFieldDefinitions = [..._customFieldDefinitions, definition];
    });
  }

  Future<void> _editCustomFieldDefinition(
    LessonCustomFieldDefinition definition,
  ) async {
    final updatedDefinition = await showCustomFieldDefinitionDialog(
      context,
      initialDefinition: definition,
      existingDefinitions: _customFieldDefinitions,
    );
    if (updatedDefinition == null) return;

    setState(() {
      _customFieldDefinitions = _customFieldDefinitions
          .map(
            (item) => item.code == definition.code ? updatedDefinition : item,
          )
          .toList();
    });
  }

  void _removeCustomFieldDefinition(LessonCustomFieldDefinition definition) {
    setState(() {
      _customFieldDefinitions = _customFieldDefinitions
          .where((item) => item.code != definition.code)
          .toList();
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final currentUser = Globals.firebaseAuth.currentUser;
    final currentGroupId = Globals.profileManager.currentGroupId ?? '';
    final now = DateTime.now();
    final existing = widget.template;
    final tags = _tagsController.text
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toSet()
        .toList();

    final template = GroupTemplate(
      id: existing?.id ?? '',
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      location: _locationController.text.trim(),
      unit: _unitController.text.trim(),
      tags: tags,
      durationMinutes: int.parse(_durationController.text.trim()),
      type: _selectedType,
      isDefault: _isDefault,
      groupId: existing?.groupId ?? currentGroupId,
      createdBy: existing?.createdBy ?? currentUser?.uid ?? 'system',
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      customFieldDefinitions: _customFieldDefinitions,
      progressReminders: _progressReminders,
    );

    Navigator.of(context).pop(template);
  }
}

class _TemplateStatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final bool compact;

  const _TemplateStatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 16,
        vertical: compact ? 10 : 16,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: compact
          ? Row(
              children: [
                Icon(icon, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 2),
                      Text(
                        '$value • $subtitle',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 12)),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(subtitle, style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ],
            ),
    );
  }
}

class _TemplatesEmptyState extends StatelessWidget {
  const _TemplatesEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.description_outlined,
              size: 64,
              color: Colors.grey.shade500,
            ),
            const SizedBox(height: 16),
            const Text(
              'Шаблонів поки немає',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Створіть шаблон, щоб швидше заповнювати заняття в календарі.',
              style: TextStyle(color: Colors.grey.shade700),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
