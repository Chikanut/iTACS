import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/instructor_absence.dart';
import '../../../globals.dart';
import '../widgets/absence_assignment_dialog.dart';
import '../widgets/absence_grid_cell.dart';

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
              : _buildGrid(),
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
                    Text('• Синій - призначено адміном'),
                    Text('• Інші - запити користувачів'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    final daysInMonth = _getDaysInMonth();
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          columnSpacing: 24,
          headingRowHeight: 56,
          dataRowHeight: 48,
          columns: [
            const DataColumn(
              label: Text(
                'Інструктор',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            ...daysInMonth.map((day) => DataColumn(
              label: SizedBox(
                width: 40,
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
                    width: 150,
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
                    AbsenceGridCell(
                      date: day,
                      instructorId: instructorId,
                      instructorName: instructorName,
                      absence: absence,
                      hasLessons: lessons.isNotEmpty,
                      onTap: () => _showCellMenu(context, day, instructorId, instructorName),
                    ),
                  );
                }),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

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

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      await Future.wait([
        _loadInstructors(),
        _loadAbsences(),
        _loadLessons(),
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

    final groupData = await Globals.firestoreManager.getDocumentsForGroup(
      groupId: currentGroupId,
      collection: 'allowed_users',
    );

    if (groupData.isNotEmpty) {
      final data = groupData.first.data() as Map<String, dynamic>;
      final members = Map<String, dynamic>.from(data['members'] ?? {});
      
      _instructors = members.entries
          .map((entry) => Map<String, dynamic>.from(entry.value))
          .where((member) => member['uid'] != null && member['fullName'] != null)
          .toList();
      
      _instructors.sort((a, b) => (a['fullName'] as String).compareTo(b['fullName'] as String));
    }
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
      
      // Заповнюємо всі дні періоду відсутності
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
              Text('Поточна відсутність:'),
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
          ] else if (absence.status == AbsenceStatus.pending) ...[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _approveAbsence(absence.id);
              },
              child: const Text('Підтвердити'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _rejectAbsence(absence.id);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Відхилити'),
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