import 'package:flutter/material.dart';
import '../models/calendar_view_type.dart';
import '../models/lesson_model.dart';

import 'package:flutter/material.dart';
import '../models/calendar_view_type.dart';
import '../models/lesson_model.dart';
import '../../../services/calendar_service.dart';
import '../calendar_utils.dart';
import 'lesson_card.dart';

class CalendarGrid extends StatefulWidget {
  final CalendarViewType viewType;
  final DateTime selectedDate;
  final List<String>? filteredGroups;
  final Function(LessonModel)? onLessonTap;

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
  double _minHour = 8.0;
  double _maxHour = 20.0;
  static const double hourHeight = 80.0;
  static const double minuteHeight = hourHeight / 60.0;

  final CalendarService _calendarService = CalendarService();
  List<LessonModel> _lessons = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadLessons();
  }

  @override
  void didUpdateWidget(CalendarGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDate != widget.selectedDate ||
        oldWidget.viewType != widget.viewType) {
      _loadLessons();
    }
  }

  Future<void> _loadLessons() async {
    setState(() => _isLoading = true);
    
    try {
      List<LessonModel> lessons;
      
      switch (widget.viewType) {
        case CalendarViewType.day:
          lessons = await _calendarService.getLessonsForDay(widget.selectedDate);
          break;
        case CalendarViewType.week:
          lessons = await _calendarService.getLessonsForWeek(widget.selectedDate);
          break;
        case CalendarViewType.month:
          final startOfMonth = CalendarUtils.getStartOfMonth(widget.selectedDate);
          final endOfMonth = CalendarUtils.getEndOfMonth(widget.selectedDate);
          lessons = await _calendarService.getLessonsForPeriod(
            startDate: startOfMonth,
            endDate: endOfMonth,
          );
          break;
        case CalendarViewType.year:
          final startOfYear = DateTime(widget.selectedDate.year, 1, 1);
          final endOfYear = DateTime(widget.selectedDate.year, 12, 31);
          lessons = await _calendarService.getLessonsForPeriod(
            startDate: startOfYear,
            endDate: endOfYear,
          );
          break;
      }

      if (mounted) {
        setState(() {
          _lessons = lessons;
          
          // Динамічно обчислюємо межі часу
          if (lessons.isNotEmpty) {
            _minHour = CalendarUtils.getMinHourFromLessons(lessons);
            _maxHour = CalendarUtils.getMaxHourFromLessons(lessons);
          } else {
            _minHour = 8.0;  // fallback
            _maxHour = 20.0;
          }
          
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('CalendarGrid: Помилка завантаження занять: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

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
    final days = CalendarUtils.getWeekDays(widget.selectedDate);
    
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
          final isToday = CalendarUtils.isToday(day);
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
                  CalendarUtils.getDayName(day.weekday),
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
    final days = CalendarUtils.getWeekDays(widget.selectedDate);
    
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
            final isToday = CalendarUtils.isToday(day);
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
                      CalendarUtils.getDayName(day.weekday),
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
    final dayLessons = _getLessonsForDay(widget.selectedDate.weekday - 1);
    
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
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => _loadLessons(),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Оновити'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadLessons,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: dayLessons.length,
        itemBuilder: (context, index) {
          final lesson = dayLessons[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            child: _buildMobileLessonCard(lesson),
          );
        },
      ),
    );
  }

  Widget _buildDesktopWeekView(bool isTablet) {
    return SingleChildScrollView(
      child: Container(
        height: (_maxHour - _minHour) * hourHeight,
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
        children: List.generate((_maxHour - _minHour).toInt(), (index) {
          final hour = (_minHour + index).toInt();
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
    final dayLessons = _getLessonsForDay(dayIndex);
    
    return Container(
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Stack(
        children: [
          // Сітка годин
          ...List.generate((_maxHour - _minHour).toInt(), (index) {
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

  Widget _buildPositionedLesson(LessonModel lesson, int dayIndex, bool isTablet) {
    final start = TimeOfDay.fromDateTime(lesson.startTime);
    final end = TimeOfDay.fromDateTime(lesson.endTime);
    
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;
    final durationMinutes = endMinutes - startMinutes;
    
    final topPosition = (start.hour - _minHour) * hourHeight + (start.minute * minuteHeight);
    final height = durationMinutes * minuteHeight;
    
    final dayLessons = _getLessonsForDay(widget.selectedDate.weekday - 1);

    // Перевірка на перекриття з іншими заняттями в цей час
    final overlappingLessons = dayLessons.where((other) => 
      other.id != lesson.id &&
      CalendarUtils.timesOverlap(
        TimeOfDay.fromDateTime(other.startTime),
        TimeOfDay.fromDateTime(other.endTime),
        start, end
      )
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

  Widget _buildDesktopLessonCard(LessonModel lesson, bool isTablet) {
    final isRegistered = _calendarService.isUserRegisteredForLesson(lesson);
    final color = CalendarUtils.getGroupColor(lesson.groupName);
    final status = CalendarUtils.getLessonStatus(
      lesson.currentParticipants, 
      lesson.maxParticipants, 
      isRegistered
    );

    return GestureDetector(
      onTap: () => widget.onLessonTap?.call(lesson),
      child: Container(
        margin: const EdgeInsets.all(2),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: color.withOpacity(0.3),
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
            Row(
              children: [
                Icon(
                  CalendarUtils.getLessonTypeIcon(lesson.tags.isNotEmpty ? lesson.tags.first : ''),
                  size: 12,
                  color: Colors.grey.shade700,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    lesson.title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  status.icon,
                  size: 10,
                  color: status.color,
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              lesson.groupName,
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
                '${lesson.currentParticipants}/${lesson.maxParticipants}',
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

  Widget _buildMobileLessonCard(LessonModel lesson) {
    final start = TimeOfDay.fromDateTime(lesson.startTime);
    final end = TimeOfDay.fromDateTime(lesson.endTime);
    final isRegistered = _calendarService.isUserRegisteredForLesson(lesson);
    final color = CalendarUtils.getGroupColor(lesson.groupName);
    final status = CalendarUtils.getLessonStatus(
      lesson.currentParticipants, 
      lesson.maxParticipants, 
      isRegistered
    );
    
    return GestureDetector(
      onTap: () => widget.onLessonTap?.call(lesson),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.3),
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
                  child: Row(
                    children: [
                      Icon(
                        CalendarUtils.getLessonTypeIcon(lesson.tags.isNotEmpty ? lesson.tags.first : ''),
                        size: 20,
                        color: Colors.grey.shade700,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          lesson.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Icon(
                      status.icon,
                      size: 16,
                      color: status.color,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${CalendarUtils.formatTime(start)} - ${CalendarUtils.formatTime(end)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
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
                  lesson.groupName,
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
                  Icons.person,
                  size: 16,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  lesson.instructor,
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
                  lesson.location,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      '${lesson.currentParticipants}/${lesson.maxParticipants} учасників',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: status.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status.label,
                        style: TextStyle(
                          fontSize: 10,
                          color: status.color.withOpacity(0.8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                if (!isRegistered && !CalendarUtils.isFull(lesson.currentParticipants, lesson.maxParticipants))
                  ElevatedButton(
                    onPressed: () => _registerForLesson(lesson),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: Size.zero,
                    ),
                    child: const Text(
                      'Записатися',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
            if (lesson.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: lesson.tags.take(3).map((tag) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<LessonModel> _getLessonsForDay(int dayIndex) {
    final weekDays = CalendarUtils.getWeekDays(widget.selectedDate);
    final targetDate = weekDays[dayIndex];
    
    return _lessons.where((lesson) {
      final lessonDate = lesson.startTime;
      return lessonDate.year == targetDate.year &&
             lessonDate.month == targetDate.month &&
             lessonDate.day == targetDate.day;
    }).toList();
  }

  bool _hasLessonsOnDay(int dayIndex) {
    return _getLessonsForDay(dayIndex).isNotEmpty;
  }

  Future<void> _registerForLesson(LessonModel lesson) async {
    try {
      final success = await _calendarService.registerForLesson(lesson.id);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Успішно зареєстровано на заняття "${lesson.title}"'),
            backgroundColor: Colors.green,
          ),
        );
        _loadLessons(); // Оновлюємо дані
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Помилка реєстрації: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}