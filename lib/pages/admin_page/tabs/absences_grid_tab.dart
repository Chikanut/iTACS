// lib/pages/admin_page/tabs/absences_grid_tab.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../globals.dart';
import '../../../models/instructor_absence.dart';
import '../../../models/lesson_model.dart';
import '../widgets/absence_assignment_dialog.dart';

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

  // 📐 Адаптивна логіка визначення режиму відображення
  bool _shouldUseMobileLayout(BuildContext context, List<DateTime> daysInMonth) {
    final screenWidth = MediaQuery.of(context).size.width;
    final availableWidth = screenWidth - 32; // margin
    
    // Розрахунок необхідної ширини для desktop режиму
    const instructorColumnWidth = 120;
    const minDayColumnWidth = 32;
    const daySpacing = 8; // мінімальний spacing між колонками
    
    final requiredWidth = instructorColumnWidth + 
                         (daysInMonth.length * minDayColumnWidth) + 
                         (daysInMonth.length * daySpacing);
    
    // Якщо не поміщається навіть з мінімальним spacing - переходимо в мобільний режим
    return requiredWidth > availableWidth;
  }

  // 📱 Адаптивна логіка для spacing між колонками
  double _calculateOptimalSpacing(BuildContext context, List<DateTime> daysInMonth) {
    final screenWidth = MediaQuery.of(context).size.width;
    final availableWidth = screenWidth - 32;
    
    const instructorColumnWidth = 120;
    const dayColumnWidth = 32;
    
    final totalDayColumnsWidth = daysInMonth.length * dayColumnWidth;
    final remainingWidth = availableWidth - instructorColumnWidth - totalDayColumnsWidth;
    
    // Розподіляємо залишковий простір між колонками
    final optimalSpacing = (remainingWidth / daysInMonth.length).clamp(4.0, 20.0);
    
    return optimalSpacing;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    final daysInMonth = _getDaysInMonth(_selectedMonth);
    final useMobileLayout = _shouldUseMobileLayout(context, daysInMonth);

    return SingleChildScrollView(
      child: Column(
        children: [
          // Заголовок з навігацією по місяцях
          _buildMonthNavigation(),
          
          const SizedBox(height: 16),
          
          // Інформаційна панель
          _buildAbsencesInfoPanel(),
          
          const SizedBox(height: 24),
          
          // Адаптивна сітка
          useMobileLayout 
              ? _buildMobileGrid(daysInMonth)
              : _buildResponsiveDesktopGrid(daysInMonth),
          
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
                _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
              });
              _loadData();
            },
            icon: const Icon(Icons.chevron_left),
          ),
          Text(
            DateFormat('MMMM yyyy', 'uk_UA').format(_selectedMonth),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
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
              ...daysInMonth.map((day) => DataColumn(
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
                        onTap: () => _showCellMenu(context, day, instructorId, instructorName),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: _getCellBackgroundColor(absence, lessons.isNotEmpty, day),
                            borderRadius: BorderRadius.circular(4),
                            border: absence != null || lessons.isNotEmpty
                                ? Border.all(color: Colors.grey.shade400, width: 1)
                                : null,
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

  // 🎨 Допоміжні методи (залишаються без змін)
  List<DateTime> _getDaysInMonth(DateTime month) {
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);
    
    return List.generate(
      lastDay.day,
      (index) => DateTime(month.year, month.month, index + 1),
    );
  }

  bool _isWeekend(DateTime day) {
    return day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
  }

  Color _getCellBackgroundColor(InstructorAbsence? absence, bool hasLessons, DateTime day) {
    if (absence != null) {
      switch (absence.status) {
        case AbsenceStatus.pending:
          return Colors.orange.shade100;
        case AbsenceStatus.active:
          return absence.type == AbsenceType.sickLeave
              ? Colors.red.shade100
              : Colors.yellow.shade100;
        case AbsenceStatus.cancelled:
          return Colors.grey.shade100;
        case AbsenceStatus.completed:
          return Colors.green.shade100;
      }
    }
    
    if (hasLessons) {
      return Colors.green.shade50;
    }
    
    if (_isWeekend(day)) {
      return Colors.grey.shade50;
    }
    
    return Colors.transparent;
  }

  Color _getCellTextColor(InstructorAbsence? absence, bool hasLessons, DateTime day) {
    if (absence != null) {
      switch (absence.status) {
        case AbsenceStatus.pending:
          return Colors.orange.shade800;
        case AbsenceStatus.active:
          return absence.type == AbsenceType.sickLeave 
              ? Colors.red.shade800 
              : Colors.amber.shade800;
        case AbsenceStatus.cancelled:
          return Colors.grey.shade600;
        case AbsenceStatus.completed:
          return Colors.green.shade600;
      }
    }
    
    if (hasLessons) {
      return Colors.green.shade800;
    }
    
    return _isWeekend(day) ? Colors.red.shade600 : Colors.black87;
  }

  String _getCellDisplayText(InstructorAbsence? absence, bool hasLessons) {
    if (absence != null) {
      return absence.type.emoji;
    }
    
    if (hasLessons) {
      return '📚';
    }
    
    return '';
  }

  void _showCellMenu(BuildContext context, DateTime day, String instructorId, String instructorName) {
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
            
            if (absence != null) ...[
              ListTile(
                leading: Text(absence.type.emoji, style: const TextStyle(fontSize: 24)),
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
                          _approveAbsence(absence.id);
                        },
                        icon: const Icon(Icons.check),
                        label: const Text('Підтвердити'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _rejectAbsence(absence.id);
                        },
                        icon: const Icon(Icons.close),
                        label: const Text('Відхилити'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      ),
                    ),
                  ],
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
            
            if (lessons.isNotEmpty) ...[
              const Divider(),
              Text('Заняття на цей день: ${lessons.length}'),
              ...lessons.take(3).map((lesson) => ListTile(
                dense: true,
                title: Text(lesson.title),
                subtitle: Text('${lesson.startTime} - ${lesson.endTime}'),
              )),
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

    _absencesGrid.clear();
    
    for (final absence in absences) {
      _absencesGrid.putIfAbsent(absence.instructorId, () => {});
      
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
  }

  Future<void> _loadLessons() async {
    // Завантаження занять для показу в клітинках
    _lessonsGrid.clear();
    // TODO: Реалізувати завантаження занять з календарю
  }

  Future<void> _loadAbsencesSummary() async {
    final allAbsences = await Globals.absencesService.getAllAbsencesForGroup();
    final now = DateTime.now();
    
    _pendingRequests = allAbsences.where((a) => a.status == AbsenceStatus.pending).toList();
    _currentAbsences = allAbsences.where((a) => 
      a.status == AbsenceStatus.active && 
      now.isAfter(a.startDate) && 
      now.isBefore(a.endDate.add(const Duration(days: 1)))
    ).toList();
    _upcomingAbsences = allAbsences.where((a) => 
      a.status == AbsenceStatus.active && 
      a.startDate.isAfter(now)
    ).toList();
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
          
          if (_pendingRequests.isEmpty && _currentAbsences.isEmpty && _upcomingAbsences.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green.shade600),
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
                  'Запити що очікують (${_pendingRequests.length})',
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
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person_off, color: Colors.red.shade700),
                const SizedBox(width: 8),
                Text(
                  'Поточні відсутності (${_currentAbsences.length})',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
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
                  child: const Text(
                    'Адмін',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${DateFormat('dd.MM.yyyy').format(absence.startDate)} - ${DateFormat('dd.MM.yyyy').format(absence.endDate)}',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
          if (absence.reason?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(
              'Причина: ${absence.reason}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
          if (showActions) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _approveAbsence(absence.id),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Підтвердити'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      minimumSize: const Size(0, 32),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _rejectAbsence(absence.id),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Відхилити'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      minimumSize: const Size(0, 32),
                    ),
                  ),
                ),
              ],
            ),
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
}