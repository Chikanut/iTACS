import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../../../globals.dart';
import '../../../../models/checklist_tool/checklist_tool_models.dart';
import '../../../../services/checklist_tool_service.dart';
import 'checklist_config_editor_page.dart';
import 'checklist_lesson_page.dart';

class ChecklistBuilderHomePage extends StatefulWidget {
  const ChecklistBuilderHomePage({super.key});

  @override
  State<ChecklistBuilderHomePage> createState() =>
      _ChecklistBuilderHomePageState();
}

class _ChecklistBuilderHomePageState extends State<ChecklistBuilderHomePage> {
  final ChecklistToolService _service = ChecklistToolService();
  final Uuid _uuid = const Uuid();
  late Future<_ChecklistHomeData> _future;

  bool get _canManage =>
      !Globals.appRuntimeState.isReadOnlyOffline &&
      Globals.profileManager.isCurrentGroupEditor;

  @override
  void initState() {
    super.initState();
    _future = _loadData();
  }

  Future<_ChecklistHomeData> _loadData() async {
    var configs = await _service.loadAllConfigs();
    if (configs.isEmpty) {
      await _seedDefaults();
      configs = await _service.loadAllConfigs();
    }

    final progress = <String, _ChecklistProgress>{};
    for (final config in configs) {
      final session = await _service.loadSessionState(config.id);
      progress[config.id] = _ChecklistProgress(
        checked: session.checkedItems.length,
        total: config.totalChecklistItems,
      );
    }

    return _ChecklistHomeData(configs: configs, progress: progress);
  }

  Future<void> _seedDefaults() async {
    try {
      final jsonString = await rootBundle.loadString(
        'assets/checklist_defaults/tank_lesson.json',
      );
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      await _service.saveConfig(ChecklistToolConfig.fromJson(decoded));
    } catch (error) {
      debugPrint('ChecklistBuilder seed error: $error');
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _loadData();
    });
    await _future;
  }

  Future<void> _openLesson(ChecklistToolConfig config) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChecklistLessonPage(initialConfig: config),
      ),
    );
    await _refresh();
  }

  Future<void> _openEditor({ChecklistToolConfig? config}) async {
    final didSave = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ChecklistConfigEditorPage(initialConfig: config),
      ),
    );
    if (didSave == true) {
      await _refresh();
    }
  }

  Future<void> _duplicateConfig(ChecklistToolConfig config) async {
    final duplicated = ChecklistToolConfig(
      id: _uuid.v4(),
      title: '${config.title} (копія)',
      emoji: config.emoji,
      userFields: config.userFields
          .map((field) => field.copyWith(id: _uuid.v4()))
          .toList(growable: false),
      sections: config.sections
          .map(
            (section) => section.copyWith(
              id: _uuid.v4(),
              items: section.items
                  .map((item) => item.copyWith(id: _uuid.v4()))
                  .toList(growable: false),
            ),
          )
          .toList(growable: false),
      infoCards: config.infoCards
          .map((card) => card.copyWith(id: _uuid.v4()))
          .toList(growable: false),
      templates: config.templates
          .map(
            (template) => template.copyWith(
              id: _uuid.v4(),
              fields: template.fields
                  .map((field) => field.copyWith(id: _uuid.v4()))
                  .toList(growable: false),
            ),
          )
          .toList(growable: false),
    );

    await _service.saveConfig(duplicated);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Конфігурацію дубльовано')));
    }
    await _refresh();
  }

  Future<void> _deleteConfig(ChecklistToolConfig config) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Видалити конфігурацію?'),
        content: Text(
          'Конфігурацію "${config.title}" буде видалено разом із локальним станом сесії.',
        ),
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

    if (confirmed != true) {
      return;
    }

    await _service.deleteConfig(config.id);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Конфігурацію видалено')));
    }
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Чеклісти занять')),
      body: FutureBuilder<_ChecklistHomeData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _ChecklistEmptyState(
              icon: Icons.error_outline,
              title: 'Не вдалося завантажити інструмент',
              message: '${snapshot.error}',
              actionLabel: 'Спробувати ще раз',
              onAction: _refresh,
            );
          }

          final data = snapshot.data ?? const _ChecklistHomeData();
          if (data.configs.isEmpty) {
            return _ChecklistEmptyState(
              icon: Icons.fact_check_outlined,
              title: 'Конфігурації відсутні',
              message: _canManage
                  ? 'Додайте перше заняття або відредагуйте дефолтний приклад.'
                  : 'Адміністратор ще не додав жодної конфігурації.',
              actionLabel: _canManage ? 'Створити конфігурацію' : null,
              onAction: _canManage ? () => _openEditor() : null,
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: data.configs.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final config = data.configs[index];
                final progress =
                    data.progress[config.id] ?? const _ChecklistProgress();
                final progressValue = progress.total == 0
                    ? 0.0
                    : progress.checked / progress.total;

                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _openLesson(config),
                    onLongPress: _canManage
                        ? () => _showConfigMenu(context, config)
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                config.emoji?.trim().isNotEmpty == true
                                    ? config.emoji!
                                    : '📋',
                                style: const TextStyle(fontSize: 28),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      config.title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${config.sections.length} секц. • ${config.templates.length} шабл. • ${config.infoCards.length} довідк.',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_canManage)
                                IconButton(
                                  onPressed: () =>
                                      _showConfigMenu(context, config),
                                  icon: const Icon(Icons.more_vert),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          LinearProgressIndicator(value: progressValue),
                          const SizedBox(height: 8),
                          Text(
                            'Поточна сесія: ${progress.checked}/${progress.total}',
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: _canManage
          ? FloatingActionButton(
              onPressed: () => _openEditor(),
              tooltip: 'Створити конфігурацію',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Future<void> _showConfigMenu(
    BuildContext context,
    ChecklistToolConfig config,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Редагувати'),
              onTap: () => Navigator.of(context).pop('edit'),
            ),
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text('Дублювати'),
              onTap: () => Navigator.of(context).pop('duplicate'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Видалити'),
              onTap: () => Navigator.of(context).pop('delete'),
            ),
          ],
        ),
      ),
    );

    switch (action) {
      case 'edit':
        await _openEditor(config: config);
      case 'duplicate':
        await _duplicateConfig(config);
      case 'delete':
        await _deleteConfig(config);
    }
  }
}

class _ChecklistHomeData {
  const _ChecklistHomeData({this.configs = const [], this.progress = const {}});

  final List<ChecklistToolConfig> configs;
  final Map<String, _ChecklistProgress> progress;
}

class _ChecklistProgress {
  const _ChecklistProgress({this.checked = 0, this.total = 0});

  final int checked;
  final int total;
}

class _ChecklistEmptyState extends StatelessWidget {
  const _ChecklistEmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

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
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
