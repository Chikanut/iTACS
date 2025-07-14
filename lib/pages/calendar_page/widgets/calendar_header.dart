// lib/pages/calendar_page/widgets/calendar_header.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
      child: Row(
        children: [
          // Група навігації (стрілки + текст) - компактно
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left), 
                onPressed: onPrevious,
                visualDensity: VisualDensity.compact, // 👈 Компактніший розмір
              ),
              Container(
                constraints: const BoxConstraints(minWidth: 200), // 👈 Фіксована мінімальна ширина
                child: Text(
                  _getFormattedPeriod(),
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right), 
                onPressed: onNext,
                visualDensity: VisualDensity.compact, // 👈 Компактніший розмір
              ),
            ],
          ),
          
          const Spacer(), // 👈 Відштовхує кнопки вправо
          
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
      ),
    );
  }
}