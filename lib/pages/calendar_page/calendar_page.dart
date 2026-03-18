// lib/pages/calendar_page/calendar_page.dart

import 'package:flutter/material.dart';
import 'models/calendar_view_type.dart';
import 'models/calendar_filters.dart';
import '../../models/lesson_model.dart';
import '../../services/templates_service.dart';
import '../../theme/app_theme.dart';
import '../../globals.dart';
import 'widgets/calendar_header.dart';
import 'widgets/calendar_grid.dart';
import 'widgets/lesson_details_dialog.dart';
import 'package:intl/intl.dart';
import 'widgets/lesson_form_dialog.dart';
import 'calendar_utils.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  CalendarViewType _viewType = CalendarViewType.week;
  DateTime _selectedDate = DateTime.now();
  int _refreshKey = 0; // Для примусового оновлення календаря
  CalendarFilters _filters = CalendarFilters.empty;
  List<Map<String, dynamic>> _groupMembers = [];
  bool _isLoadingFilterData = false;

  bool isMobile(BuildContext context) {
    final shortestSide = MediaQuery.of(context).size.shortestSide;
    return shortestSide < 600;
  }

  void _goToToday() {
    setState(() {
      _selectedDate = DateTime.now();
      _viewType = CalendarViewType.day;
      _refreshKey++;
    });
  }

  void _goToPrevious() {
    setState(() {
      switch (_viewType) {
        case CalendarViewType.day:
          _selectedDate = _selectedDate.subtract(const Duration(days: 1));
          break;
        case CalendarViewType.week:
          // 👈 ВИПРАВЛЕННЯ: йдемо точно на 7 днів назад від понеділка поточного тижня
          final startOfCurrentWeek = CalendarUtils.getStartOfWeek(
            _selectedDate,
          );
          _selectedDate = startOfCurrentWeek.subtract(const Duration(days: 7));
          break;
        case CalendarViewType.month:
          _selectedDate = DateTime(
            _selectedDate.year,
            _selectedDate.month - 1,
            1,
          );
          break;
        case CalendarViewType.year:
          _selectedDate = DateTime(_selectedDate.year - 1, 1, 1);
          break;
      }
      _refreshKey++;
    });
  }

  void _goToNext() {
    setState(() {
      switch (_viewType) {
        case CalendarViewType.day:
          _selectedDate = _selectedDate.add(const Duration(days: 1));
          break;
        case CalendarViewType.week:
          // 👈 ВИПРАВЛЕННЯ: йдемо точно на 7 днів вперед від понеділка поточного тижня
          final startOfCurrentWeek = CalendarUtils.getStartOfWeek(
            _selectedDate,
          );
          _selectedDate = startOfCurrentWeek.add(const Duration(days: 7));
          break;
        case CalendarViewType.month:
          _selectedDate = DateTime(
            _selectedDate.year,
            _selectedDate.month + 1,
            1,
          );
          break;
        case CalendarViewType.year:
          _selectedDate = DateTime(_selectedDate.year + 1, 1, 1);
          break;
      }
      _refreshKey++;
    });
  }

  void _showLessonDetails(LessonModel lesson) {
    showDialog(
      context: context,
      builder: (context) => LessonDetailsDialog(
        lesson: lesson,
        onUpdated: () {
          // Оновлюємо календар після змін
          setState(() {
            _refreshKey++;
          });
        },
      ),
    );
  }

  Future<void> _loadFilterData() async {
    if (_groupMembers.isNotEmpty || _isLoadingFilterData) {
      return;
    }

    final currentGroupId = Globals.profileManager.currentGroupId;
    if (currentGroupId == null) {
      return;
    }

    setState(() => _isLoadingFilterData = true);

    try {
      final members = await Globals.firestoreManager.getGroupMembersWithDetails(
        currentGroupId,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _groupMembers = members;
      });
    } finally {
      if (mounted) {
        setState(() => _isLoadingFilterData = false);
      }
    }
  }

  Future<void> _ensureFilterDataReady() async {
    await Future.wait([
      _loadFilterData(),
      Globals.groupTemplatesService.ensureInitializedForCurrentGroup(),
    ]);
  }

  void _createNewLesson() {
    showDialog(
      context: context,
      builder: (context) => LessonFormDialog(
        initialDate: _selectedDate.add(const Duration(days: 1)),
        initialStartTime: const TimeOfDay(hour: 8, minute: 15),
        onSaved: () {
          setState(() {
            _refreshKey++;
          });
        },
      ),
    );
  }

  String _getFormattedPeriod() {
    switch (_viewType) {
      case CalendarViewType.day:
        return DateFormat('dd MMMM yyyy', 'uk').format(_selectedDate);
      case CalendarViewType.week:
        final startOfWeek = _selectedDate.subtract(
          Duration(days: _selectedDate.weekday - 1),
        );
        final endOfWeek = startOfWeek.add(const Duration(days: 6));
        return '${DateFormat('dd MMM', 'uk').format(startOfWeek)} - ${DateFormat('dd MMM yyyy', 'uk').format(endOfWeek)}';
      case CalendarViewType.month:
        return DateFormat('MMMM yyyy', 'uk').format(_selectedDate);
      case CalendarViewType.year:
        return DateFormat('yyyy').format(_selectedDate);
    }
  }

  void _selectDate(DateTime date) {
    setState(() {
      _selectedDate = date;

      // Автоматично переключаємо тип перегляду залежно від поточного
      switch (_viewType) {
        case CalendarViewType.year:
          _viewType = CalendarViewType.month; // Рік → Місяць
          break;
        case CalendarViewType.month:
          _viewType = CalendarViewType.week; // Місяць → Тиждень
          break;
        case CalendarViewType.week:
          _viewType = CalendarViewType.day; // Тиждень → День
          break;
        case CalendarViewType.day:
          // День залишається днем
          break;
      }

      _refreshKey++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isOnMobileDevice = isMobile(context);

    Widget content;
    switch (_viewType) {
      case CalendarViewType.day:
        content = CalendarGrid(
          key: ValueKey('day_$_refreshKey'),
          viewType: _viewType,
          selectedDate: _selectedDate,
          filters: _filters,
          onLessonTap: _showLessonDetails,
          onDateSelected: _selectDate, // 👈 ДОДАТИ callback для вибору дати
        );
        break;
      case CalendarViewType.week:
        content = CalendarGrid(
          key: ValueKey('week_$_refreshKey'),
          viewType: _viewType,
          selectedDate: _selectedDate,
          filters: _filters,
          onLessonTap: _showLessonDetails,
          onDateSelected: _selectDate, // 👈 ДОДАТИ callback для вибору дати
        );
        break;
      case CalendarViewType.month:
        content = CalendarGrid(
          key: ValueKey('month_$_refreshKey'),
          viewType: _viewType,
          selectedDate: _selectedDate,
          filters: _filters,
          onLessonTap: _showLessonDetails,
          onDateSelected: _selectDate,
        );
        break;
      case CalendarViewType.year:
        content = CalendarGrid(
          key: ValueKey('year_$_refreshKey'),
          viewType: _viewType,
          selectedDate: _selectedDate,
          filters: _filters,
          onLessonTap: _showLessonDetails,
          onDateSelected: _selectDate,
        );
        break;
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Календар занять'),
            Text(
              _getFormattedPeriod(),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          // Кнопка оновлення
          IconButton(
            onPressed: () {
              setState(() {
                _refreshKey++;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Календар оновлено'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            icon: const Icon(Icons.refresh),
            tooltip: 'Оновити',
          ),
          // Кнопка фільтрів (поки заглушка)
          IconButton(
            onPressed: _showFiltersDialog,
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.filter_list),
                if (_filters.hasActiveFilters)
                  Positioned(
                    right: -6,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.infoStatus.border,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_filters.activeFiltersCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            tooltip: 'Фільтри',
          ),
        ],
      ),
      body: Column(
        children: [
          CalendarHeader(
            viewType: _viewType,
            selectedDate: _selectedDate,
            onViewTypeChange: (type) => setState(() {
              _viewType = type;
              _refreshKey++;
            }),
            onPrevious: _goToPrevious,
            onNext: _goToNext,
            onToday: _goToToday,
          ),
          const Divider(height: 1),
          Expanded(child: content),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewLesson,
        tooltip: 'Створити заняття',
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      // 👈 ПРИБРАТИ: bottomNavigationBar повністю видалена
    );
  }

  Future<void> _showFiltersDialog() async {
    final shouldShowLoader = _groupMembers.isEmpty;
    if (shouldShowLoader) {
      _showFilterLoadingDialog();
    }

    try {
      await _ensureFilterDataReady().timeout(const Duration(seconds: 3));
    } catch (_) {
      if (mounted && shouldShowLoader) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не вдалося завантажити фільтри. Спробуйте ще раз.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    if (mounted && shouldShowLoader) {
      Navigator.of(context, rootNavigator: true).pop();
    }

    if (!mounted) {
      return;
    }

    final result = await showModalBottomSheet<CalendarFilters>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _CalendarFiltersSheet(
        initialFilters: _filters,
        members: _groupMembers,
        templates: Globals.groupTemplatesService.getTemplates(),
      ),
    );

    if (result == null) {
      return;
    }

    setState(() {
      _filters = result;
      _refreshKey++;
    });
  }

  void _showFilterLoadingDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const PopScope(
        canPop: false,
        child: Dialog(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
                SizedBox(width: 16),
                Flexible(child: Text('Завантажуємо фільтри...')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CalendarFiltersSheet extends StatefulWidget {
  final CalendarFilters initialFilters;
  final List<Map<String, dynamic>> members;
  final List<GroupTemplate> templates;

  const _CalendarFiltersSheet({
    required this.initialFilters,
    required this.members,
    required this.templates,
  });

  @override
  State<_CalendarFiltersSheet> createState() => _CalendarFiltersSheetState();
}

class _CalendarFiltersSheetState extends State<_CalendarFiltersSheet> {
  late bool _showMineOnly;
  late Set<String> _selectedUsers;
  late Set<String> _selectedTemplates;

  @override
  void initState() {
    super.initState();
    _showMineOnly = widget.initialFilters.showMineOnly;
    _selectedUsers = Set<String>.from(widget.initialFilters.userIds);
    _selectedTemplates = Set<String>.from(widget.initialFilters.templateTitles);
  }

  @override
  Widget build(BuildContext context) {
    final memberOptions =
        widget.members
            .map((member) {
              final uid = ((member['uid'] as String?) ?? '').trim();
              final email = ((member['email'] as String?) ?? '')
                  .trim()
                  .toLowerCase();
              final id = uid.isNotEmpty && email.isNotEmpty
                  ? '$uid|$email'
                  : (uid.isNotEmpty ? uid : email);
              final name = ((member['fullName'] as String?) ?? '').trim();
              final label = name.isNotEmpty
                  ? name
                  : (((member['email'] as String?) ?? '').trim().isNotEmpty
                        ? (member['email'] as String).trim()
                        : 'Без імені');
              return (id: id, label: label);
            })
            .where((member) => member.id.isNotEmpty)
            .toList()
          ..sort((a, b) => a.label.compareTo(b.label));

    final templateTitles =
        widget.templates
            .map((template) => template.title.trim())
            .where((title) => title.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Фільтри календаря',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _resetFilters,
                    child: const Text('Скинути'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Показати мої'),
                subtitle: const Text(
                  'Показувати лише заняття, де ви призначені інструктором',
                ),
                value: _showMineOnly,
                onChanged: (value) => setState(() => _showMineOnly = value),
              ),
              _buildSection(
                title: 'Юзери',
                values: memberOptions.map((member) => member.id).toList(),
                selectedValues: _selectedUsers,
                labels: {
                  for (final member in memberOptions) member.id: member.label,
                },
              ),
              _buildSection(
                title: 'Шаблони',
                values: templateTitles,
                selectedValues: _selectedTemplates,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(
                      context,
                      CalendarFilters(
                        showMineOnly: _showMineOnly,
                        userIds: _selectedUsers,
                        templateTitles: _selectedTemplates,
                      ),
                    );
                  },
                  child: const Text('Застосувати'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<String> values,
    required Set<String> selectedValues,
    Map<String, String> labels = const {},
  }) {
    final options =
        values
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    if (options.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((value) {
              final isSelected = selectedValues.contains(value);
              return FilterChip(
                label: Text(labels[value] ?? value),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      selectedValues.add(value);
                    } else {
                      selectedValues.remove(value);
                    }
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _resetFilters() {
    setState(() {
      _showMineOnly = false;
      _selectedUsers.clear();
      _selectedTemplates.clear();
    });
  }
}
