// lib/pages/calendar_page/widgets/calendar_grid.dart

import 'package:flutter/material.dart';
import '../models/calendar_view_type.dart';
import '../../../models/lesson_model.dart';
import '../../../services/calendar_service.dart';
import '../calendar_utils.dart';
import 'views/mobile_day_view.dart';
import 'views/mobile_week_view.dart';
import 'views/month_view.dart';
import 'views/year_view.dart';
import 'views/desktop_week_view.dart';

class CalendarGrid extends StatefulWidget {
  final CalendarViewType viewType;
  final DateTime selectedDate;
  final List<String>? filteredGroups;
  final Function(LessonModel)? onLessonTap;
  final Function(DateTime)? onDateSelected;

  const CalendarGrid({
    super.key,
    required this.viewType,
    required this.selectedDate,
    this.filteredGroups,
    this.onLessonTap,
    this.onDateSelected,
  });

  @override
  State<CalendarGrid> createState() => _CalendarGridState();
}

class _CalendarGridState extends State<CalendarGrid> {
  final CalendarService _calendarService = CalendarService();
  List<LessonModel> _lessons = [];
  bool _isLoading = false;
  double _minHour = 8.0;
  double _maxHour = 20.0;

  @override
  void initState() {
    super.initState();
    _loadLessons();
  }

  @override
  void didUpdateWidget(CalendarGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDate != widget.selectedDate ||
        oldWidget.viewType != widget.viewType) {
      _loadLessons();
    }
  }

  Future<void> _loadLessons() async {
    setState(() => _isLoading = true);
    
    try {
      List<LessonModel> lessons;
      
      switch (widget.viewType) {
        case CalendarViewType.day:
          lessons = await _calendarService.getLessonsForDay(widget.selectedDate);
          break;
        case CalendarViewType.week:
          lessons = await _calendarService.getLessonsForWeek(widget.selectedDate);
          break;
        case CalendarViewType.month:
          final startOfMonth = CalendarUtils.getStartOfMonth(widget.selectedDate);
          final endOfMonth = CalendarUtils.getEndOfMonth(widget.selectedDate);
          lessons = await _calendarService.getLessonsForPeriod(
            startDate: startOfMonth,
            endDate: endOfMonth,
          );
          break;
        case CalendarViewType.year:
          final startOfYear = DateTime(widget.selectedDate.year, 1, 1);
          final endOfYear = DateTime(widget.selectedDate.year, 12, 31);
          lessons = await _calendarService.getLessonsForPeriod(
            startDate: startOfYear,
            endDate: endOfYear,
          );
          break;
      }

      if (mounted) {
        setState(() {
          _lessons = lessons;
          
          // Динамічно обчислюємо межі часу
          if (lessons.isNotEmpty) {
            _minHour = CalendarUtils.getMinHourFromLessons(lessons);
            _maxHour = CalendarUtils.getMaxHourFromLessons(lessons);
          } else {
            _minHour = 8.0;
            _maxHour = 20.0;
          }
          
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('CalendarGrid: Помилка завантаження занять: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Методи для отримання занять по датах
  List<LessonModel> getLessonsForSpecificDate(DateTime date) {
    final normalizedTargetDate = DateTime(date.year, date.month, date.day);
    
    return _lessons.where((lesson) {
      final normalizedLessonDate = DateTime(
        lesson.startTime.year, 
        lesson.startTime.month, 
        lesson.startTime.day
      );
      return normalizedLessonDate.isAtSameMomentAs(normalizedTargetDate);
    }).toList();
  }

  List<LessonModel> getLessonsForDay(int dayIndex) {
    final weekDays = CalendarUtils.getWeekDays(widget.selectedDate);
    final targetDate = weekDays[dayIndex];
    return getLessonsForSpecificDate(targetDate);
  }

  bool hasLessonsOnDay(int dayIndex) {
    return getLessonsForDay(dayIndex).isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final isTablet = constraints.maxWidth >= 600 && constraints.maxWidth < 1024;
        
        switch (widget.viewType) {
          case CalendarViewType.day:
            return MobileDayView(
              selectedDate: widget.selectedDate,
              lessons: _lessons,
              onLessonTap: widget.onLessonTap,
              onDateSelected: widget.onDateSelected,
              onRefresh: _loadLessons,
              getLessonsForSpecificDate: getLessonsForSpecificDate,
            );
            
          case CalendarViewType.week:
            if (isMobile) {
              return MobileWeekView(
                selectedDate: widget.selectedDate,
                lessons: _lessons,
                onLessonTap: widget.onLessonTap,
                onRefresh: _loadLessons,
                getLessonsForSpecificDate: getLessonsForSpecificDate,
              );
            } else {
              return DesktopWeekView(
                selectedDate: widget.selectedDate,
                lessons: _lessons,
                onLessonTap: widget.onLessonTap,
                onRefresh: _loadLessons,
                minHour: _minHour,
                maxHour: _maxHour,
                isTablet: isTablet,
                getLessonsForDay: getLessonsForDay,
                hasLessonsOnDay: hasLessonsOnDay,
                showSingleDay: false,
              );
            }
            
          case CalendarViewType.month:
            return MonthView(
              selectedDate: widget.selectedDate,
              lessons: _lessons,
              onDateSelected: widget.onDateSelected,
              onRefresh: _loadLessons,
              getLessonsForSpecificDate: getLessonsForSpecificDate,
              isMobile: isMobile,
            );
            
          case CalendarViewType.year:
            return YearView(
              selectedDate: widget.selectedDate,
              lessons: _lessons,
              onDateSelected: widget.onDateSelected,
              onRefresh: _loadLessons,
              isMobile: isMobile,
            );
        }
      },
    );
  }
}