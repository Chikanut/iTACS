import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../globals.dart';
import '../../../../models/checklist_tool/checklist_tool_models.dart';
import '../../../../services/checklist_tool_service.dart';
import '../../../../utils/template_renderer.dart';
import '../../../../widgets/tool_field_widget.dart';
import 'checklist_config_editor_page.dart';

class ChecklistLessonPage extends StatefulWidget {
  const ChecklistLessonPage({super.key, required this.initialConfig});

  final ChecklistToolConfig initialConfig;

  @override
  State<ChecklistLessonPage> createState() => _ChecklistLessonPageState();
}

class _ChecklistLessonPageState extends State<ChecklistLessonPage> {
  final ChecklistToolService _service = ChecklistToolService();

  late ChecklistToolConfig _config;
  ChecklistSessionState? _sessionState;
  Map<String, String> _globalFieldValues = {};
  bool _isLoading = true;

  bool get _canManage =>
      !Globals.appRuntimeState.isReadOnlyOffline &&
      Globals.profileManager.isCurrentGroupEditor;
  String? get _groupId => Globals.profileManager.currentGroupId;

  @override
  void initState() {
    super.initState();
    _config = widget.initialConfig;
    _loadState();
  }

  Future<void> _loadState() async {
    final session = await _service.loadSessionState(_config.id);
    final values = await _service.loadGlobalFieldValues();
    if (!mounted) {
      return;
    }

    setState(() {
      _sessionState = session;
      _globalFieldValues = values;
      _isLoading = false;
    });
  }

  Future<void> _toggleChecklistItem(String itemId, bool isChecked) async {
    final current = _sessionState;
    if (current == null) {
      return;
    }

    final nextCheckedItems = current.checkedItems.toSet();
    if (isChecked) {
      nextCheckedItems.add(itemId);
    } else {
      nextCheckedItems.remove(itemId);
    }

    final nextState = current.copyWith(checkedItems: nextCheckedItems);
    setState(() {
      _sessionState = nextState;
    });
    await _service.saveSessionState(nextState);
  }

  Future<void> _updateGlobalField(UserField field, String value) async {
    setState(() {
      _globalFieldValues = {..._globalFieldValues, field.id: value};
    });

    if (field.isGlobal) {
      await _service.saveGlobalFieldValue(field.id, value);
    }
  }

  Future<void> _resetSession() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Скинути сесію?'),
        content: const Text(
          'Усі позначені пункти поточної добової сесії буде очищено.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Скасувати'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Скинути'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    await _service.resetSession(_config.id);
    await _loadState();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Сесію скинуто')));
    }
  }

  Future<void> _editConfig() async {
    final groupId = _groupId;
    if (groupId == null) {
      return;
    }

    final didSave = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ChecklistConfigEditorPage(initialConfig: _config),
      ),
    );
    if (didSave != true) {
      return;
    }

    final updatedConfig = await _service.loadConfigById(groupId, _config.id);
    if (updatedConfig == null) {
      return;
    }

    setState(() {
      _config = updatedConfig;
      _isLoading = true;
    });
    await _loadState();
  }

  void _showCopiedSnackBar() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Скопійовано')));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _sessionState == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Text(
                _config.emoji?.trim().isNotEmpty == true
                    ? _config.emoji!
                    : '📋',
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(_config.title)),
            ],
          ),
          actions: [
            IconButton(
              onPressed: _resetSession,
              icon: const Icon(Icons.restart_alt),
              tooltip: 'Скинути сесію',
            ),
            if (_canManage)
              IconButton(
                onPressed: _editConfig,
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Редагувати конфігурацію',
              ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: '📋 Чеклісти'),
              Tab(text: 'ℹ️ Довідка'),
              Tab(text: '📝 Шаблони'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ChecklistTab(
              config: _config,
              checkedItems: _sessionState!.checkedItems,
              onToggle: _toggleChecklistItem,
            ),
            _InfoCardsTab(
              infoCards: _config.infoCards,
              onCopied: _showCopiedSnackBar,
            ),
            _TemplatesTab(
              config: _config,
              globalValues: _globalFieldValues,
              onGlobalFieldChanged: _updateGlobalField,
              onCopied: _showCopiedSnackBar,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChecklistTab extends StatelessWidget {
  const _ChecklistTab({
    required this.config,
    required this.checkedItems,
    required this.onToggle,
  });

  final ChecklistToolConfig config;
  final Set<String> checkedItems;
  final Future<void> Function(String itemId, bool isChecked) onToggle;

  @override
  Widget build(BuildContext context) {
    if (config.sections.isEmpty) {
      return const _TabEmptyState(
        icon: Icons.checklist_rtl_outlined,
        title: 'Чеклісти ще не додані',
        message: 'Додайте першу секцію в редакторі конфігурації.',
      );
    }

    final totalItems = config.totalChecklistItems;
    final completedItems = checkedItems.length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Загальний прогрес',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: totalItems == 0 ? 0.0 : completedItems / totalItems,
                ),
                const SizedBox(height: 8),
                Text('$completedItems / $totalItems виконано'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ...config.sections.map((section) {
          final sectionTotal = section.items.length;
          final sectionCompleted = section.items
              .where((item) => checkedItems.contains(item.id))
              .length;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    title: Text(
                      '${section.emoji?.trim().isNotEmpty == true ? '${section.emoji} ' : ''}${section.title}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    trailing: Text('$sectionCompleted/$sectionTotal'),
                  ),
                  ...section.items.map((item) {
                    final isChecked = checkedItems.contains(item.id);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        decoration: BoxDecoration(
                          color: isChecked
                              ? Colors.green.withOpacity(0.12)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: CheckboxListTile(
                          value: isChecked,
                          title: Text(item.text),
                          onChanged: (value) =>
                              onToggle(item.id, value ?? false),
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _InfoCardsTab extends StatelessWidget {
  const _InfoCardsTab({required this.infoCards, required this.onCopied});

  final List<InfoCard> infoCards;
  final VoidCallback onCopied;

  @override
  Widget build(BuildContext context) {
    if (infoCards.isEmpty) {
      return const _TabEmptyState(
        icon: Icons.info_outline,
        title: 'Довідка ще не додана',
        message:
            'Адміністратор може додати картки з поясненнями та пам’ятками.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: infoCards.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final card = infoCards[index];
        final accentColor = Color(
          card.accentColor ?? Theme.of(context).colorScheme.primary.value,
        );

        return Card(
          clipBehavior: Clip.antiAlias,
          child: Container(
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: accentColor, width: 6)),
            ),
            child: ExpansionTile(
              title: Text(card.title),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: card.content),
                      );
                      onCopied();
                    },
                    icon: const Icon(Icons.copy_outlined),
                    label: const Text('Копіювати'),
                  ),
                ),
                SelectableText(card.content),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TemplatesTab extends StatefulWidget {
  const _TemplatesTab({
    required this.config,
    required this.globalValues,
    required this.onGlobalFieldChanged,
    required this.onCopied,
  });

  final ChecklistToolConfig config;
  final Map<String, String> globalValues;
  final Future<void> Function(UserField field, String value)
  onGlobalFieldChanged;
  final VoidCallback onCopied;

  @override
  State<_TemplatesTab> createState() => _TemplatesTabState();
}

class _TemplatesTabState extends State<_TemplatesTab> {
  final Map<String, Map<String, String>> _templateValues = {};

  @override
  Widget build(BuildContext context) {
    if (widget.config.templates.isEmpty) {
      return const _TabEmptyState(
        icon: Icons.edit_note_outlined,
        title: 'Шаблони ще не додані',
        message: 'Додайте перший шаблон у редакторі конфігурації.',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (widget.config.userFields.isNotEmpty) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Загальні поля',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _FieldGrid(
                    children: widget.config.userFields
                        .map((field) {
                          return ToolFieldWidget(
                            field: field.toTemplateField(),
                            value: widget.globalValues[field.id],
                            onChanged: (value) {
                              widget.onGlobalFieldChanged(field, value);
                            },
                          );
                        })
                        .toList(growable: false),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        ...widget.config.templates.map((template) {
          final values = _templateValues[template.id] ?? const {};
          final preview = TemplateRenderer.render(template.body, {
            ...widget.globalValues,
            ...values,
          });

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ExpansionTile(
              title: Text(template.title),
              subtitle: Text('${template.fields.length} полів'),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                if (template.fields.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _FieldGrid(
                    children: template.fields
                        .map((field) {
                          return ToolFieldWidget(
                            field: field,
                            value: values[field.id],
                            onChanged: (value) {
                              setState(() {
                                _templateValues[template.id] = {
                                  ...values,
                                  field.id: value,
                                };
                              });
                            },
                          );
                        })
                        .toList(growable: false),
                  ),
                  const SizedBox(height: 16),
                ],
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Попередній перегляд',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SelectableText(preview),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: preview));
                      widget.onCopied();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: _templateColor(template.buttonColor),
                    ),
                    icon: const Icon(Icons.copy_outlined),
                    label: const Text('Копіювати'),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Color _templateColor(TemplateColor color) {
    return switch (color) {
      TemplateColor.blue => Theme.of(context).colorScheme.primary,
      TemplateColor.red => Colors.red.shade700,
      TemplateColor.green => Colors.green.shade700,
      TemplateColor.orange => Colors.orange.shade700,
    };
  }
}

class _FieldGrid extends StatelessWidget {
  const _FieldGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;
        final spacing = 12.0;
        final itemWidth = isWide
            ? (constraints.maxWidth - spacing) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: children
              .map((child) => SizedBox(width: itemWidth, child: child))
              .toList(growable: false),
        );
      },
    );
  }
}

class _TabEmptyState extends StatelessWidget {
  const _TabEmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 72, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
