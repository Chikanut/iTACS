// lib/pages/calendar_page/widgets/calendar_grid.dart

import 'dart:async';

import 'package:flutter/material.dart';
import '../models/calendar_view_type.dart';
import '../models/calendar_filters.dart';
import '../../../models/lesson_model.dart';
import '../../../services/calendar_service.dart';
import '../../../globals.dart';
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
  final CalendarFilters filters;
  final Function(LessonModel)? onLessonTap;
  final Function(DateTime)? onDateSelected;

  const CalendarGrid({
    super.key,
    required this.viewType,
    required this.selectedDate,
    this.filters = CalendarFilters.empty,
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
    _hydrateCachedLessons();
    unawaited(_loadLessons());
  }

  @override
  void didUpdateWidget(CalendarGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDate != widget.selectedDate ||
        oldWidget.viewType != widget.viewType ||
        oldWidget.filters != widget.filters) {
      _hydrateCachedLessons();
      unawaited(_loadLessons());
    }
  }

  Future<void> _loadLessons() async {
    final shouldShowBlockingLoader = _lessons.isEmpty;
    setState(() => _isLoading = shouldShowBlockingLoader);

    try {
      List<LessonModel> lessons;

      switch (widget.viewType) {
        case CalendarViewType.day:
          lessons = await _calendarService.getLessonsForWeek(
            widget.selectedDate,
          );
          break;
        case CalendarViewType.week:
          lessons = await _calendarService.getLessonsForWeek(
            widget.selectedDate,
          );
          break;
        case CalendarViewType.month:
          final startOfMonth = CalendarUtils.getStartOfMonth(
            widget.selectedDate,
          );
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

      lessons = _applyFilters(lessons);

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

  void _hydrateCachedLessons() {
    final range = _resolveRequestedRange();
    final cachedLessons = _calendarService.getCachedLessonsForPeriod(
      startDate: range.start,
      endDate: range.end,
    );
    if (cachedLessons.isEmpty) {
      return;
    }

    final filteredLessons = _applyFilters(cachedLessons);
    setState(() {
      _lessons = filteredLessons;
      if (filteredLessons.isNotEmpty) {
        _minHour = CalendarUtils.getMinHourFromLessons(filteredLessons);
        _maxHour = CalendarUtils.getMaxHourFromLessons(filteredLessons);
      } else {
        _minHour = 8.0;
        _maxHour = 20.0;
      }
      _isLoading = false;
    });
  }

  ({DateTime start, DateTime end}) _resolveRequestedRange() {
    switch (widget.viewType) {
      case CalendarViewType.day:
      case CalendarViewType.week:
        return (
          start: CalendarUtils.getStartOfWeek(widget.selectedDate),
          end: CalendarUtils.getEndOfWeek(widget.selectedDate),
        );
      case CalendarViewType.month:
        return (
          start: CalendarUtils.getStartOfMonth(widget.selectedDate),
          end: CalendarUtils.getEndOfMonth(widget.selectedDate),
        );
      case CalendarViewType.year:
        return (
          start: DateTime(widget.selectedDate.year, 1, 1),
          end: DateTime(widget.selectedDate.year, 12, 31),
        );
    }
  }

  List<LessonModel> _applyFilters(List<LessonModel> lessons) {
    final filters = widget.filters;
    if (!filters.hasActiveFilters) {
      return lessons;
    }

    final currentUserId = Globals.profileManager.currentUserId?.trim() ?? '';
    final currentUserEmail =
        Globals.profileManager.currentUserEmail?.trim().toLowerCase() ?? '';
    final currentUserName = Globals.profileManager.currentUserName.trim();

    return lessons.where((lesson) {
      if (filters.showMineOnly) {
        final matchesCurrentUser =
            (currentUserId.isNotEmpty &&
                lesson.hasInstructorId(currentUserId)) ||
            (currentUserEmail.isNotEmpty &&
                (lesson.hasInstructorId(currentUserEmail) ||
                    lesson.hasInstructorName(currentUserEmail))) ||
            (currentUserName.isNotEmpty &&
                lesson.hasInstructorName(currentUserName));
        if (!matchesCurrentUser) {
          return false;
        }
      }

      if (filters.userIds.isNotEmpty &&
          !_matchesSelectedUsers(filters.userIds, lesson.instructorIds)) {
        return false;
      }

      if (filters.templateTitles.isNotEmpty &&
          !filters.templateTitles.contains(lesson.title.trim())) {
        return false;
      }

      return true;
    }).toList();
  }

  bool _matchesSelectedUsers(
    Set<String> selectedUsers,
    List<String> instructorIds,
  ) {
    for (final selectedUser in selectedUsers) {
      final variants = selectedUser
          .split('|')
          .map((value) => value.trim().toLowerCase())
          .where((value) => value.isNotEmpty);
      if (instructorIds.any(
        (instructorId) => variants.contains(instructorId.trim().toLowerCase()),
      )) {
        return true;
      }
    }

    return false;
  }

  // Методи для отримання занять по датах
  List<LessonModel> getLessonsForSpecificDate(DateTime date) {
    final normalizedTargetDate = DateTime(date.year, date.month, date.day);

    return _lessons.where((lesson) {
      final normalizedLessonDate = DateTime(
        lesson.startTime.year,
        lesson.startTime.month,
        lesson.startTime.day,
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
      return const Center(child: CircularProgressIndicator());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final isTablet =
            constraints.maxWidth >= 600 && constraints.maxWidth < 1024;

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
