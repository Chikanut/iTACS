import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/instructor_absence.dart';
import '../../../globals.dart';
import '../widgets/absence_assignment_dialog.dart';

class AbsencesGridTab extends StatefulWidget {
  const AbsencesGridTab({super.key});

  @override
  State<AbsencesGridTab> createState() => _AbsencesGridTabState();
}

class _AbsencesGridTabState extends State<AbsencesGridTab> {
  DateTime _selectedMonth = DateTime.now();
  List<Map<String, dynamic>> _instructors = [];
  Map<String, Map<DateTime, InstructorAbsence?>> _absencesGrid = {};
  Map<String, Map<DateTime, List<String>>> _lessonsGrid = {};
  List<InstructorAbsence> _pendingRequests = [];
  List<InstructorAbsence> _upcomingAbsences = [];
  List<InstructorAbsence> _currentAbsences = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      // Адаптивна календарна сітка
                      _buildAdaptiveGrid(),
                      
                      const SizedBox(height: 24),
                      
                      // Панель з запитами та наближаючимися відсутностями
                      _buildAbsencesInfoPanel(),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, 2),
            blurRadius: 4,
            color: Colors.black.withOpacity(0.1),
          ),
        ],
      ),
      child: Row(
        children: [
          // Навігація по місяцях
          IconButton(
            onPressed: () => _changeMonth(-1),
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Center(
              child: Text(
                DateFormat('MMMM yyyy', 'uk_UA').format(_selectedMonth),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: () => _changeMonth(1),
            icon: const Icon(Icons.chevron_right),
          ),
          
          const SizedBox(width: 16),
          
          // Кнопка оновлення
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Оновити дані',
          ),
          
          // Легенда
          PopupMenuButton<String>(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Легенда',
            itemBuilder: (context) => [
              const PopupMenuItem(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Символи:', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    _LegendItem(symbol: 'З', meaning: 'Заняття'),
                    _LegendItem(symbol: 'Х', meaning: 'Лікарняний'),
                    _LegendItem(symbol: 'В', meaning: 'Відпустка'),
                    _LegendItem(symbol: 'ВД', meaning: 'Відрядження'),
                    _LegendItem(symbol: 'Н', meaning: 'Наряд'),
                    SizedBox(height: 8),
                    Text('Кольори:', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text('• Помаранчевий - очікує підтвердження'),
                    Text('• Синій - призначено адміном'),
                    Text('• Інші - підтверджені запити'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdaptiveGrid() {
    final daysInMonth = _getDaysInMonth();
    final screenWidth = MediaQuery.of(context).size.width;
    final isNarrowScreen = screenWidth < 1200;
    
    if (isNarrowScreen) {
      // Мобільна/планшетна версія - картки замість таблиці
      return _buildMobileGrid(daysInMonth);
    } else {
      // Десктопна версія - таблиця з горизонтальним скролом
      return _buildDesktopGrid(daysInMonth);
    }
  }

  Widget _buildMobileGrid(List<DateTime> daysInMonth) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: _instructors.map((instructor) {
          final instructorName = instructor['fullName'] as String;
          final instructorId = instructor['uid'] as String;
          
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
                  child: _buildInstructorDaysGrid(instructorId, instructorName, daysInMonth),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildInstructorDaysGrid(String instructorId, String instructorName, List<DateTime> daysInMonth) {
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
          onTap: () => _showCellMenu(context, day, instructorId, instructorName),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(4),
              color: _getCellBackgroundColor(absence, lessons.isNotEmpty, day),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${day.day}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: _isWeekend(day) ? Colors.red : Colors.black87,
                  ),
                ),
                if (absence != null || lessons.isNotEmpty)
                  Text(
                    _getCellDisplayText(absence, lessons.isNotEmpty),
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: absence?.isAdminAssignment == true 
                          ? FontWeight.bold 
                          : FontWeight.normal,
                      color: _getCellTextColor(absence, lessons.isNotEmpty, day),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktopGrid(List<DateTime> daysInMonth) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: MediaQuery.of(context).size.width - 32,
          ),
          child: DataTable(
            columnSpacing: 16,
            headingRowHeight: 56,
            dataRowHeight: 48,
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
              ...daysInMonth.map((day) => DataColumn(
                label: SizedBox(
                  width: 32,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${day.day}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        DateFormat('E', 'uk_UA').format(day),
                        style: TextStyle(
                          fontSize: 10,
                          color: _isWeekend(day) ? Colors.red : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              )),
            ],
            rows: _instructors.map((instructor) {
              final instructorName = instructor['fullName'] as String;
              final instructorId = instructor['uid'] as String;
              
              return DataRow(
                cells: [
                  DataCell(
                    SizedBox(
                      width: 120,
                      child: Text(
                        instructorName,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  ...daysInMonth.map((day) {
                    final absence = _absencesGrid[instructorId]?[day];
                    final lessons = _lessonsGrid[instructorId]?[day] ?? [];
                    
                    return DataCell(
                      SizedBox(
                        width: 32,
                        child: GestureDetector(
                          onTap: () => _showCellMenu(context, day, instructorId, instructorName),
                          child: Container(
                            height: 32,
                            decoration: BoxDecoration(
                              color: _getCellBackgroundColor(absence, lessons.isNotEmpty, day),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: Colors.grey.shade300,
                                width: 1,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                _getCellDisplayText(absence, lessons.isNotEmpty),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: absence?.isAdminAssignment == true 
                                      ? FontWeight.bold 
                                      : FontWeight.normal,
                                  color: _getCellTextColor(absence, lessons.isNotEmpty, day),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
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

  Widget _buildAbsencesInfoPanel() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Управління відсутностями',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // Запити що очікують підтвердження
          if (_pendingRequests.isNotEmpty) ...[
            _buildPendingRequestsCard(),
            const SizedBox(height: 16),
          ],
          
          // Поточні відсутності
          if (_currentAbsences.isNotEmpty) ...[
            _buildCurrentAbsencesCard(),
            const SizedBox(height: 16),
          ],
          
          // Наближаючі відсутності
          if (_upcomingAbsences.isNotEmpty) ...[
            _buildUpcomingAbsencesCard(),
            const SizedBox(height: 16),
          ],
          
          // Якщо немає жодних відсутностей
          if (_pendingRequests.isEmpty && _currentAbsences.isEmpty && _upcomingAbsences.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green.shade600),
                    const SizedBox(width: 12),
                    const Text('Немає активних відсутностей або запитів'),
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
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.pending_actions, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                Text(
                  'Запити що очікують підтвердження (${_pendingRequests.length})',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._pendingRequests.map((absence) => _buildAbsenceListItem(absence, showActions: true)),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentAbsencesCard() {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.event_busy, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  'Поточні відсутності (${_currentAbsences.length})',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._currentAbsences.map((absence) => _buildAbsenceListItem(absence)),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingAbsencesCard() {
    return Card(
      color: Colors.purple.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.schedule, color: Colors.purple.shade700),
                const SizedBox(width: 8),
                Text(
                  'Наближаючі відсутності (${_upcomingAbsences.length})',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.purple.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._upcomingAbsences.map((absence) => _buildAbsenceListItem(absence)),
          ],
        ),
      ),
    );
  }

  Widget _buildAbsenceListItem(InstructorAbsence absence, {bool showActions = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
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
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Адмін',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Період: ${DateFormat('dd.MM.yyyy').format(absence.startDate)} - ${DateFormat('dd.MM.yyyy').format(absence.endDate)}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          Text(
            'Причина: ${absence.reason}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          if (showActions) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton(
                  onPressed: () => _approveAbsence(absence.id),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: const Text('Підтвердити', style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _rejectAbsence(absence.id),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: const Text('Відхилити', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // === МЕТОДИ ЗАВАНТАЖЕННЯ ДАНИХ ===

// === МЕТОДИ ЗАВАНТАЖЕННЯ ДАНИХ ===

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      await Future.wait([
        _loadInstructors(),
        _loadAbsences(),
        _loadLessons(),
        _loadAbsencesInfo(),
      ]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Помилка завантаження даних: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadInstructors() async {
    final currentGroupId = Globals.profileManager.currentGroupId;
    if (currentGroupId == null) return;

    final members = await Globals.firestoreManager.getGroupMembersWithDetails(currentGroupId);
    _instructors = members;
  }

  Future<void> _loadAbsences() async {
    final firstDay = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final lastDay = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);

    final absences = await Globals.absencesService.getAbsencesForPeriod(
      startDate: firstDay,
      endDate: lastDay,
    );

    debugPrint('AbsencesGridTab: Завантажено ${absences.length} відсутностей');
    for (final absence in absences) {
      debugPrint('  - ${absence.instructorName}: ${absence.type.displayName} (${absence.status.displayName}) ${DateFormat('dd.MM').format(absence.startDate)}-${DateFormat('dd.MM').format(absence.endDate)}');
    }

    _absencesGrid.clear();
    
    for (final absence in absences) {
      _absencesGrid.putIfAbsent(absence.instructorId, () => {});
      
      // Заповнюємо всі дні періоду відсутності тільки для активних та pending статусів
      if (absence.status == AbsenceStatus.active || absence.status == AbsenceStatus.pending) {
        DateTime current = DateTime(absence.startDate.year, absence.startDate.month, absence.startDate.day);
        final end = DateTime(absence.endDate.year, absence.endDate.month, absence.endDate.day);
        
        while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
          if (current.month == _selectedMonth.month && current.year == _selectedMonth.year) {
            _absencesGrid[absence.instructorId]![current] = absence;
          }
          current = current.add(const Duration(days: 1));
        }
      }
    }
    
    debugPrint('AbsencesGridTab: Заповнено сітку для ${_absencesGrid.length} інструкторів');
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
      if (lesson.instructorId.isEmpty) continue;
      
      final lessonDate = DateTime(
        lesson.startTime.year,
        lesson.startTime.month,
        lesson.startTime.day,
      );
      
      _lessonsGrid.putIfAbsent(lesson.instructorId, () => {});
      _lessonsGrid[lesson.instructorId]!.putIfAbsent(lessonDate, () => []);
      _lessonsGrid[lesson.instructorId]![lessonDate]!.add(lesson.title);
    }
  }

  Future<void> _loadAbsencesInfo() async {
    try {
      final now = DateTime.now();
      final threeWeeksLater = now.add(const Duration(days: 21));
      
      // Отримуємо всі відсутності на найближчі 3 тижні
      final allAbsences = await Globals.absencesService.getAbsencesForPeriod(
        startDate: now.subtract(const Duration(days: 1)), // включаємо сьогодні
        endDate: threeWeeksLater,
      );

      _pendingRequests = allAbsences
          .where((a) => a.status == AbsenceStatus.pending)
          .toList();

      _currentAbsences = allAbsences
          .where((a) => a.status == AbsenceStatus.active && a.isActiveOnDate(now))
          .toList();

      _upcomingAbsences = allAbsences
          .where((a) => 
              a.status == AbsenceStatus.active && 
              a.startDate.isAfter(now) && 
              a.startDate.isBefore(threeWeeksLater))
          .toList();

      debugPrint('AbsencesInfo: Pending: ${_pendingRequests.length}, Current: ${_currentAbsences.length}, Upcoming: ${_upcomingAbsences.length}');
    } catch (e) {
      debugPrint('Помилка завантаження інфо про відсутності: $e');
    }
  }

  // === МЕТОДИ ДІЙ ===

  void _showCellMenu(BuildContext context, DateTime date, String instructorId, String instructorName) {
    final absence = _absencesGrid[instructorId]?[date];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${DateFormat('dd.MM.yyyy').format(date)} - $instructorName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (absence != null) ...[
              const Text('Поточна відсутність:'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: absence.displayColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: absence.displayColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${absence.type.emoji} ${absence.type.displayName}'),
                    Text('Період: ${DateFormat('dd.MM').format(absence.startDate)} - ${DateFormat('dd.MM').format(absence.endDate)}'),
                    Text('Причина: ${absence.reason}'),
                    Text('Статус: ${absence.status.displayName}'),
                  ],
                ),
              ),
            ] else ...[
              const Text('Відсутності не зареєстровано'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Закрити'),
          ),
          if (absence == null) ...[
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showAssignmentDialog(instructorId, instructorName, date);
              },
              child: const Text('Призначити'),
            ),
          ] else ...[
            if (absence.status == AbsenceStatus.pending) ...[
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _approveAbsence(absence.id);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text('Підтвердити'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _rejectAbsence(absence.id);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Відхилити'),
              ),
            ] else if (absence.status == AbsenceStatus.active) ...[
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _cancelAbsence(absence.id);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child: const Text('Скасувати'),
              ),
            ],
          ],
        ],
      ),
    );
  }

  void _showAssignmentDialog(String instructorId, String instructorName, DateTime date) {
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

  Future<void> _approveAbsence(String absenceId) async {
    try {
      await Globals.absencesService.approveAbsenceRequest(absenceId);
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Запит підтверджено'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Помилка: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rejectAbsence(String absenceId) async {
    try {
      await Globals.absencesService.rejectAbsenceRequest(absenceId);
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Запит відхилено'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Помилка: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _cancelAbsence(String absenceId) async {
    try {
      await Globals.absencesService.cancelAbsence(absenceId);
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Відсутність скасовано'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Помилка: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // === ДОПОМІЖНІ МЕТОДИ ===

  List<DateTime> _getDaysInMonth() {
    final firstDay = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final lastDay = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
    
    return List.generate(
      lastDay.day,
      (index) => DateTime(_selectedMonth.year, _selectedMonth.month, index + 1),
    );
  }

  bool _isWeekend(DateTime date) {
    return date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
  }

  void _changeMonth(int direction) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + direction,
        1,
      );
    });
    _loadData();
  }

  // Допоміжні методи для клітинок
  String _getCellDisplayText(InstructorAbsence? absence, bool hasLessons) {
    if (absence != null) {
      return absence.shortSymbol;
    }
    if (hasLessons) {
      return 'З';
    }
    return '';
  }

  Color _getCellBackgroundColor(InstructorAbsence? absence, bool hasLessons, DateTime date) {
    if (absence != null) {
      if (absence.status == AbsenceStatus.pending) {
        return Colors.orange.withOpacity(0.3);
      } else {
        return absence.displayColor.withOpacity(0.2);
      }
    }
    
    if (hasLessons) {
      return Colors.blue.shade50;
    }
    
    if (_isWeekend(date)) {
      return Colors.grey.shade100;
    }
    
    return Colors.white;
  }

  Color _getCellTextColor(InstructorAbsence? absence, bool hasLessons, DateTime date) {
    if (absence != null) {
      if (absence.status == AbsenceStatus.pending) {
        return Colors.orange.shade700;
      } else {
        return absence.displayColor;
      }
    }
    
    if (hasLessons) {
      return Colors.blue.shade700;
    }
    
    if (_isWeekend(date)) {
      return Colors.grey.shade600;
    }
    
    return Colors.black87;
  }
}

class _LegendItem extends StatelessWidget {
  final String symbol;
  final String meaning;

  const _LegendItem({
    required this.symbol,
    required this.meaning,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Center(
              child: Text(
                symbol,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(meaning),
        ],
      ),
    );
  }
}


