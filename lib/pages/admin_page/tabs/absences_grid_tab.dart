// lib/pages/admin_page/tabs/absences_grid_tab.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../globals.dart';
import '../../../models/instructor_absence.dart';
import '../../../models/lesson_model.dart';
import '../../../theme/app_theme.dart';
import '../../calendar_page/calendar_utils.dart';
import '../../calendar_page/widgets/lesson_details_dialog.dart';
import '../widgets/absence_assignment_dialog.dart';

enum _LessonCellStatus { none, acknowledged, pending, urgent }

class AbsencesGridTab extends StatefulWidget {
  const AbsencesGridTab({super.key});

  @override
  State<AbsencesGridTab> createState() => _AbsencesGridTabState();
}

class _AbsencesGridTabState extends State<AbsencesGridTab> {
  DateTime _selectedMonth = DateTime.now();
  List<Map<String, dynamic>> _instructors = [];
  Map<String, Map<DateTime, InstructorAbsence>> _absencesGrid = {};
  Map<String, Map<DateTime, List<LessonModel>>> _lessonsGrid = {};

  List<InstructorAbsence> _pendingRequests = [];
  List<InstructorAbsence> _currentAbsences = [];
  List<InstructorAbsence> _upcomingAbsences = [];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      await Future.wait([
        _loadInstructors(),
        _loadAbsences(),
        _loadLessons(),
        _loadAbsencesSummary(),
      ]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Помилка завантаження даних: ${e.toString()}'),
            backgroundColor: AppTheme.dangerStatus.border,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // 📐 Адаптивна логіка визначення режиму відображення
  bool _shouldUseMobileLayout(
    BuildContext context,
    List<DateTime> daysInMonth,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final availableWidth = screenWidth - 32; // margin

    // Розрахунок необхідної ширини для desktop режиму
    const instructorColumnWidth = 120;
    const minDayColumnWidth = 32;
    const daySpacing = 8; // мінімальний spacing між колонками

    final requiredWidth =
        instructorColumnWidth +
        (daysInMonth.length * minDayColumnWidth) +
        (daysInMonth.length * daySpacing);

    // Якщо не поміщається навіть з мінімальним spacing - переходимо в мобільний режим
    return requiredWidth > availableWidth;
  }

  // 📱 Адаптивна логіка для spacing між колонками
  double _calculateOptimalSpacing(
    BuildContext context,
    List<DateTime> daysInMonth,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final availableWidth = screenWidth - 32;

    const instructorColumnWidth = 120;
    const dayColumnWidth = 32;

    final totalDayColumnsWidth = daysInMonth.length * dayColumnWidth;
    final remainingWidth =
        availableWidth - instructorColumnWidth - totalDayColumnsWidth;

    // Розподіляємо залишковий простір між колонками
    final optimalSpacing = (remainingWidth / daysInMonth.length).clamp(
      4.0,
      20.0,
    );

    return optimalSpacing;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final daysInMonth = _getDaysInMonth(_selectedMonth);
    final useMobileLayout = _shouldUseMobileLayout(context, daysInMonth);

    return SingleChildScrollView(
      child: Column(
        children: [
          // Заголовок з навігацією по місяцях
          _buildMonthNavigation(),

          const SizedBox(height: 16),

          // Адаптивна сітка
          useMobileLayout
              ? _buildMobileGrid(daysInMonth)
              : _buildResponsiveDesktopGrid(daysInMonth),

          const SizedBox(height: 24),

          // Інформаційна панель
          _buildAbsencesInfoPanel(),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildMonthNavigation() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () {
              setState(() {
                _selectedMonth = DateTime(
                  _selectedMonth.year,
                  _selectedMonth.month - 1,
                );
              });
              _loadData();
            },
            icon: const Icon(Icons.chevron_left),
          ),
          Text(
            DateFormat('MMMM yyyy', 'uk_UA').format(_selectedMonth),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _selectedMonth = DateTime(
                  _selectedMonth.year,
                  _selectedMonth.month + 1,
                );
              });
              _loadData();
            },
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  // 🖥️ Адаптивна desktop версія з розумним spacing
  Widget _buildResponsiveDesktopGrid(List<DateTime> daysInMonth) {
    final optimalSpacing = _calculateOptimalSpacing(context, daysInMonth);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceOverlay,
        border: Border.all(color: AppTheme.borderSubtle),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: MediaQuery.of(context).size.width - 32,
          ),
          child: DataTable(
            columnSpacing: optimalSpacing, // 🎯 Динамічний spacing
            headingRowHeight: 56,
            dataRowHeight: 48,
            horizontalMargin: 8,
            columns: [
              const DataColumn(
                label: SizedBox(
                  width: 120,
                  child: Text(
                    'Інструктор',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              ...daysInMonth.map(
                (day) => DataColumn(
                  label: Container(
                    width: 32,
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${day.day}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          DateFormat('E', 'uk_UA').format(day),
                          style: TextStyle(
                            fontSize: 10,
                            color: _isWeekend(day)
                                ? AppTheme.weekendStatus.badge
                                : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            rows: _instructors.map((instructor) {
              final instructorName = _memberDisplayName(instructor);
              final instructorId = _memberAssignmentId(instructor);

              return DataRow(
                cells: [
                  DataCell(
                    SizedBox(
                      width: 120,
                      child: Text(
                        instructorName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  ...daysInMonth.map((day) {
                    final absence = _absencesGrid[instructorId]?[day];
                    final lessons = _lessonsGrid[instructorId]?[day] ?? [];

                    return DataCell(
                      GestureDetector(
                        onTap: () => _showCellMenu(
                          context,
                          day,
                          instructorId,
                          instructorName,
                        ),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: _getCellBackgroundColor(
                              absence,
                              instructorId,
                              lessons,
                              day,
                            ),
                            borderRadius: BorderRadius.circular(4),
                            border: absence != null || lessons.isNotEmpty
                                ? Border.all(
                                    color: AppTheme.borderSubtle,
                                    width: 1,
                                  )
                                : null,
                          ),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned.fill(
                                child: _buildCellContent(
                                  absence: absence,
                                  instructorId: instructorId,
                                  lessons: lessons,
                                  day: day,
                                  compact: true,
                                ),
                              ),
                              _buildLessonCountBadge(
                                lessons: lessons,
                                compact: true,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // 📱 Мобільна версія залишається без змін
  Widget _buildMobileGrid(List<DateTime> daysInMonth) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: _instructors.map((instructor) {
          final instructorName = _memberDisplayName(instructor);
          final instructorId = _memberAssignmentId(instructor);

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ExpansionTile(
              title: Text(
                instructorName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildInstructorDaysGrid(
                    instructorId,
                    instructorName,
                    daysInMonth,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildInstructorDaysGrid(
    String instructorId,
    String instructorName,
    List<DateTime> daysInMonth,
  ) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7, // 7 днів на тиждень
        childAspectRatio: 1,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: daysInMonth.length,
      itemBuilder: (context, index) {
        final day = daysInMonth[index];
        final absence = _absencesGrid[instructorId]?[day];
        final lessons = _lessonsGrid[instructorId]?[day] ?? [];

        return GestureDetector(
          onTap: () =>
              _showCellMenu(context, day, instructorId, instructorName),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.borderSubtle),
              borderRadius: BorderRadius.circular(4),
              color: _getCellBackgroundColor(
                absence,
                instructorId,
                lessons,
                day,
              ),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${day.day}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: _isWeekend(day)
                              ? AppTheme.weekendStatus.foreground
                              : AppTheme.textPrimary,
                        ),
                      ),
                      if (absence != null || lessons.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Expanded(
                          child: _buildCellContent(
                            absence: absence,
                            instructorId: instructorId,
                            lessons: lessons,
                            day: day,
                            compact: false,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                _buildLessonCountBadge(lessons: lessons, compact: false),
              ],
            ),
          ),
        );
      },
    );
  }

  // 🎨 Допоміжні методи (залишаються без змін)
  List<DateTime> _getDaysInMonth(DateTime month) {
    final lastDay = DateTime(month.year, month.month + 1, 0);

    return List.generate(
      lastDay.day,
      (index) => DateTime(month.year, month.month, index + 1),
    );
  }

  bool _isWeekend(DateTime day) {
    return day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
  }

  Color _getCellBackgroundColor(
    InstructorAbsence? absence,
    String instructorId,
    List<LessonModel> lessons,
    DateTime day,
  ) {
    if (absence != null) {
      switch (absence.status) {
        case AbsenceStatus.pending:
          return AppTheme.warningStatus.background;
        case AbsenceStatus.active:
          return absence.type == AbsenceType.sickLeave
              ? AppTheme.dangerStatus.background
              : AppTheme.warningStatus.background;
        case AbsenceStatus.cancelled:
          return AppTheme.neutralStatus.background;
        case AbsenceStatus.completed:
          return AppTheme.successStatus.background;
      }
    }

    switch (_getLessonCellStatus(instructorId, lessons)) {
      case _LessonCellStatus.urgent:
        return AppTheme.dangerStatus.background;
      case _LessonCellStatus.pending:
        return AppTheme.warningStatus.background;
      case _LessonCellStatus.acknowledged:
        return AppTheme.successStatus.background.withOpacity(0.8);
      case _LessonCellStatus.none:
        break;
    }

    if (_isWeekend(day)) {
      return AppTheme.weekendStatus.background;
    }

    return AppTheme.surfaceRaised;
  }

  Color _getCellTextColor(
    InstructorAbsence? absence,
    String instructorId,
    List<LessonModel> lessons,
    DateTime day,
  ) {
    if (absence != null) {
      switch (absence.status) {
        case AbsenceStatus.pending:
          return AppTheme.warningStatus.foreground;
        case AbsenceStatus.active:
          return absence.type == AbsenceType.sickLeave
              ? AppTheme.dangerStatus.foreground
              : AppTheme.warningStatus.foreground;
        case AbsenceStatus.cancelled:
          return AppTheme.textSecondary;
        case AbsenceStatus.completed:
          return AppTheme.successStatus.foreground;
      }
    }

    switch (_getLessonCellStatus(instructorId, lessons)) {
      case _LessonCellStatus.urgent:
        return AppTheme.dangerStatus.foreground;
      case _LessonCellStatus.pending:
        return AppTheme.warningStatus.foreground;
      case _LessonCellStatus.acknowledged:
        return AppTheme.successStatus.foreground;
      case _LessonCellStatus.none:
        break;
    }

    return _isWeekend(day)
        ? AppTheme.weekendStatus.foreground
        : AppTheme.textPrimary;
  }

  String _getBaseCellDisplayText(
    InstructorAbsence? absence,
    List<LessonModel> lessons,
  ) {
    if (absence != null) {
      return absence.type.emoji;
    }

    if (lessons.isNotEmpty) {
      return '📚';
    }

    return '';
  }

  Widget _buildCellContent({
    required InstructorAbsence? absence,
    required String instructorId,
    required List<LessonModel> lessons,
    required DateTime day,
    required bool compact,
  }) {
    final baseText = _getBaseCellDisplayText(absence, lessons);
    final textColor = _getCellTextColor(absence, instructorId, lessons, day);

    if (baseText.isEmpty) {
      return const SizedBox.shrink();
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Align(
          alignment: Alignment.center,
          child: Text(
            baseText,
            style: TextStyle(
              fontSize: compact ? 11 : 10,
              fontWeight: absence?.isAdminAssignment == true
                  ? FontWeight.bold
                  : FontWeight.normal,
              color: textColor,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildLessonCountBadge({
    required List<LessonModel> lessons,
    required bool compact,
  }) {
    if (lessons.length <= 1) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: compact ? -3 : 2,
      right: compact ? -3 : 2,
      child: Container(
        constraints: BoxConstraints(
          minWidth: compact ? 16 : 18,
          minHeight: compact ? 16 : 18,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 3 : 4,
          vertical: compact ? 2 : 3,
        ),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white70, width: 1),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 2,
              offset: Offset(0, 1),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          '${lessons.length}',
          style: TextStyle(
            fontSize: compact ? 8 : 9,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            height: 1,
          ),
        ),
      ),
    );
  }

  void _showCellMenu(
    BuildContext context,
    DateTime day,
    String instructorId,
    String instructorName,
  ) {
    final absence = _absencesGrid[instructorId]?[day];
    final lessons = _lessonsGrid[instructorId]?[day] ?? [];

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$instructorName - ${DateFormat('dd MMMM yyyy', 'uk_UA').format(day)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 16),

            // 🎯 ЗАНЯТТЯ - ПОКАЗУЄМО СПОЧАТКУ
            if (lessons.isNotEmpty) ...[
              ListTile(
                leading: Icon(Icons.school, color: AppTheme.infoStatus.border),
                title: Text('Заняття (${lessons.length})'),
                subtitle: Text(lessons.map((l) => l.title).join(', ')),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  Navigator.pop(context);
                  _showLessonDetails(
                    context,
                    lessons,
                    instructorId,
                    instructorName,
                    day,
                  );
                },
              ),
              const Divider(),
            ],

            // ВІДСУТНОСТІ
            if (absence != null) ...[
              ListTile(
                leading: Text(
                  absence.type.emoji,
                  style: const TextStyle(fontSize: 24),
                ),
                title: Text(absence.type.displayName),
                subtitle: Text('Статус: ${absence.status.displayName}'),
              ),
              if (absence.status == AbsenceStatus.pending) ...[
                const Divider(),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _approveAbsence(absence);
                        },
                        icon: const Icon(Icons.check),
                        label: const Text('Підтвердити'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.successStatus.border,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _rejectAbsence(absence);
                        },
                        icon: const Icon(Icons.close),
                        label: const Text('Відхилити'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.dangerStatus.border,
                        ),
                      ),
                    ),
                  ],
                ),
              ] else if (absence.status == AbsenceStatus.active) ...[
                const Divider(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _cancelAbsence(absence);
                    },
                    icon: const Icon(Icons.cancel_schedule_send),
                    label: const Text('Скасувати відсутність'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.warningStatus.border,
                    ),
                  ),
                ),
              ],
            ] else ...[
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('Призначити відсутність'),
                onTap: () {
                  Navigator.pop(context);
                  _showAssignmentDialog(instructorId, instructorName, day);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Решта методів залишається без змін
  Future<void> _loadInstructors() async {
    final currentGroupId = Globals.profileManager.currentGroupId;
    if (currentGroupId == null) return;

    final members = await Globals.firestoreManager.getGroupMembersWithDetails(
      currentGroupId,
    );
    _instructors = members;
  }

  Future<void> _loadAbsences() async {
    final firstDay = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final lastDay = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);

    final absences = await Globals.absencesService.getAbsencesForPeriod(
      startDate: firstDay,
      endDate: lastDay,
    );

    _absencesGrid.clear();

    for (final absence in absences) {
      _absencesGrid.putIfAbsent(absence.instructorId, () => {});

      if (absence.status == AbsenceStatus.active ||
          absence.status == AbsenceStatus.pending) {
        DateTime current = DateTime(
          absence.startDate.year,
          absence.startDate.month,
          absence.startDate.day,
        );
        final end = DateTime(
          absence.endDate.year,
          absence.endDate.month,
          absence.endDate.day,
        );

        while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
          if (current.month == _selectedMonth.month &&
              current.year == _selectedMonth.year) {
            _absencesGrid[absence.instructorId]![current] = absence;
          }
          current = current.add(const Duration(days: 1));
        }
      }
    }
  }

  Future<void> _loadLessons() async {
    final firstDay = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final lastDay = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);

    final lessons = await Globals.calendarService.getLessonsForPeriod(
      startDate: firstDay,
      endDate: lastDay,
    );

    _lessonsGrid.clear();

    for (final lesson in lessons) {
      final lessonDate = DateTime(
        lesson.startTime.year,
        lesson.startTime.month,
        lesson.startTime.day,
      );

      for (final instructorId in lesson.instructorIds) {
        final normalizedInstructorId = _normalizeAssignmentId(instructorId);
        if (normalizedInstructorId.isEmpty) continue;

        _lessonsGrid.putIfAbsent(normalizedInstructorId, () => {});
        _lessonsGrid[normalizedInstructorId]!.putIfAbsent(lessonDate, () => []);
        _lessonsGrid[normalizedInstructorId]![lessonDate]!.add(lesson);
      }
    }
  }

  String _memberAssignmentId(Map<String, dynamic> member) {
    final uid = ((member['uid'] as String?) ?? '').trim();
    if (uid.isNotEmpty) {
      return _normalizeAssignmentId(uid);
    }
    return _normalizeAssignmentId((member['email'] as String?) ?? '');
  }

  String _memberDisplayName(Map<String, dynamic> member) {
    final fullName = ((member['fullName'] as String?) ?? '').trim();
    if (fullName.isNotEmpty) {
      return fullName;
    }
    final email = ((member['email'] as String?) ?? '').trim();
    return email.isNotEmpty ? email : 'Без імені';
  }

  String _normalizeAssignmentId(String value) {
    return LessonModel.normalizeInstructorAssignmentId(value);
  }

  List<String> _identityCandidatesForInstructor(String instructorId) {
    final normalizedInstructorId = _normalizeAssignmentId(instructorId);
    final candidates = <String>[normalizedInstructorId];

    for (final member in _instructors) {
      if (_memberAssignmentId(member) != normalizedInstructorId) continue;

      final email = ((member['email'] as String?) ?? '').trim();
      if (email.isNotEmpty) {
        candidates.add(_normalizeAssignmentId(email));
      }
    }

    return candidates.toSet().toList();
  }

  _LessonCellStatus _getLessonCellStatus(
    String instructorId,
    List<LessonModel> lessons,
  ) {
    if (lessons.isEmpty) return _LessonCellStatus.none;

    final identityCandidates = _identityCandidatesForInstructor(instructorId);
    var hasPending = false;

    for (final lesson in lessons) {
      final status = LessonStatusUtils.getAcknowledgementStatusForInstructor(
        lesson,
        instructorAssignmentId: instructorId,
        instructorIdentityCandidates: identityCandidates,
      );

      if (status == LessonAcknowledgementStatus.urgent) {
        return _LessonCellStatus.urgent;
      }

      if (status == LessonAcknowledgementStatus.pending) {
        hasPending = true;
      }
    }

    if (hasPending) {
      return _LessonCellStatus.pending;
    }

    return _LessonCellStatus.acknowledged;
  }

  LessonAcknowledgementStatus _getAcknowledgementStatus(
    LessonModel lesson,
    String instructorId,
  ) {
    return LessonStatusUtils.getAcknowledgementStatusForInstructor(
      lesson,
      instructorAssignmentId: instructorId,
      instructorIdentityCandidates: _identityCandidatesForInstructor(
        instructorId,
      ),
    );
  }

  String _getAcknowledgementSubtitle(LessonModel lesson, String instructorId) {
    return LessonStatusUtils.getAcknowledgementStatusText(
      lesson,
      instructorAssignmentId: instructorId,
      instructorIdentityCandidates: _identityCandidatesForInstructor(
        instructorId,
      ),
      acknowledgedAtFormatter: DateFormat('dd.MM.yyyy HH:mm'),
    );
  }

  void _showLessonDetails(
    BuildContext context,
    List<LessonModel> lessons,
    String instructorId,
    String instructorName,
    DateTime date,
  ) {
    if (lessons.length == 1) {
      _openLessonDetailsDialog(lessons.first);
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Заняття ${DateFormat('dd MMMM yyyy', 'uk_UA').format(date)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              'Інструктор: $instructorName',
              style: TextStyle(fontSize: 16, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: lessons.length,
                itemBuilder: (context, index) {
                  final lesson = lessons[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Icon(
                        lesson.isPast ? Icons.check_circle : Icons.schedule,
                        color: lesson.isPast
                            ? AppTheme.successStatus.border
                            : AppTheme.warningStatus.border,
                      ),
                      title: Text(lesson.title),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${DateFormat('HH:mm').format(lesson.startTime)} - ${DateFormat('HH:mm').format(lesson.endTime)}',
                          ),
                          if (lesson.groupName.isNotEmpty)
                            Text('Група: ${lesson.groupName}'),
                          if (lesson.location.isNotEmpty)
                            Text('Локація: ${lesson.location}'),
                          Text(
                            _getAcknowledgementSubtitle(lesson, instructorId),
                            style: TextStyle(
                              color: _getAcknowledgementStatus(
                                lesson,
                                instructorId,
                              ).color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      trailing: lesson.isPast
                          ? Icon(
                              Icons.done,
                              color: AppTheme.successStatus.border,
                            )
                          : null,
                      onTap: () {
                        Navigator.pop(context);
                        _openLessonDetailsDialog(lesson);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openLessonDetailsDialog(LessonModel lesson) {
    showDialog(
      context: context,
      builder: (dialogContext) =>
          LessonDetailsDialog(lesson: lesson, onUpdated: _loadData),
    );
  }

  Future<void> _loadAbsencesSummary() async {
    final allAbsences = await Globals.absencesService.getAllAbsencesForGroup();
    final now = DateTime.now();

    _pendingRequests = allAbsences
        .where((a) => a.status == AbsenceStatus.pending)
        .toList();
    _currentAbsences = allAbsences
        .where(
          (a) =>
              a.status == AbsenceStatus.active &&
              now.isAfter(a.startDate) &&
              now.isBefore(a.endDate.add(const Duration(days: 1))),
        )
        .toList();
    _upcomingAbsences = allAbsences
        .where(
          (a) => a.status == AbsenceStatus.active && a.startDate.isAfter(now),
        )
        .toList();
  }

  Widget _buildAbsencesInfoPanel() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Управління відсутностями',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          if (_pendingRequests.isNotEmpty) ...[
            _buildPendingRequestsCard(),
            const SizedBox(height: 16),
          ],

          if (_currentAbsences.isNotEmpty) ...[
            _buildCurrentAbsencesCard(),
            const SizedBox(height: 16),
          ],

          if (_upcomingAbsences.isNotEmpty) ...[
            _buildUpcomingAbsencesCard(),
            const SizedBox(height: 16),
          ],

          if (_pendingRequests.isEmpty &&
              _currentAbsences.isEmpty &&
              _upcomingAbsences.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: AppTheme.successStatus.border,
                    ),
                    const SizedBox(width: 12),
                    const Text('Нема активних відсутностей'),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPendingRequestsCard() {
    return Card(
      color: AppTheme.warningStatus.background,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.pending_actions,
                  color: AppTheme.warningStatus.border,
                ),
                const SizedBox(width: 8),
                Text(
                  'Запити що очікують (${_pendingRequests.length})',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.warningStatus.foreground,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._pendingRequests.map(
              (absence) => _buildAbsenceListItem(absence, showActions: true),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentAbsencesCard() {
    return Card(
      color: AppTheme.dangerStatus.background,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person_off, color: AppTheme.dangerStatus.border),
                const SizedBox(width: 8),
                Text(
                  'Поточні відсутності (${_currentAbsences.length})',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.dangerStatus.foreground,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._currentAbsences.map(
              (absence) => _buildAbsenceListItem(absence),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingAbsencesCard() {
    return Card(
      color: AppTheme.accentStatus.background,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.schedule, color: AppTheme.accentStatus.border),
                const SizedBox(width: 8),
                Text(
                  'Наближаючі відсутності (${_upcomingAbsences.length})',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.accentStatus.foreground,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._upcomingAbsences.map(
              (absence) => _buildAbsenceListItem(absence),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAbsenceListItem(
    InstructorAbsence absence, {
    bool showActions = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceRaised,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(absence.type.emoji),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${absence.instructorName} - ${absence.type.displayName}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              if (absence.isAdminAssignment)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.infoStatus.background,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Адмін',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.infoStatus.foreground,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${DateFormat('dd.MM.yyyy').format(absence.startDate)} - ${DateFormat('dd.MM.yyyy').format(absence.endDate)}',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          if (absence.reason?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(
              'Причина: ${absence.reason}',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
          ],
          if (showActions) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _approveAbsence(absence),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Підтвердити'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.successStatus.border,
                      minimumSize: const Size(0, 32),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _rejectAbsence(absence),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Відхилити'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.dangerStatus.border,
                      minimumSize: const Size(0, 32),
                    ),
                  ),
                ),
              ],
            ),
          ] else if (absence.status == AbsenceStatus.active) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _cancelAbsence(absence),
                icon: const Icon(Icons.cancel_schedule_send, size: 16),
                label: const Text('Скасувати відсутність'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.warningStatus.border,
                  side: BorderSide(color: AppTheme.warningStatus.border),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showAssignmentDialog(
    String instructorId,
    String instructorName,
    DateTime date,
  ) {
    showDialog(
      context: context,
      builder: (context) => AbsenceAssignmentDialog(
        instructorId: instructorId,
        instructorName: instructorName,
        initialDate: date,
        onAssigned: _loadData,
      ),
    );
  }

  Future<void> _approveAbsence(InstructorAbsence absence) async {
    try {
      await Globals.absencesService.approveAbsenceRequest(absence);
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Запит підтверджено'),
            backgroundColor: AppTheme.successStatus.border,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Помилка: ${e.toString()}'),
            backgroundColor: AppTheme.dangerStatus.border,
          ),
        );
      }
    }
  }

  Future<void> _rejectAbsence(InstructorAbsence absence) async {
    try {
      await Globals.absencesService.rejectAbsenceRequest(absence);
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Запит відхилено'),
            backgroundColor: AppTheme.warningStatus.border,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Помилка: ${e.toString()}'),
            backgroundColor: AppTheme.dangerStatus.border,
          ),
        );
      }
    }
  }

  Future<void> _cancelAbsence(InstructorAbsence absence) async {
    try {
      await Globals.absencesService.cancelAbsenceByAdmin(absence);
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Відсутність скасовано'),
            backgroundColor: AppTheme.warningStatus.border,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Помилка: ${e.toString()}'),
            backgroundColor: AppTheme.dangerStatus.border,
          ),
        );
      }
    }
  }
}
