// lib/pages/calendar_page/calendar_page.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'models/calendar_view_type.dart';
import 'models/lesson_model.dart';
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
          final startOfCurrentWeek = CalendarUtils.getStartOfWeek(_selectedDate);
          _selectedDate = startOfCurrentWeek.subtract(const Duration(days: 7));
          break;
        case CalendarViewType.month:
          _selectedDate = DateTime(_selectedDate.year, _selectedDate.month - 1, 1);
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
          final startOfCurrentWeek = CalendarUtils.getStartOfWeek(_selectedDate);
          _selectedDate = startOfCurrentWeek.add(const Duration(days: 7));
          break;
        case CalendarViewType.month:
          _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + 1, 1);
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

  void _createNewLesson() {
    showDialog(
      context: context,
      builder: (context) => LessonFormDialog(
        initialDate: _selectedDate,
        initialStartTime: const TimeOfDay(hour: 9, minute: 0),
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
        final startOfWeek = _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
        final endOfWeek = startOfWeek.add(const Duration(days: 6));
        return '${DateFormat('dd MMM', 'uk').format(startOfWeek)} - ${DateFormat('dd MMM yyyy', 'uk').format(endOfWeek)}';
      case CalendarViewType.month:
        return DateFormat('MMMM yyyy', 'uk').format(_selectedDate);
      case CalendarViewType.year:
        return DateFormat('yyyy').format(_selectedDate);
    }
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
          onLessonTap: _showLessonDetails,
        );
        break;
      case CalendarViewType.week:
        content = CalendarGrid(
          key: ValueKey('week_$_refreshKey'),
          viewType: _viewType,
          selectedDate: _selectedDate,
          onLessonTap: _showLessonDetails,
        );
        break;
      case CalendarViewType.month:
        content = const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.calendar_month, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Місячний перегляд',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Буде реалізовано найближчим часом',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        );
        break;
      case CalendarViewType.year:
        content = const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.calendar_today, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Річний перегляд',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Буде реалізовано найближчим часом',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
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
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
              ),
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
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Фільтри будуть додані пізніше'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            icon: const Icon(Icons.filter_list),
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
      // Додаткова кнопка для швидкого переходу на сьогодні (мобільна версія)
      floatingActionButtonLocation: isOnMobileDevice 
        ? FloatingActionButtonLocation.endFloat
        : FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: isOnMobileDevice ? Container(
        height: 60,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: Border(
            top: BorderSide(color: Colors.grey.shade300),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildBottomNavButton(
              icon: Icons.today,
              label: 'День',
              isSelected: _viewType == CalendarViewType.day,
              onTap: () => setState(() {
                _viewType = CalendarViewType.day;
                _refreshKey++;
              }),
            ),
            _buildBottomNavButton(
              icon: Icons.view_week,
              label: 'Тиждень',
              isSelected: _viewType == CalendarViewType.week,
              onTap: () => setState(() {
                _viewType = CalendarViewType.week;
                _refreshKey++;
              }),
            ),
            _buildBottomNavButton(
              icon: Icons.calendar_month,
              label: 'Місяць',
              isSelected: _viewType == CalendarViewType.month,
              onTap: () => setState(() {
                _viewType = CalendarViewType.month;
                _refreshKey++;
              }),
            ),
            _buildBottomNavButton(
              icon: Icons.date_range,
              label: 'Рік',
              isSelected: _viewType == CalendarViewType.year,
              onTap: () => setState(() {
                _viewType = CalendarViewType.year;
                _refreshKey++;
              }),
            ),
          ],
        ),
      ) : null,
    );
  }

  Widget _buildBottomNavButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected 
                ? Theme.of(context).primaryColor 
                : Colors.grey.shade600,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected 
                  ? Theme.of(context).primaryColor 
                  : Colors.grey.shade600,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}