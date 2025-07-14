// lib/pages/calendar_page/widgets/views/mobile_week_view.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/lesson_model.dart';
import '../../calendar_utils.dart';
import '../mobile_lesson_card.dart';

class MobileWeekView extends StatelessWidget {
  final DateTime selectedDate;
  final List<LessonModel> lessons;
  final Function(LessonModel)? onLessonTap;
  final Future<void> Function() onRefresh;
  final List<LessonModel> Function(DateTime) getLessonsForSpecificDate;

  const MobileWeekView({
    super.key,
    required this.selectedDate,
    required this.lessons,
    this.onLessonTap,
    required this.onRefresh,
    required this.getLessonsForSpecificDate,
  });

  @override
  Widget build(BuildContext context) {
    final weekDays = CalendarUtils.getWeekDays(selectedDate);
    final daysWithLessons = <DateTime, List<LessonModel>>{};
    
    // Групуємо заняття по датах
    for (final day in weekDays) {
      final dayLessons = getLessonsForSpecificDate(day);
      if (dayLessons.isNotEmpty) {
        daysWithLessons[day] = dayLessons;
      }
    }

    if (daysWithLessons.isEmpty) {
      return _buildEmptyState(context);
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: daysWithLessons.length,
        itemBuilder: (context, index) {
          final date = daysWithLessons.keys.elementAt(index);
          final lessonsForDay = daysWithLessons[date]!;
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Заголовок дати
              _buildDateHeader(context, date),
              
              // Заняття для цього дня
              ...lessonsForDay.map((lesson) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: MobileLessonCard(
                  lesson: lesson,
                  onTap: () => onLessonTap?.call(lesson),
                ),
              )),
              
              // Розділювач між днями
              if (index < daysWithLessons.length - 1)
                const Divider(height: 32),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDateHeader(BuildContext context, DateTime date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Text(
            DateFormat('EEEE, dd MMMM', 'uk').format(date),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (CalendarUtils.isToday(date)) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Сьогодні',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
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
            'Немає занять на цьому тижні',
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

