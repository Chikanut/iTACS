// lib/pages/calendar_page/widgets/calendar_header.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import '../models/calendar_view_type.dart';
import '../calendar_utils.dart';

class CalendarHeader extends StatelessWidget {
  final CalendarViewType viewType;
  final DateTime selectedDate;
  final void Function(CalendarViewType) onViewTypeChange;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;

  const CalendarHeader({
    super.key,
    required this.viewType,
    required this.selectedDate,
    required this.onViewTypeChange,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
  });

  String _getFormattedPeriod() {
    switch (viewType) {
      case CalendarViewType.day:
        return DateFormat('dd MMMM yyyy', 'uk').format(selectedDate);
      case CalendarViewType.week:
        final startOfWeek = CalendarUtils.getStartOfWeek(selectedDate);
        final endOfWeek = startOfWeek.add(const Duration(days: 6));
        return '${DateFormat('dd MMM', 'uk').format(startOfWeek)} - ${DateFormat('dd MMM yyyy', 'uk').format(endOfWeek)}';
      case CalendarViewType.month:
        return DateFormat('MMMM yyyy', 'uk').format(selectedDate);
      case CalendarViewType.year:
        return DateFormat('yyyy').format(selectedDate);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Визначаємо, чи достатньо місця для повного макету
          final isWideScreen = constraints.maxWidth > 400;
          
          if (isWideScreen) {
            // Звичайний горизонтальний макет для широких екранів
            return Row(
              children: [
                // Група навігації
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left), 
                      onPressed: onPrevious,
                      visualDensity: VisualDensity.compact,
                    ),
                    Container(
                      constraints: BoxConstraints(
                        minWidth: math.min(200, constraints.maxWidth * 0.4), // Адаптивна ширина
                      ),
                      child: Text(
                        _getFormattedPeriod(),
                        style: Theme.of(context).textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right), 
                      onPressed: onNext,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                
                const Spacer(),
                
                // Група кнопок управління
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(onPressed: onToday, child: const Text('Сьогодні')),
                    const SizedBox(width: 12),
                    DropdownButton<CalendarViewType>(
                      value: viewType,
                      onChanged: (v) => onViewTypeChange(v!),
                      items: CalendarViewType.values.map((type) => DropdownMenuItem(
                        value: type,
                        child: Text(type.label),
                      )).toList(),
                    ),
                  ],
                ),
              ],
            );
          } else {
            // Компактний вертикальний макет для вузьких екранів
            return Column(
              children: [
                // Верхній рядок: навігація
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left), 
                      onPressed: onPrevious,
                      visualDensity: VisualDensity.compact,
                    ),
                    Expanded(
                      child: Text(
                        _getFormattedPeriod(),
                        style: Theme.of(context).textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right), 
                      onPressed: onNext,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                
                const SizedBox(height: 8),
                
                // Нижній рядок: кнопки управління
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(onPressed: onToday, child: const Text('Сьогодні')),
                    DropdownButton<CalendarViewType>(
                      value: viewType,
                      onChanged: (v) => onViewTypeChange(v!),
                      items: CalendarViewType.values.map((type) => DropdownMenuItem(
                        value: type,
                        child: Text(type.label),
                      )).toList(),
                    ),
                  ],
                ),
              ],
            );
          }
        },
      ),
    );
  }
}