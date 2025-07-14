import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'models/calendar_view_type.dart';
import 'widgets/calendar_header.dart';
import 'widgets/calendar_grid.dart';
import 'package:intl/intl.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  CalendarViewType _viewType = CalendarViewType.week;
  DateTime _selectedDate = DateTime.now();

  bool isMobile(BuildContext context) {
    final shortestSide = MediaQuery.of(context).size.shortestSide;
    return shortestSide < 600;
  }

  void _goToToday() {
    setState(() {
      _selectedDate = DateTime.now();
      _viewType = CalendarViewType.day;
    });
  }

  void _goToPrevious() {
    setState(() {
      switch (_viewType) {
        case CalendarViewType.day:
          _selectedDate = _selectedDate.subtract(const Duration(days: 1));
          break;
        case CalendarViewType.week:
          _selectedDate = _selectedDate.subtract(const Duration(days: 7));
          break;
        case CalendarViewType.month:
          _selectedDate = DateTime(_selectedDate.year, _selectedDate.month - 1, 1);
          break;
        case CalendarViewType.year:
          _selectedDate = DateTime(_selectedDate.year - 1, 1, 1);
          break;
      }
    });
  }

  void _goToNext() {
    setState(() {
      switch (_viewType) {
        case CalendarViewType.day:
          _selectedDate = _selectedDate.add(const Duration(days: 1));
          break;
        case CalendarViewType.week:
          _selectedDate = _selectedDate.add(const Duration(days: 7));
          break;
        case CalendarViewType.month:
          _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + 1, 1);
          break;
        case CalendarViewType.year:
          _selectedDate = DateTime(_selectedDate.year + 1, 1, 1);
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isOnMobileDevice = isMobile(context);

    Widget content;
    switch (_viewType) {
      case CalendarViewType.day:
        content = const Center(child: Text('Денний перегляд (todo)'));
        break;
      case CalendarViewType.week:
        content = CalendarGrid(
          viewType: _viewType,
          selectedDate: _selectedDate,
        );
        break;
      case CalendarViewType.month:
        content = const Center(child: Text('Місячний перегляд (todo)'));
        break;
      case CalendarViewType.year:
        content = const Center(child: Text('Річний перегляд (todo)'));
        break;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Календар занять — ${DateFormat('dd.MM.yyyy').format(_selectedDate)}'),
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
          Expanded(child: content),
        ],
      ),
    );
  }
}
