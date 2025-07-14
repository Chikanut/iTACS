import 'package:flutter/material.dart';
import '../models/calendar_view_type.dart';
import 'calendar_header.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  CalendarViewType _viewType = CalendarViewType.week;
  DateTime _selectedDate = DateTime.now();

  void _goToToday() {
    setState(() => _selectedDate = DateTime.now());
  }

  void _goToPrevious() {
    setState(() {
      _selectedDate = _selectedDate.subtract(const Duration(days: 7));
    });
  }

  void _goToNext() {
    setState(() {
      _selectedDate = _selectedDate.add(const Duration(days: 7));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Календар занять'),
      ),
      body: Column(
        children: [
          CalendarHeader(
            viewType: _viewType,
            selectedDate: _selectedDate,
            onViewTypeChange: (type) => setState(() => _viewType = type),
            onPrevious: _goToPrevious,
            onNext: _goToNext,
            onToday: _goToToday,
          ),
          const Divider(height: 1),
          Expanded(
            child: Center(
              child: Text(
                'Поточний вигляд: ${_viewType.label}\nДата: ${_selectedDate.toLocal().toIso8601String()}',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
