import 'package:flutter/material.dart';
import '../models/calendar_view_type.dart';

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

  @override
  Widget build(BuildContext context) {
    String formattedDate = '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.chevron_left), onPressed: onPrevious),
          Text(formattedDate, style: Theme.of(context).textTheme.titleMedium),
          IconButton(icon: const Icon(Icons.chevron_right), onPressed: onNext),
          const Spacer(),
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
    );
  }
}
