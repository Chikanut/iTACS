// lib/pages/calendar_page/widgets/views/month_view.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import '../../models/lesson_model.dart';
import '../../calendar_utils.dart';

class MonthView extends StatelessWidget {
  final DateTime selectedDate;
  final List<LessonModel> lessons;
  final Function(DateTime)? onDateSelected;
  final Future<void> Function() onRefresh;
  final List<LessonModel> Function(DateTime) getLessonsForSpecificDate;
  final bool isMobile;

  const MonthView({
    super.key,
    required this.selectedDate,
    required this.lessons,
    this.onDateSelected,
    required this.onRefresh,
    required this.getLessonsForSpecificDate,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    final monthStart = CalendarUtils.getStartOfMonth(selectedDate);
    final monthEnd = CalendarUtils.getEndOfMonth(selectedDate);
    
    // Отримуємо всі дні місяця
    final daysInMonth = <DateTime>[];
    for (int i = 0; i < monthEnd.day; i++) {
      daysInMonth.add(monthStart.add(Duration(days: i)));
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Заголовок місяця
            _buildMonthHeader(context),
            const SizedBox(height: 20),
            
            // Календарна сітка
            _buildCalendarGrid(context, daysInMonth),
            
            const SizedBox(height: 20),
            
            // Статистика місяця
            _buildMonthStats(context, daysInMonth),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Text(
            DateFormat('MMMM yyyy', 'uk').format(selectedDate),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _getMonthSummary(),
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid(BuildContext context, List<DateTime> daysInMonth) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Розраховуємо оптимальну висоту клітинки
        final screenWidth = constraints.maxWidth;
        final screenHeight = MediaQuery.of(context).size.height;
        
        // Ширина клітинки = (доступна ширина - borders) / 7 колонок
        final cellWidth = (screenWidth - 6) / 7; // -6 для 6 borders між колонками
        
        // Висота клітинки залежить від ширини та розміру екрана
        double cellHeight;
        if (screenHeight < 600) {
          // Дуже маленькі екрани - мінімальна висота
          cellHeight = math.max(60, cellWidth * 0.8);
        } else if (screenHeight < 800) {
          // Середні екрани
          cellHeight = math.max(70, cellWidth * 0.9);
        } else {
          // Великі екрани
          cellHeight = math.max(80, cellWidth);
        }
        
        // Розраховуємо кількість рядків
        final weekRows = (daysInMonth.length / 7).ceil();
        final totalRows = weekRows + 1; // +1 для заголовків
        final totalHeight = totalRows * cellHeight;
        
        return Container(
          height: totalHeight,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: cellWidth / cellHeight,
              crossAxisSpacing: 0,
              mainAxisSpacing: 0,
              mainAxisExtent: cellHeight,
            ),
            itemCount: 7 + daysInMonth.length,
            itemBuilder: (context, index) {
              if (index < 7) {
                return _buildDayHeader(index);
              }
              
              final dayIndex = index - 7;
              final day = daysInMonth[dayIndex];
              return _buildDayCell(context, day, cellHeight);
            },
          ),
        );
      },
    );
  }

  Widget _buildDayHeader(int index) {
    final dayNames = ['ПН', 'ВТ', 'СР', 'ЧТ', 'ПТ', 'СБ', 'НД'];
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxHeight < 70;
        
        return Container(
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(vertical: isSmall ? 4 : 8),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade300),
              right: index < 6 ? BorderSide(color: Colors.grey.shade300) : BorderSide.none,
            ),
          ),
          child: Text(
            dayNames[index],
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
              fontSize: isSmall ? 10 : 12,
            ),
          ),
        );
      },
    );
  }

  Widget _buildDayCell(BuildContext context, DateTime day, double cellHeight) {
    final lessonsForDay = getLessonsForSpecificDate(day);
    final isToday = CalendarUtils.isToday(day);
    final isSelected = day.year == selectedDate.year &&
                      day.month == selectedDate.month &&
                      day.day == selectedDate.day;
    
    // Адаптивні розміри залежно від висоти клітинки
    final isSmallCell = cellHeight < 70;
    final isTinyCell = cellHeight < 60;
    
    return GestureDetector(
      onTap: () => onDateSelected?.call(day),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: isSelected 
              ? Colors.green
              : isToday 
                ? Theme.of(context).primaryColor 
                : Colors.grey.shade300,
            width: (isToday || isSelected) ? 2 : 1,
          ),
          borderRadius: (isToday || isSelected) ? BorderRadius.circular(4) : null,
        ),
        child: Padding(
          padding: EdgeInsets.all(isSmallCell ? 2 : 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Номер дня
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    day.day.toString(),
                    style: TextStyle(
                      fontSize: isTinyCell ? 10 : isSmallCell ? 11 : 12,
                      fontWeight: (isToday || isSelected) ? FontWeight.bold : FontWeight.normal,
                      color: isSelected
                        ? Colors.green
                        : isToday 
                          ? Theme.of(context).primaryColor 
                          : Colors.black,
                    ),
                  ),
                  if (lessonsForDay.isNotEmpty)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallCell ? 3 : 4, 
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        lessonsForDay.length.toString(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isTinyCell ? 6 : 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              
              // Плашки занять
              if (lessonsForDay.isNotEmpty && !isTinyCell) ...[
                SizedBox(height: isSmallCell ? 1 : 2),
                Expanded(
                  child: Column(
                    children: [
                      // Показуємо менше занять для маленьких клітинок
                      ...lessonsForDay.take(isSmallCell ? 2 : 3).map((lesson) {
                        final readinessStatus = LessonStatusUtils.getReadinessStatus(lesson);
                        return Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 1),
                          padding: EdgeInsets.symmetric(
                            horizontal: isSmallCell ? 1 : 2, 
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: readinessStatus.color.withAlpha(100),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: Text(
                            lesson.title,
                            style: TextStyle(
                              fontSize: isSmallCell ? 6 : 7,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }),
                      if (lessonsForDay.length > (isSmallCell ? 2 : 3))
                        Text(
                          '+${lessonsForDay.length - (isSmallCell ? 2 : 3)} ще',
                          style: TextStyle(
                            fontSize: isSmallCell ? 5 : 6,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
              ] else if (lessonsForDay.isNotEmpty && isTinyCell) ...[
                // Для дуже маленьких клітинок показуємо тільки крапку
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMonthStats(BuildContext context, List<DateTime> daysInMonth) {
    final totalLessons = lessons.length;
    final daysWithLessons = daysInMonth.where((day) => 
      getLessonsForSpecificDate(day).isNotEmpty
    ).length;
    
    // Групуємо заняття по тегах
    final tagCounts = <String, int>{};
    for (final lesson in lessons) {
      for (final tag in lesson.tags) {
        tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
      }
    }
    
    final topTags = tagCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Статистика місяця',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  context,
                  'Всього занять',
                  totalLessons.toString(),
                  Icons.event,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  context,
                  'Активних днів',
                  daysWithLessons.toString(),
                  Icons.calendar_today,
                  Colors.green,
                ),
              ),
            ],
          ),
          
          if (topTags.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Популярні категорії:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: topTags.take(5).map((entry) => 
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context).primaryColor.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    '${entry.key} (${entry.value})',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ),
              ).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
                      Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _getMonthSummary() {
    final totalLessons = lessons.length;
    if (totalLessons == 0) {
      return 'Немає запланованих занять';
    }
    
    final uniqueDays = lessons
        .map((lesson) => DateTime(
              lesson.startTime.year,
              lesson.startTime.month,
              lesson.startTime.day,
            ))
        .toSet()
        .length;
    
    return '$totalLessons занять на $uniqueDays днів';
  }

  
}