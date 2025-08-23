// lib/pages/calendar_page/widgets/views/mobile_day_view.dart

import 'package:flutter/material.dart';
import '../../../../models/lesson_model.dart';
import '../../calendar_utils.dart';
import '../mobile_lesson_card.dart';
import '../../../../theme/theme_utils.dart';

class MobileDayView extends StatelessWidget {
  final DateTime selectedDate;
  final List<LessonModel> lessons;
  final Function(LessonModel)? onLessonTap;
  final Function(DateTime)? onDateSelected;
  final Future<void> Function() onRefresh;
  final List<LessonModel> Function(DateTime) getLessonsForSpecificDate;

  const MobileDayView({
    super.key,
    required this.selectedDate,
    required this.lessons,
    this.onLessonTap,
    this.onDateSelected,
    required this.onRefresh,
    required this.getLessonsForSpecificDate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildDateNavigation(context),
        const Divider(height: 1),
        Expanded(
          child: _buildDayContent(context),
        ),
      ],
    );
  }

  Widget _buildDateNavigation(BuildContext context) {
    final weekDays = CalendarUtils.getWeekDays(selectedDate);
    
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: weekDays.length,
        itemBuilder: (context, index) {
          final day = weekDays[index];
          final isSelected = day.year == selectedDate.year &&
                            day.month == selectedDate.month &&
                            day.day == selectedDate.day;
          final isToday = CalendarUtils.isToday(day);
          final hasLessons = getLessonsForSpecificDate(day).isNotEmpty;
          
          return GestureDetector(
            onTap: () => onDateSelected?.call(day),
            child: Container(
              width: 60,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: isSelected ? Theme.of(context).primaryColor : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isToday && !isSelected
                    ? Theme.of(context).primaryColor
                    : isSelected 
                      ? Theme.of(context).primaryColor 
                      : Colors.grey.shade300,
                  width: isToday && !isSelected ? 2 : 1,
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
                      color: isSelected 
                        ? Theme.of(context).colorScheme.onSurface 
                        : Colors.white, // 👈 Завжди білий текст для неактивних днів
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    day.day.toString(),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isSelected 
                        ? Theme.of(context).colorScheme.onSurface 
                        : Colors.white, // 👈 Завжди білий текст для неактивних днів
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Крапка для всіх днів з заняттями (завжди показується якщо є заняття)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: hasLessons 
                        ? (isSelected 
                          ? Theme.of(context).colorScheme.onSurface 
                          : Colors.orange) // 👈 Помаранчева крапка для неактивних днів з заняттями
                        : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDayContent(BuildContext context) {
    final dayLessons = getLessonsForSpecificDate(selectedDate);
    
    if (dayLessons.isEmpty) {
      return _buildEmptyState(context);
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: dayLessons.length,
        itemBuilder: (context, index) {
          final lesson = dayLessons[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            child: MobileLessonCard(
              lesson: lesson,
              onTap: () => onLessonTap?.call(lesson),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
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
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Оновити'),
          ),
        ],
      ),
    );
  }
}

