import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../../../globals.dart';
import '../../../../models/checklist_tool/checklist_tool_models.dart';
import '../../../../services/file_manager/file_sharer.dart';
import '../../../../services/local_file_picker_service.dart';
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
  final LocalFilePickerService _filePickerService = LocalFilePickerService();
  final FileSharer _fileSharer = FileSharer();
  final Uuid _uuid = const Uuid();
  late Future<_ChecklistHomeData> _future;

  bool get _canManage =>
      !Globals.appRuntimeState.isReadOnlyOffline &&
      Globals.profileManager.isCurrentGroupEditor;
  String? get _groupId => Globals.profileManager.currentGroupId;

  @override
  void initState() {
    super.initState();
    _future = _loadData();
  }

  Future<_ChecklistHomeData> _loadData() async {
    final groupId = _groupId;
    if (groupId == null) {
      return const _ChecklistHomeData();
    }

    await _service.migrateLegacyConfigsToGroupIfNeeded(groupId);
    var configs = await _service.loadAllConfigs(groupId);
    if (configs.isEmpty) {
      await _seedDefaults(groupId);
      configs = await _service.loadAllConfigs(groupId);
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

  Future<void> _seedDefaults(String groupId) async {
    try {
      final jsonString = await rootBundle.loadString(
        'assets/checklist_defaults/tank_lesson.json',
      );
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      await _service.saveConfig(groupId, ChecklistToolConfig.fromJson(decoded));
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
    final groupId = _groupId;
    if (groupId == null) {
      return;
    }

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

    await _service.saveConfig(groupId, duplicated);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Конфігурацію дубльовано')));
    }
  }

  Future<void> _deleteConfig(ChecklistToolConfig config) async {
    final groupId = _groupId;
    if (groupId == null) {
      return;
    }

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

    await _service.deleteConfig(groupId, config.id);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Конфігурацію видалено')));
    }
  }

  Future<void> _importFromJson() async {
    final groupId = _groupId;
    if (groupId == null) {
      return;
    }

    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'JSON', extensions: ['json']),
      ],
    );
    if (file == null) {
      return;
    }

    try {
      final content = await file.readAsString();
      final decoded = jsonDecode(content);
      final existingConfigs = await _service.loadAllConfigs(groupId);
      final existingIds = existingConfigs.map((item) => item.id).toSet();
      final importedConfigs = <ChecklistToolConfig>[];

      if (decoded is List) {
        for (final item in decoded.whereType<Map>()) {
          importedConfigs.add(
            _normalizeImportedConfig(
              ChecklistToolConfig.fromJson(Map<String, dynamic>.from(item)),
              existingIds,
            ),
          );
        }
      } else if (decoded is Map<String, dynamic>) {
        if (decoded['configs'] is List) {
          for (final item in (decoded['configs'] as List).whereType<Map>()) {
            importedConfigs.add(
              _normalizeImportedConfig(
                ChecklistToolConfig.fromJson(Map<String, dynamic>.from(item)),
                existingIds,
              ),
            );
          }
        } else {
          importedConfigs.add(
            _normalizeImportedConfig(
              ChecklistToolConfig.fromJson(decoded),
              existingIds,
            ),
          );
        }
      } else {
        throw const FormatException('Непідтримуваний формат JSON');
      }

      for (final config in importedConfigs) {
        await _service.saveConfig(groupId, config);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Імпортовано ${importedConfigs.length} конфігурацій'),
          ),
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не вдалося імпортувати JSON: $error')),
      );
    }
  }

  ChecklistToolConfig _normalizeImportedConfig(
    ChecklistToolConfig config,
    Set<String> occupiedIds,
  ) {
    var nextConfig = config;
    if (nextConfig.id.trim().isEmpty || occupiedIds.contains(nextConfig.id)) {
      nextConfig = nextConfig.copyWith(
        id: _uuid.v4(),
        title: '${nextConfig.title} (імпорт)',
      );
    }
    occupiedIds.add(nextConfig.id);
    return nextConfig;
  }

  Future<void> _exportConfig(ChecklistToolConfig config) async {
    await _exportJsonPayload(
      payload: config.toJson(),
      fileName:
          '${_filePickerService.titleFromFileName(config.title.replaceAll(RegExp(r'[\\\\/:*?"<>|]'), '_'))}.json',
      successMessage: 'Конфігурацію експортовано',
    );
  }

  Future<void> _exportAllConfigs() async {
    final groupId = _groupId;
    if (groupId == null) {
      return;
    }

    final configs = await _service.loadAllConfigs(groupId);
    await _exportJsonPayload(
      payload: {
        'exportedAt': DateTime.now().toIso8601String(),
        'configs': configs.map((item) => item.toJson()).toList(),
      },
      fileName: 'checklist_tool_configs.json',
      successMessage: 'Архів конфігурацій експортовано',
    );
  }

  Future<void> _exportJsonPayload({
    required Object payload,
    required String fileName,
    required String successMessage,
  }) async {
    try {
      final encoder = const JsonEncoder.withIndent('  ');
      final bytes = Uint8List.fromList(utf8.encode(encoder.convert(payload)));
      await _fileSharer.shareFile(bytes, fileName);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не вдалося експортувати JSON: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupId = _groupId;
    if (groupId == null) {
      return const Scaffold(body: Center(child: Text('Групу не знайдено')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Чеклісти занять'),
        actions: [
          if (_canManage)
            PopupMenuButton<String>(
              onSelected: (value) async {
                switch (value) {
                  case 'import':
                    await _importFromJson();
                    break;
                  case 'export_all':
                    await _exportAllConfigs();
                    break;
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'import',
                  child: ListTile(
                    leading: Icon(Icons.file_upload_outlined),
                    title: Text('Імпорт JSON'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'export_all',
                  child: ListTile(
                    leading: Icon(Icons.file_download_outlined),
                    title: Text('Експорт усіх'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
        ],
      ),
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

          return StreamBuilder<List<ChecklistToolConfig>>(
            stream: _service.watchAllConfigs(groupId),
            initialData: snapshot.data?.configs,
            builder: (context, configsSnapshot) {
              final data = snapshot.data ?? const _ChecklistHomeData();
              final configs =
                  configsSnapshot.data ?? snapshot.data?.configs ?? const [];

              if (configs.isEmpty) {
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
                  itemCount: configs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final config = configs[index];
                    final progress = data.progress[config.id];
                    final checked = progress?.checked ?? 0;
                    final total = config.totalChecklistItems;
                    final progressValue = total == 0 ? 0.0 : checked / total;

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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                              Text('Поточна сесія: $checked/$total'),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
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
              leading: const Icon(Icons.file_download_outlined),
              title: const Text('Експорт JSON'),
              onTap: () => Navigator.of(context).pop('export'),
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
        break;
      case 'duplicate':
        await _duplicateConfig(config);
        break;
      case 'export':
        await _exportConfig(config);
        break;
      case 'delete':
        await _deleteConfig(config);
        break;
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
