import 'package:flutter/material.dart';
import '../models/calendar_view_type.dart';
import 'lesson_card.dart';

class CalendarGrid extends StatefulWidget {
  final CalendarViewType viewType;
  final DateTime selectedDate;
  final List<String>? filteredGroups;
  final Function(Map<String, dynamic>)? onLessonTap;

  const CalendarGrid({
    super.key,
    required this.viewType,
    required this.selectedDate,
    this.filteredGroups,
    this.onLessonTap,
  });

  @override
  State<CalendarGrid> createState() => _CalendarGridState();
}

class _CalendarGridState extends State<CalendarGrid> {
  static const double timeColumnWidth = 60.0;
  static const double minHour = 7.0;
  static const double maxHour = 20.0;
  static const double hourHeight = 80.0;
  static const double minuteHeight = hourHeight / 60.0;

  // Мок-дані занять
  final List<Map<String, dynamic>> lessons = [
    {
      'id': '1',
      'dayOffset': 0,
      'start': const TimeOfDay(hour: 8, minute: 15),
      'end': const TimeOfDay(hour: 9, minute: 45),
      'title': 'Тактика',
      'group': '1-а рота',
      'instructor': 'Іванов І.І.',
      'location': 'Навчальний клас №1',
      'filled': 25,
      'total': 30,
      'color': const Color(0xFFE3F2FD),
      'tags': ['тактика', 'теорія'],
    },
    {
      'id': '2',
      'dayOffset': 0,
      'start': const TimeOfDay(hour: 8, minute: 15),
      'end': const TimeOfDay(hour: 9, minute: 45),
      'title': 'Фізпідготовка',
      'group': '2-а рота',
      'instructor': 'Петров П.П.',
      'location': 'Спортивний зал',
      'filled': 22,
      'total': 28,
      'color': const Color(0xFFF3E5F5),
      'tags': ['фізична', 'практика'],
    },
    {
      'id': '3',
      'dayOffset': 0,
      'start': const TimeOfDay(hour: 10, minute: 0),
      'end': const TimeOfDay(hour: 11, minute: 30),
      'title': 'Стройова',
      'group': '1-а рота',
      'instructor': 'Іванов І.І.',
      'location': 'Плац',
      'filled': 28,
      'total': 30,
      'color': const Color(0xFFE3F2FD),
      'tags': ['стройова', 'практика'],
    },
    {
      'id': '4',
      'dayOffset': 1,
      'start': const TimeOfDay(hour: 9, minute: 0),
      'end': const TimeOfDay(hour: 12, minute: 30),
      'title': 'Тактика',
      'group': '3-я рота',
      'instructor': 'Сидоров С.С.',
      'location': 'Навчальний клас №2',
      'filled': 18,
      'total': 25,
      'color': const Color(0xFFE8F5E8),
      'tags': ['тактика', 'теорія'],
    },
    {
      'id': '5',
      'dayOffset': 2,
      'start': const TimeOfDay(hour: 14, minute: 0),
      'end': const TimeOfDay(hour: 15, minute: 30),
      'title': 'Теорія',
      'group': '2-а рота',
      'instructor': 'Петров П.П.',
      'location': 'Актовий зал',
      'filled': 15,
      'total': 28,
      'color': const Color(0xFFF3E5F5),
      'tags': ['теорія'],
    },
    {
      'id': '6',
      'dayOffset': 4,
      'start': const TimeOfDay(hour: 16, minute: 0),
      'end': const TimeOfDay(hour: 17, minute: 30),
      'title': 'Стрільби',
      'group': '4-а рота',
      'instructor': 'Коваленко К.К.',
      'location': 'Тир',
      'filled': 12,
      'total': 20,
      'color': const Color(0xFFFFF3E0),
      'tags': ['стрільби', 'практика'],
    },
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final isTablet = constraints.maxWidth >= 600 && constraints.maxWidth < 1024;
        
        if (widget.viewType == CalendarViewType.day || isMobile) {
          return _buildMobileView(constraints);
        } else {
          return _buildDesktopView(constraints, isTablet);
        }
      },
    );
  }

  Widget _buildMobileView(BoxConstraints constraints) {
    return Column(
      children: [
        _buildMobileDateHeader(),
        const Divider(height: 1),
        Expanded(
          child: _buildMobileDayView(),
        ),
      ],
    );
  }

  Widget _buildDesktopView(BoxConstraints constraints, bool isTablet) {
    return Column(
      children: [
        _buildDesktopDateHeader(isTablet),
        const Divider(height: 1),
        Expanded(
          child: _buildDesktopWeekView(isTablet),
        ),
      ],
    );
  }

  Widget _buildMobileDateHeader() {
    final days = _getWeekDays();
    
    return Container(
      height: 80,
      child: PageView.builder(
        controller: PageController(
          initialPage: widget.selectedDate.weekday - 1,
          viewportFraction: 0.25,
        ),
        itemCount: days.length,
        itemBuilder: (context, index) {
          final day = days[index];
          final isToday = _isToday(day);
          final hasLessons = _hasLessonsOnDay(index);
          
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            decoration: BoxDecoration(
              color: isToday ? Theme.of(context).primaryColor : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isToday ? Theme.of(context).primaryColor : Colors.grey.shade300,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _getDayName(day.weekday),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isToday ? Colors.white : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  day.day.toString(),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isToday ? Colors.white : Colors.black,
                  ),
                ),
                if (hasLessons) ...[
                  const SizedBox(height: 4),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isToday ? Colors.white : Theme.of(context).primaryColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDesktopDateHeader(bool isTablet) {
    final days = _getWeekDays();
    
    return Container(
      height: 60,
      child: Row(
        children: [
          SizedBox(
            width: timeColumnWidth,
            child: Container(),
          ),
          ...days.asMap().entries.map((entry) {
            final index = entry.key;
            final day = entry.value;
            final isToday = _isToday(day);
            final hasLessons = _hasLessonsOnDay(index);
            
            return Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isToday ? Theme.of(context).primaryColor.withOpacity(0.1) : null,
                  border: Border(
                    right: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _getDayName(day.weekday),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          day.day.toString(),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isToday ? Theme.of(context).primaryColor : Colors.black,
                          ),
                        ),
                        if (hasLessons) ...[
                          const SizedBox(width: 4),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildMobileDayView() {
    final currentDayIndex = widget.selectedDate.weekday - 1;
    final dayLessons = lessons.where((lesson) => lesson['dayOffset'] == currentDayIndex).toList();
    
    if (dayLessons.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_busy,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Немає занять на цей день',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: dayLessons.length,
      itemBuilder: (context, index) {
        final lesson = dayLessons[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: _buildMobileLessonCard(lesson),
        );
      },
    );
  }

  Widget _buildDesktopWeekView(bool isTablet) {
    return SingleChildScrollView(
      child: Container(
        height: (maxHour - minHour) * hourHeight,
        child: Row(
          children: [
            // Часова колонка
            SizedBox(
              width: timeColumnWidth,
              child: _buildTimeColumn(),
            ),
            // Колонки днів
            Expanded(
              child: Row(
                children: List.generate(7, (dayIndex) {
                  return Expanded(
                    child: _buildDayColumn(dayIndex, isTablet),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeColumn() {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Column(
        children: List.generate((maxHour - minHour).toInt(), (index) {
          final hour = (minHour + index).toInt();
          return Container(
            height: hourHeight,
            alignment: Alignment.topRight,
            padding: const EdgeInsets.only(right: 8, top: 4),
            child: Text(
              '${hour.toString().padLeft(2, '0')}:00',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildDayColumn(int dayIndex, bool isTablet) {
    final dayLessons = lessons.where((lesson) => lesson['dayOffset'] == dayIndex).toList();
    
    return Container(
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Stack(
        children: [
          // Сітка годин
          ...List.generate((maxHour - minHour).toInt(), (index) {
            return Positioned(
              top: index * hourHeight,
              left: 0,
              right: 0,
              height: hourHeight,
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
              ),
            );
          }),
          // Заняття
          ...dayLessons.map((lesson) => _buildPositionedLesson(lesson, dayIndex, isTablet)),
        ],
      ),
    );
  }

  Widget _buildPositionedLesson(Map<String, dynamic> lesson, int dayIndex, bool isTablet) {
    final start = lesson['start'] as TimeOfDay;
    final end = lesson['end'] as TimeOfDay;
    
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;
    final durationMinutes = endMinutes - startMinutes;
    
    final topPosition = (start.hour - minHour) * hourHeight + (start.minute * minuteHeight);
    final height = durationMinutes * minuteHeight;
    
    // Перевірка на перекриття з іншими заняттями в цей час
    final overlappingLessons = lessons.where((other) => 
      other['dayOffset'] == dayIndex && 
      other['id'] != lesson['id'] &&
      _timesOverlap(other['start'], other['end'], start, end)
    ).toList();
    
    final overlapCount = overlappingLessons.length + 1;
    final lessonIndex = overlappingLessons.indexOf(lesson) + 1;
    
    return Positioned(
      top: topPosition,
      left: 4 + (lessonIndex - 1) * (1.0 / overlapCount) * (100 - 8),
      right: 4 + (overlapCount - lessonIndex) * (1.0 / overlapCount) * (100 - 8),
      height: height.clamp(40.0, double.infinity),
      child: _buildDesktopLessonCard(lesson, isTablet),
    );
  }

  Widget _buildDesktopLessonCard(Map<String, dynamic> lesson, bool isTablet) {
    return GestureDetector(
      onTap: () => widget.onLessonTap?.call(lesson),
      child: Container(
        margin: const EdgeInsets.all(2),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: lesson['color'] as Color,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: (lesson['color'] as Color).withOpacity(0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lesson['title'],
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              lesson['group'],
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (!isTablet) ...[
              const SizedBox(height: 2),
              Text(
                '${lesson['filled']}/${lesson['total']}',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMobileLessonCard(Map<String, dynamic> lesson) {
    final start = lesson['start'] as TimeOfDay;
    final end = lesson['end'] as TimeOfDay;
    
    return GestureDetector(
      onTap: () => widget.onLessonTap?.call(lesson),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: lesson['color'] as Color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: (lesson['color'] as Color).withOpacity(0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    lesson['title'],
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '${_formatTime(start)} - ${_formatTime(end)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.group,
                  size: 16,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  lesson['group'],
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  size: 16,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  lesson['location'],
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${lesson['filled']}/${lesson['total']} учасників',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Доступно',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.green.shade800,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<DateTime> _getWeekDays() {
    final startOfWeek = widget.selectedDate.subtract(Duration(days: widget.selectedDate.weekday - 1));
    return List.generate(7, (index) => startOfWeek.add(Duration(days: index)));
  }

  String _getDayName(int weekday) {
    const days = ['ПН', 'ВТ', 'СР', 'ЧТ', 'ПТ', 'СБ', 'НД'];
    return days[weekday - 1];
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  bool _hasLessonsOnDay(int dayIndex) {
    return lessons.any((lesson) => lesson['dayOffset'] == dayIndex);
  }

  bool _timesOverlap(TimeOfDay start1, TimeOfDay end1, TimeOfDay start2, TimeOfDay end2) {
    final start1Minutes = start1.hour * 60 + start1.minute;
    final end1Minutes = end1.hour * 60 + end1.minute;
    final start2Minutes = start2.hour * 60 + start2.minute;
    final end2Minutes = end2.hour * 60 + end2.minute;
    
    return start1Minutes < end2Minutes && start2Minutes < end1Minutes;
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}