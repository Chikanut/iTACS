// lib/pages/calendar_page/widgets/views/desktop_week_view.dart

import 'package:flutter/material.dart';
import '../../models/lesson_model.dart';
import '../../calendar_utils.dart';
import '../../../../services/calendar_service.dart';

class DesktopWeekView extends StatelessWidget {
  final DateTime selectedDate;
  final List<LessonModel> lessons;
  final Function(LessonModel)? onLessonTap;
  final Future<void> Function() onRefresh;
  final double minHour;
  final double maxHour;
  final bool isTablet;
  final List<LessonModel> Function(int) getLessonsForDay;
  final bool Function(int) hasLessonsOnDay;
  final bool showSingleDay;

  static const double timeColumnWidth = 60.0;
  static const double hourHeight = 80.0;
  static const double minuteHeight = hourHeight / 60.0;

  const DesktopWeekView({
    super.key,
    required this.selectedDate,
    required this.lessons,
    this.onLessonTap,
    required this.onRefresh,
    required this.minHour,
    required this.maxHour,
    required this.isTablet,
    required this.getLessonsForDay,
    required this.hasLessonsOnDay,
    this.showSingleDay = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildDateHeader(context),
        const Divider(height: 1),
        Expanded(
          child: _buildTimeView(context),
        ),
      ],
    );
  }

  Widget _buildDateHeader(BuildContext context) {
    final days = CalendarUtils.getWeekDays(selectedDate);
    final displayDays = showSingleDay ? [selectedDate] : days;
    
    return Container(
      height: 60,
      child: Row(
        children: [
          SizedBox(
            width: timeColumnWidth,
            child: Container(),
          ),
          ...displayDays.asMap().entries.map((entry) {
            final index = showSingleDay ? selectedDate.weekday - 1 : entry.key;
            final day = entry.value;
            final isToday = CalendarUtils.isToday(day);
            final hasLessons = hasLessonsOnDay(index);
            
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

  Widget _buildTimeView(BuildContext context) {
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
                children: showSingleDay 
                  ? [Expanded(child: _buildDayColumn(selectedDate.weekday - 1))]
                  : [
                      Expanded(child: _buildDayColumn(0)), // Понеділок
                      Expanded(child: _buildDayColumn(1)), // Вівторок
                      Expanded(child: _buildDayColumn(2)), // Середа
                      Expanded(child: _buildDayColumn(3)), // Четвер
                      Expanded(child: _buildDayColumn(4)), // П'ятниця
                      Expanded(child: _buildDayColumn(5)), // Субота
                      Expanded(child: _buildDayColumn(6)), // Неділя
                    ],
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

  Widget _buildDayColumn(int dayIndex) {
    final dayLessons = getLessonsForDay(dayIndex);
    
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
          ...dayLessons.map((lesson) => _buildPositionedLesson(lesson, dayIndex)),
        ],
      ),
    );
  }

  Widget _buildPositionedLesson(LessonModel lesson, int dayIndex) {
    final start = TimeOfDay.fromDateTime(lesson.startTime);
    final end = TimeOfDay.fromDateTime(lesson.endTime);
    
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;
    final durationMinutes = endMinutes - startMinutes;
    
    final topPosition = (start.hour - minHour) * hourHeight + (start.minute * minuteHeight);
    final height = (durationMinutes * minuteHeight).clamp(50.0, double.infinity);
    
    // Знаходимо ВСІ заняття цього дня
    final allDayLessons = getLessonsForDay(dayIndex);
    
    // Знаходимо заняття що перекриваються з поточним
    final overlappingLessons = allDayLessons.where((other) => 
      CalendarUtils.timesOverlap(
        TimeOfDay.fromDateTime(other.startTime),
        TimeOfDay.fromDateTime(other.endTime),
        start, end
      )
    ).toList();
    
    // Сортуємо перекриваючі заняття за часом початку, потім за часом закінчення
    overlappingLessons.sort((a, b) {
      final aStart = a.startTime.millisecondsSinceEpoch;
      final bStart = b.startTime.millisecondsSinceEpoch;
      if (aStart != bStart) {
        return aStart.compareTo(bStart);
      }
      return a.endTime.millisecondsSinceEpoch.compareTo(b.endTime.millisecondsSinceEpoch);
    });
    
    final totalOverlapping = overlappingLessons.length;
    final lessonIndex = overlappingLessons.indexOf(lesson);
    
    if (totalOverlapping <= 1) {
      // Немає перекриттів - займає майже всю ширину клітинки
      return Positioned(
        top: topPosition,
        left: 0,
        right: 0,
        height: height,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2.0),
          child: _buildDesktopLessonCard(lesson),
        ),
      );
    } else {
      // Є перекриття - ділимо ширину клітинки
      return Positioned(
        top: topPosition,
        left: 0,
        right: 0,
        height: height,
        child: SizedBox(
          height: height,
          child: Row(
            children: List.generate(totalOverlapping, (index) {
              if (index == lessonIndex) {
                // Це наше заняття
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: index == 0 ? 2.0 : 1.0,
                      right: index == totalOverlapping - 1 ? 2.0 : 1.0,
                    ),
                    child: SizedBox(
                      height: height,
                      child: _buildDesktopLessonCard(lesson),
                    ),
                  ),
                );
              } else {
                // Це місце для іншого заняття (пусте)
                return const Expanded(child: SizedBox.shrink());
              }
            }),
          ),
        ),
      );
    }
  }

Widget _buildDesktopLessonCard(LessonModel lesson) {
  final calendarService = CalendarService();
  final isRegistered = calendarService.isUserInstructorForLesson(lesson);
  final needsInstructor = calendarService.doesLessonNeedInstructor(lesson);
  final color = CalendarUtils.getGroupColor(lesson.groupName);

  final readinessStatus = LessonStatusUtils.getReadinessStatus(lesson); // ⬅️ нове

  return GestureDetector(
    onTap: () => onLessonTap?.call(lesson),
    child: Container(
      margin: const EdgeInsets.all(1),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: readinessStatus.color, // ⬅️ колір рамки зі статусу
          width: 2, // ⬅️ завжди показуємо широку рамку для видимості статусу
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
        mainAxisSize: MainAxisSize.min,
        children: [
          // Заголовок з іконкою
          Row(
            children: [
              Icon(
                CalendarUtils.getLessonTypeIcon(
                  lesson.tags.isNotEmpty ? lesson.tags.first : ''
                ),
                size: 10,
                color: Colors.grey.shade700,
              ),
              const SizedBox(width: 2),
              Expanded(
                child: Text(
                  lesson.title,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                readinessStatus.icon, // ⬅️ статусна іконка
                size: 8,
                color: readinessStatus.color,
              ),
            ],
          ),

          const SizedBox(height: 2),

          // Інструктор або "Потрібен викладач"
          Text(
            needsInstructor ? 'Потрібен викладач' : lesson.instructorName,
            style: TextStyle(
              fontSize: 8,
              color: needsInstructor ? Colors.orange.shade700 : Colors.grey.shade700,
              fontWeight: needsInstructor ? FontWeight.w600 : FontWeight.normal,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          // Підрозділ та кількість (тільки якщо є місце)
          if (!isTablet) ...[
            const SizedBox(height: 1),
            Text(
              lesson.unit.isNotEmpty
                  ? '${lesson.unit} • ${lesson.maxParticipants}'
                  : '${lesson.maxParticipants} учнів',
              style: TextStyle(
                fontSize: 7,
                color: Colors.grey.shade600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    ),
  );
}
}