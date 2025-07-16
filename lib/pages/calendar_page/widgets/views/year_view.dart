// lib/pages/calendar_page/widgets/views/year_view.dart

import 'package:flutter/material.dart';
import '../../models/lesson_model.dart';
import '../../calendar_utils.dart';

class YearView extends StatelessWidget {
  final DateTime selectedDate;
  final List<LessonModel> lessons;
  final Function(DateTime)? onDateSelected;
  final Future<void> Function() onRefresh;
  final bool isMobile;

  const YearView({
    super.key,
    required this.selectedDate,
    required this.lessons,
    this.onDateSelected,
    required this.onRefresh,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    final year = selectedDate.year;
    
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Заголовок року
            _buildYearHeader(context, year),
            const SizedBox(height: 20),
            
            // Сітка місяців
            _buildMonthsGrid(context, year),
            
            const SizedBox(height: 20),
            
            // Річна статистика
            _buildYearStats(context, year),
          ],
        ),
      ),
    );
  }

  Widget _buildYearHeader(BuildContext context, int year) {
    final yearLessons = _getLessonsForYear(year);
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Text(
            year.toString(),
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _getYearSummary(yearLessons),
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthsGrid(BuildContext context, int year) {
    // Обмежуємо максимальний розмір клітинки
    const maxCellWidth = 200.0;
    const maxCellHeight = 150.0;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        // Визначаємо кількість колонок залежно від ширини
        final screenWidth = constraints.maxWidth;
        int crossAxisCount;
        
        if (screenWidth < 400) {
          crossAxisCount = 1; // Дуже вузькі екрани - 1 колонка
        } else if (screenWidth < 600) {
          crossAxisCount = 2; // Мобільні - 2 колонки
        } else {
          crossAxisCount = 3; // Планшет/десктоп - 3 колонки
        }
        
        // Розраховуємо висоту сітки динамічно
        final rows = (12 / crossAxisCount).ceil();
        final gridHeight = rows * maxCellHeight + (rows - 1) * 16; // +16 для mainAxisSpacing
        
        return Container(
          height: gridHeight, // Динамічна висота замість maxHeight
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: maxCellWidth / maxCellHeight,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              mainAxisExtent: maxCellHeight,
            ),
            itemCount: 12,
            itemBuilder: (context, index) {
              final month = index + 1;
              final monthDate = DateTime(year, month, 1);
              return _buildMonthCard(context, monthDate, month);
            },
          ),
        );
      },
    );
  }

  Widget _buildMonthCard(BuildContext context, DateTime monthDate, int month) {
    final monthLessons = _getLessonsForMonth(monthDate.year, month);
    final isCurrentMonth = monthDate.year == DateTime.now().year &&
                          monthDate.month == DateTime.now().month;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        // Адаптуємо розмір шрифту для вузьких карток
        final isNarrow = constraints.maxWidth < 150;
        
        return GestureDetector(
          onTap: () => onDateSelected?.call(monthDate),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isCurrentMonth 
                  ? Theme.of(context).primaryColor 
                  : Colors.grey.shade300,
                width: isCurrentMonth ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(isNarrow ? 8 : 12), // Менший padding для вузьких карток
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Назва місяця
                  Text(
                    CalendarUtils.getMonthName(month, short: isNarrow), // Короткі назви для вузьких карток
                    style: TextStyle(
                      fontSize: isNarrow ? 14 : 16,
                      fontWeight: FontWeight.bold,
                      color: isCurrentMonth 
                        ? Theme.of(context).primaryColor 
                        : Colors.black,
                    ),
                  ),
                  SizedBox(height: isNarrow ? 4 : 8),
                  
                  // Кількість занять
                  if (monthLessons.isNotEmpty) ...[
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isNarrow ? 8 : 12, 
                        vertical: isNarrow ? 4 : 6,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '${monthLessons.length} занять',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isNarrow ? 10 : 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    SizedBox(height: isNarrow ? 4 : 8),
                    
                    // Топ категорії (показуємо тільки для широких карток)
                    if (!isNarrow) _buildMonthTopCategories(monthLessons),
                  ] else ...[
                    Text(
                      'Немає занять',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: isNarrow ? 10 : 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMonthTopCategories(List<LessonModel> monthLessons) {
    final tagCounts = <String, int>{};
    for (final lesson in monthLessons) {
      for (final tag in lesson.tags) {
        tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
      }
    }
    
    final topTags = tagCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    if (topTags.isEmpty) return const SizedBox.shrink();
    
    return Column(
      children: topTags.take(2).map((entry) => 
        Container(
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${entry.key} (${entry.value})',
            style: TextStyle(
              fontSize: 9,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ).toList(),
    );
  }

  Widget _buildYearStats(BuildContext context, int year) {
    final yearLessons = _getLessonsForYear(year);
    final totalLessons = yearLessons.length;
    
    // Статистика по місяцях
    final monthlyStats = <int, int>{};
    for (int month = 1; month <= 12; month++) {
      monthlyStats[month] = _getLessonsForMonth(year, month).length;
    }
    
    // Топ категорії
    final tagCounts = <String, int>{};
    for (final lesson in yearLessons) {
      for (final tag in lesson.tags) {
        tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
      }
    }
    
    final topTags = tagCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    final mostActiveMonth = monthlyStats.entries
        .reduce((a, b) => a.value > b.value ? a : b);
    
    final activeMonths = monthlyStats.values.where((count) => count > 0).length;

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
          Text(
            'Статистика $year року',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // Основні показники
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
                  'Активних місяців',
                  activeMonths.toString(),
                  Icons.calendar_month,
                  Colors.green,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          if (totalLessons > 0) ...[
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Найактивніший місяць',
                    CalendarUtils.getMonthName(mostActiveMonth.key, short: true),
                    Icons.trending_up,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Середньо за місяць',
                    (totalLessons / 12).toStringAsFixed(1),
                    Icons.analytics,
                    Colors.purple,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Топ категорії
            if (topTags.isNotEmpty) ...[
              const Text(
                'Найпопулярніші категорії:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: topTags.take(6).map((entry) => 
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
            size: 20,
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // Допоміжні методи
  List<LessonModel> _getLessonsForYear(int year) {
    return lessons.where((lesson) => lesson.startTime.year == year).toList();
  }

  List<LessonModel> _getLessonsForMonth(int year, int month) {
    return lessons.where((lesson) => 
      lesson.startTime.year == year && lesson.startTime.month == month
    ).toList();
  }

  String _getYearSummary(List<LessonModel> yearLessons) {
    if (yearLessons.isEmpty) {
      return 'Немає запланованих занять';
    }
    
    final uniqueMonths = yearLessons
        .map((lesson) => lesson.startTime.month)
        .toSet()
        .length;
    
    return '${yearLessons.length} занять в $uniqueMonths місяцях';
  }
}