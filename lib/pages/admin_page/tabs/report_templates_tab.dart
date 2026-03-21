import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../globals.dart';
import '../../../models/report_template_model.dart';
import '../../../services/report_templates_service.dart';
import '../../../services/reports/quick_report_dialog.dart';

class ReportTemplatesTab extends StatefulWidget {
  const ReportTemplatesTab({super.key});

  @override
  State<ReportTemplatesTab> createState() => _ReportTemplatesTabState();
}

class _ReportTemplatesTabState extends State<ReportTemplatesTab> {
  final ReportTemplatesService _service = Globals.reportTemplatesService;

  bool _isLoading = true;
  bool _isSaving = false;
  List<ReportTemplate> _templates = const [];

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final templates = await _service.getTemplates();
      if (!mounted) return;
      setState(() {
        _templates = templates;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      Globals.errorNotificationManager.showError(
        'Не вдалося завантажити шаблони звітів: ${e.toString()}',
      );
    }
  }

  Future<void> _openTemplateEditor({ReportTemplate? template}) async {
    final result = await showDialog<ReportTemplate>(
      context: context,
      builder: (context) => _ReportTemplateEditorDialog(template: template),
    );

    if (result == null) return;

    setState(() => _isSaving = true);
    final success = await _service.saveTemplate(result);
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (!success) {
      Globals.errorNotificationManager.showError(
        'Не вдалося зберегти шаблон звіту',
      );
      return;
    }

    await _loadTemplates();
    if (!mounted) return;
    Globals.errorNotificationManager.showSuccess(
      template == null ? 'Шаблон звіту створено' : 'Шаблон звіту оновлено',
    );
  }

  Future<void> _previewTemplate(ReportTemplate template) async {
    await showQuickReportDialog(
      context: context,
      reportTitle: template.name,
      onGenerate: (startDate, endDate) async {
        try {
          final preview = await _service.previewTemplate(
            templateId: template.id,
            useDraft: true,
            startDate: startDate,
            endDate: endDate,
          );
          if (!mounted) return;
          await showDialog<void>(
            context: context,
            builder: (context) =>
                _ReportTemplatePreviewDialog(preview: preview),
          );
        } catch (e) {
          if (!mounted) return;
          Globals.errorNotificationManager.showError(
            'Помилка preview звіту: ${e.toString()}',
          );
        }
      },
    );
  }

  Future<void> _publishTemplate(ReportTemplate template) async {
    try {
      setState(() => _isSaving = true);
      await _service.publishTemplate(template.id);
      if (!mounted) return;
      setState(() => _isSaving = false);
      await _loadTemplates();
      if (!mounted) return;
      Globals.errorNotificationManager.showSuccess(
        'Чернетку опубліковано як активний шаблон',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      Globals.errorNotificationManager.showError(
        'Помилка публікації: ${e.toString()}',
      );
    }
  }

  Future<void> _confirmDelete(ReportTemplate template) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Видалити шаблон звіту?'),
        content: Text('Шаблон "${template.name}" буде видалено безповоротно.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Скасувати'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Видалити'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    setState(() => _isSaving = true);
    final success = await _service.deleteTemplate(template.id);
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (!success) {
      Globals.errorNotificationManager.showError(
        'Не вдалося видалити шаблон звіту',
      );
      return;
    }

    await _loadTemplates();
    if (!mounted) return;
    Globals.errorNotificationManager.showSuccess('Шаблон звіту видалено');
  }

  Widget _buildTemplateCard(ReportTemplate template) {
    final updatedAt = DateFormat('dd.MM.yyyy HH:mm').format(template.updatedAt);
    final isPublished = template.activeConfig != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  template.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Chip(
                  avatar: Icon(
                    template.isActive ? Icons.check_circle : Icons.edit_note,
                    size: 16,
                  ),
                  label: Text(template.status.displayName),
                  visualDensity: VisualDensity.compact,
                ),
                Chip(
                  label: Text('Доступ: ${template.allowedRoles.join(', ')}'),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Draft v${template.draftVersion}'
              '${isPublished ? ' • Active v${template.activeVersion}' : ''}'
              ' • Оновлено: $updatedAt',
              style: TextStyle(color: Colors.grey.shade700),
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
                ActionChip(
                  avatar: const Icon(Icons.visibility_outlined, size: 18),
                  label: const Text('Preview'),
                  onPressed: () => _previewTemplate(template),
                ),
                ActionChip(
                  avatar: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Редагувати'),
                  onPressed: () => _openTemplateEditor(template: template),
                ),
                ActionChip(
                  avatar: const Icon(Icons.publish_outlined, size: 18),
                  label: const Text('Опублікувати'),
                  onPressed: _isSaving
                      ? null
                      : () => _publishTemplate(template),
                ),
                ActionChip(
                  avatar: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Видалити'),
                  onPressed: _isSaving ? null : () => _confirmDelete(template),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCompactLayout = MediaQuery.of(context).size.width < 720;

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, isCompactLayout ? 12 : 16, 16, 8),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _ReportTemplateStatCard(
                icon: Icons.query_stats,
                title: 'Шаблони звітів',
                value: '${_templates.length}',
                subtitle: 'Для поточної групи',
              ),
              FilledButton.icon(
                onPressed: _isSaving ? null : () => _openTemplateEditor(),
                icon: const Icon(Icons.add),
                label: const Text('Новий шаблон звіту'),
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
                    children: _templates.isEmpty
                        ? const [_ReportTemplatesEmptyState()]
                        : _templates
                              .map(
                                (template) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _buildTemplateCard(template),
                                ),
                              )
                              .toList(),
                  ),
                ),
        ),
      ],
    );
  }
}

class _ReportTemplateStatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;

  const _ReportTemplateStatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(value, style: Theme.of(context).textTheme.titleMedium),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportTemplatesEmptyState extends StatelessWidget {
  const _ReportTemplatesEmptyState();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.query_stats_outlined,
              size: 48,
              color: Colors.grey.shade500,
            ),
            const SizedBox(height: 12),
            const Text(
              'Шаблонів звітів поки немає',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Створіть перший шаблон або відредагуйте seed-звіт, щоб вивести його на головну сторінку.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportTemplatePreviewDialog extends StatelessWidget {
  final ReportTemplatePreview preview;

  const _ReportTemplatePreviewDialog({required this.preview});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Preview: ${preview.templateName}'),
      content: SizedBox(
        width: 960,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Рядків: ${preview.totalRows}'),
              if (preview.warnings.isNotEmpty) ...[
                const SizedBox(height: 8),
                ...preview.warnings.map(
                  (warning) => Text(
                    '• $warning',
                    style: const TextStyle(color: Colors.orange),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: preview.columns
                      .map((column) => DataColumn(label: Text(column.label)))
                      .toList(),
                  rows: preview.sampleRows
                      .map(
                        (row) => DataRow(
                          cells: preview.columns
                              .map(
                                (column) =>
                                    DataCell(Text(row[column.key] ?? '')),
                              )
                              .toList(),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Закрити'),
        ),
      ],
    );
  }
}

class _ReportTemplateEditorDialog extends StatefulWidget {
  final ReportTemplate? template;

  const _ReportTemplateEditorDialog({this.template});

  @override
  State<_ReportTemplateEditorDialog> createState() =>
      _ReportTemplateEditorDialogState();
}

class _ReportTemplateEditorDialogState
    extends State<_ReportTemplateEditorDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _sheetNameController;

  late ReportTemplatePeriodField _periodField;
  late ReportTemplateRowMode _rowMode;
  late bool _freezeHeader;
  late bool _autoWidth;
  late List<String> _allowedRoles;
  late List<ReportTemplateColumn> _columns;
  late List<ReportTemplateFilter> _filters;
  late List<String> _groupBy;
  late List<ReportTemplateSort> _sort;
  late List<ReportTemplateTotal> _totals;

  @override
  void initState() {
    super.initState();
    final template = widget.template;
    final config =
        template?.draftConfig ?? buildDefaultLessonsListReportConfig();

    _nameController = TextEditingController(
      text: template?.name ?? 'Новий звіт',
    );
    _descriptionController = TextEditingController(
      text: template?.description ?? '',
    );
    _sheetNameController = TextEditingController(text: config.sheet.name);
    _periodField = config.periodField;
    _rowMode = config.rowMode;
    _freezeHeader = config.sheet.freezeHeader;
    _autoWidth = config.sheet.autoWidth;
    _allowedRoles = List<String>.from(
      template?.allowedRoles.isNotEmpty == true
          ? template!.allowedRoles
          : const ['viewer'],
    );
    _columns = List<ReportTemplateColumn>.from(config.columns);
    _filters = List<ReportTemplateFilter>.from(config.filters);
    _groupBy = List<String>.from(config.groupBy);
    _sort = List<ReportTemplateSort>.from(config.sort);
    _totals = List<ReportTemplateTotal>.from(config.totals);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _sheetNameController.dispose();
    super.dispose();
  }

  void _save() {
    if (_nameController.text.trim().isEmpty) {
      Globals.errorNotificationManager.showError('Вкажіть назву шаблону');
      return;
    }
    if (_columns.isEmpty) {
      Globals.errorNotificationManager.showError('Додайте хоча б одну колонку');
      return;
    }

    final draftConfig = ReportTemplateConfig(
      source: ReportTemplateSource.lessons,
      periodField: _periodField,
      rowMode: _rowMode,
      filters: _filters,
      columns: _columns,
      groupBy: _groupBy.where((item) => item.trim().isNotEmpty).toList(),
      sort: _sort,
      totals: _totals,
      sheet: ReportTemplateSheet(
        name: _sheetNameController.text.trim().isEmpty
            ? _nameController.text.trim()
            : _sheetNameController.text.trim(),
        freezeHeader: _freezeHeader,
        autoWidth: _autoWidth,
      ),
    );

    final currentUserId = Globals.firebaseAuth.currentUser?.uid ?? 'system';
    final now = DateTime.now();
    final current = widget.template;

    final result = current != null
        ? current.copyWith(
            name: _nameController.text.trim(),
            description: _descriptionController.text.trim(),
            allowedRoles: _allowedRoles,
            draftConfig: draftConfig,
            updatedAt: now,
            updatedBy: currentUserId,
          )
        : ReportTemplate(
            id: '',
            name: _nameController.text.trim(),
            description: _descriptionController.text.trim(),
            groupId: Globals.profileManager.currentGroupId ?? '',
            allowedRoles: _allowedRoles,
            status: ReportTemplateStatus.draft,
            draftConfig: draftConfig,
            activeConfig: null,
            draftVersion: 1,
            activeVersion: 0,
            createdBy: currentUserId,
            updatedBy: currentUserId,
            publishedBy: '',
            createdAt: now,
            updatedAt: now,
            publishedAt: null,
          );

    Navigator.of(context).pop(result);
  }

  Widget _buildColumnsSection(List<String> fieldSuggestions) {
    return _SectionCard(
      title: 'Колонки',
      onAdd: () {
        setState(() {
          _columns = [
            ..._columns,
            const ReportTemplateColumn(key: 'lesson.title', label: 'Назва'),
          ];
        });
      },
      child: Column(
        children: [
          for (var index = 0; index < _columns.length; index++)
            _EditableColumnRow(
              column: _columns[index],
              fieldSuggestions: fieldSuggestions,
              onChanged: (value) => setState(() => _columns[index] = value),
              onRemove: _columns.length <= 1
                  ? null
                  : () => setState(() => _columns.removeAt(index)),
            ),
        ],
      ),
    );
  }

  Widget _buildFiltersSection(List<String> fieldSuggestions) {
    return _SectionCard(
      title: 'Фільтри',
      onAdd: () {
        setState(() {
          _filters = [
            ..._filters,
            const ReportTemplateFilter(
              key: 'lesson.status',
              operator: ReportTemplateFilterOperator.eq,
              value: 'scheduled',
            ),
          ];
        });
      },
      child: Column(
        children: [
          for (var index = 0; index < _filters.length; index++)
            _EditableFilterRow(
              filter: _filters[index],
              fieldSuggestions: fieldSuggestions,
              onChanged: (value) => setState(() => _filters[index] = value),
              onRemove: () => setState(() => _filters.removeAt(index)),
            ),
        ],
      ),
    );
  }

  Widget _buildGroupBySection(List<String> fieldSuggestions) {
    final effectiveGroupBy = _groupBy.isEmpty
        ? const ['instructor.name']
        : _groupBy;

    return _SectionCard(
      title: 'Групування',
      onAdd: () {
        setState(() => _groupBy = [..._groupBy, 'instructor.name']);
      },
      child: Column(
        children: [
          for (var index = 0; index < effectiveGroupBy.length; index++)
            _EditableKeyChipRow(
              label: 'Поле групування',
              value: effectiveGroupBy[index],
              suggestions: fieldSuggestions,
              onChanged: (value) {
                setState(() {
                  if (_groupBy.isEmpty) {
                    _groupBy = [value];
                  } else {
                    _groupBy[index] = value;
                  }
                });
              },
              onRemove: _groupBy.isEmpty
                  ? null
                  : () => setState(() => _groupBy.removeAt(index)),
            ),
        ],
      ),
    );
  }

  Widget _buildSortSection(List<String> fieldSuggestions) {
    return _SectionCard(
      title: 'Сортування',
      onAdd: () {
        setState(() {
          _sort = [
            ..._sort,
            const ReportTemplateSort(
              key: 'lesson.startTime',
              dir: ReportTemplateSortDirection.asc,
            ),
          ];
        });
      },
      child: Column(
        children: [
          for (var index = 0; index < _sort.length; index++)
            _EditableSortRow(
              sort: _sort[index],
              fieldSuggestions: fieldSuggestions,
              onChanged: (value) => setState(() => _sort[index] = value),
              onRemove: () => setState(() => _sort.removeAt(index)),
            ),
        ],
      ),
    );
  }

  Widget _buildTotalsSection(List<String> fieldSuggestions) {
    return _SectionCard(
      title: 'Підсумки',
      onAdd: () {
        setState(() {
          _totals = [
            ..._totals,
            const ReportTemplateTotal(
              type: ReportTemplateTotalType.count,
              label: 'Всього записів',
            ),
          ];
        });
      },
      child: Column(
        children: [
          for (var index = 0; index < _totals.length; index++)
            _EditableTotalRow(
              total: _totals[index],
              fieldSuggestions: fieldSuggestions,
              onChanged: (value) => setState(() => _totals[index] = value),
              onRemove: () => setState(() => _totals.removeAt(index)),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customFieldSuggestions =
        Globals.groupTemplatesService
            .getTemplates()
            .expand((template) => template.customFieldDefinitions)
            .map((item) => 'custom.${item.code}')
            .toSet()
            .toList()
          ..sort();
    final fieldSuggestions = [
      ...kReportTemplateBaseFieldSuggestions,
      ...customFieldSuggestions,
    ];

    return AlertDialog(
      title: Text(
        widget.template == null
            ? 'Новий шаблон звіту'
            : 'Редагування шаблону звіту',
      ),
      content: SizedBox(
        width: 980,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Назва'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Опис'),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ['viewer', 'editor', 'admin'].map((role) {
                  final isSelected = _allowedRoles.contains(role);
                  return FilterChip(
                    label: Text(role),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _allowedRoles = {..._allowedRoles, role}.toList();
                        } else {
                          _allowedRoles = _allowedRoles
                              .where((item) => item != role)
                              .toList();
                        }
                        if (_allowedRoles.isEmpty) {
                          _allowedRoles = ['viewer'];
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<ReportTemplatePeriodField>(
                      value: _periodField,
                      decoration: const InputDecoration(
                        labelText: 'Поле періоду',
                      ),
                      items: ReportTemplatePeriodField.values
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value.displayName),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _periodField = value);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<ReportTemplateRowMode>(
                      value: _rowMode,
                      decoration: const InputDecoration(
                        labelText: 'Режим рядків',
                      ),
                      items: ReportTemplateRowMode.values
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value.displayName),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _rowMode = value);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _sheetNameController,
                decoration: const InputDecoration(
                  labelText: 'Назва аркуша Excel',
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Фіксувати заголовок'),
                value: _freezeHeader,
                onChanged: (value) => setState(() => _freezeHeader = value),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Автоширина колонок'),
                value: _autoWidth,
                onChanged: (value) => setState(() => _autoWidth = value),
              ),
              const SizedBox(height: 16),
              _buildColumnsSection(fieldSuggestions),
              const SizedBox(height: 16),
              _buildFiltersSection(fieldSuggestions),
              const SizedBox(height: 16),
              _buildGroupBySection(fieldSuggestions),
              const SizedBox(height: 16),
              _buildSortSection(fieldSuggestions),
              const SizedBox(height: 16),
              _buildTotalsSection(fieldSuggestions),
              const SizedBox(height: 16),
              Text(
                'Доступні поля: ${fieldSuggestions.join(', ')}',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Скасувати'),
        ),
        FilledButton(onPressed: _save, child: const Text('Зберегти')),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final VoidCallback onAdd;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.onAdd,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add),
                  tooltip: 'Додати',
                ),
              ],
            ),
            child,
          ],
        ),
      ),
    );
  }
}

class _EditableColumnRow extends StatelessWidget {
  final ReportTemplateColumn column;
  final List<String> fieldSuggestions;
  final ValueChanged<ReportTemplateColumn> onChanged;
  final VoidCallback? onRemove;

  const _EditableColumnRow({
    required this.column,
    required this.fieldSuggestions,
    required this.onChanged,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: _SimpleTextField(
              label: 'Ключ поля',
              initialValue: column.key,
              suggestions: fieldSuggestions,
              onChanged: (value) => onChanged(column.copyWith(key: value)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _SimpleTextField(
              label: 'Заголовок',
              initialValue: column.label,
              onChanged: (value) => onChanged(column.copyWith(label: value)),
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}

class _EditableFilterRow extends StatelessWidget {
  final ReportTemplateFilter filter;
  final List<String> fieldSuggestions;
  final ValueChanged<ReportTemplateFilter> onChanged;
  final VoidCallback onRemove;

  const _EditableFilterRow({
    required this.filter,
    required this.fieldSuggestions,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _SimpleTextField(
                  label: 'Поле',
                  initialValue: filter.key,
                  suggestions: fieldSuggestions,
                  onChanged: (value) => onChanged(filter.copyWith(key: value)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<ReportTemplateFilterOperator>(
                  value: filter.operator,
                  decoration: const InputDecoration(labelText: 'Оператор'),
                  items: ReportTemplateFilterOperator.values
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value.displayName),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      onChanged(filter.copyWith(operator: value));
                    }
                  },
                ),
              ),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _FilterValueEditor(filter: filter, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _FilterValueEditor extends StatelessWidget {
  final ReportTemplateFilter filter;
  final ValueChanged<ReportTemplateFilter> onChanged;

  const _FilterValueEditor({required this.filter, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    switch (filter.operator) {
      case ReportTemplateFilterOperator.inList:
        return _SimpleTextField(
          label: 'Значення через кому',
          initialValue: filter.values.join(', '),
          onChanged: (value) {
            onChanged(
              filter.copyWith(
                values: value
                    .split(',')
                    .map((item) => item.trim())
                    .where((item) => item.isNotEmpty)
                    .cast<Object>()
                    .toList(),
              ),
            );
          },
        );
      case ReportTemplateFilterOperator.dateBetween:
        return Row(
          children: [
            Expanded(
              child: _SimpleTextField(
                label: 'Початок ISO',
                initialValue: filter.start ?? '',
                onChanged: (value) => onChanged(filter.copyWith(start: value)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SimpleTextField(
                label: 'Кінець ISO',
                initialValue: filter.end ?? '',
                onChanged: (value) => onChanged(filter.copyWith(end: value)),
              ),
            ),
          ],
        );
      case ReportTemplateFilterOperator.exists:
        return DropdownButtonFormField<bool>(
          value: filter.value is bool ? filter.value as bool : true,
          decoration: const InputDecoration(labelText: 'Поле існує'),
          items: const [
            DropdownMenuItem(value: true, child: Text('Так')),
            DropdownMenuItem(value: false, child: Text('Ні')),
          ],
          onChanged: (value) {
            if (value != null) {
              onChanged(filter.copyWith(value: value));
            }
          },
        );
      case ReportTemplateFilterOperator.lteNow:
        return const Align(
          alignment: Alignment.centerLeft,
          child: Text('Додаткове значення не потрібне'),
        );
      case ReportTemplateFilterOperator.eq:
      case ReportTemplateFilterOperator.neq:
      case ReportTemplateFilterOperator.contains:
        return _SimpleTextField(
          label: 'Значення',
          initialValue: filter.value?.toString() ?? '',
          onChanged: (value) => onChanged(filter.copyWith(value: value)),
        );
    }
  }
}

class _EditableKeyChipRow extends StatelessWidget {
  final String label;
  final String value;
  final List<String> suggestions;
  final ValueChanged<String> onChanged;
  final VoidCallback? onRemove;

  const _EditableKeyChipRow({
    required this.label,
    required this.value,
    required this.suggestions,
    required this.onChanged,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: _SimpleTextField(
              label: label,
              initialValue: value,
              suggestions: suggestions,
              onChanged: onChanged,
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}

class _EditableSortRow extends StatelessWidget {
  final ReportTemplateSort sort;
  final List<String> fieldSuggestions;
  final ValueChanged<ReportTemplateSort> onChanged;
  final VoidCallback onRemove;

  const _EditableSortRow({
    required this.sort,
    required this.fieldSuggestions,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: _SimpleTextField(
              label: 'Поле',
              initialValue: sort.key,
              suggestions: fieldSuggestions,
              onChanged: (value) => onChanged(sort.copyWith(key: value)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<ReportTemplateSortDirection>(
              value: sort.dir,
              decoration: const InputDecoration(labelText: 'Напрям'),
              items: ReportTemplateSortDirection.values
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(value.displayName),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  onChanged(sort.copyWith(dir: value));
                }
              },
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}

class _EditableTotalRow extends StatelessWidget {
  final ReportTemplateTotal total;
  final List<String> fieldSuggestions;
  final ValueChanged<ReportTemplateTotal> onChanged;
  final VoidCallback onRemove;

  const _EditableTotalRow({
    required this.total,
    required this.fieldSuggestions,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final needsKey =
        total.type == ReportTemplateTotalType.countDistinct ||
        total.type == ReportTemplateTotalType.sum;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<ReportTemplateTotalType>(
                  value: total.type,
                  decoration: const InputDecoration(labelText: 'Агрегат'),
                  items: ReportTemplateTotalType.values
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value.displayName),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      onChanged(total.copyWith(type: value));
                    }
                  },
                ),
              ),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (needsKey)
            _SimpleTextField(
              label: 'Поле для агрегата',
              initialValue: total.key,
              suggestions: fieldSuggestions,
              onChanged: (value) => onChanged(total.copyWith(key: value)),
            ),
          if (needsKey) const SizedBox(height: 8),
          _SimpleTextField(
            label: 'Label',
            initialValue: total.label,
            onChanged: (value) => onChanged(total.copyWith(label: value)),
          ),
        ],
      ),
    );
  }
}

class _SimpleTextField extends StatefulWidget {
  final String label;
  final String initialValue;
  final List<String> suggestions;
  final ValueChanged<String> onChanged;

  const _SimpleTextField({
    required this.label,
    required this.initialValue,
    required this.onChanged,
    this.suggestions = const [],
  });

  @override
  State<_SimpleTextField> createState() => _SimpleTextFieldState();
}

class _SimpleTextFieldState extends State<_SimpleTextField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(covariant _SimpleTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue &&
        _controller.text != widget.initialValue) {
      _controller.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      decoration: InputDecoration(
        labelText: widget.label,
        helperText: widget.suggestions.isEmpty
            ? null
            : 'Наприклад: ${widget.suggestions.take(4).join(', ')}',
      ),
      onChanged: widget.onChanged,
    );
  }
}
