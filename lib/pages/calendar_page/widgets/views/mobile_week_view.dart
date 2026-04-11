import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../models/lesson_model.dart';
import '../../../../theme/app_theme.dart';
import '../../calendar_utils.dart';
import '../mobile_lesson_card.dart';

class MobileWeekView extends StatefulWidget {
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
  State<MobileWeekView> createState() => _MobileWeekViewState();
}

class _MobileWeekViewState extends State<MobileWeekView> {
  final Map<String, GlobalKey> _daySectionKeys = {};

  @override
  void initState() {
    super.initState();
    _syncDaySectionKeys();
    _scheduleScrollToSelectedDay();
  }

  @override
  void didUpdateWidget(covariant MobileWeekView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncDaySectionKeys();

    if (!CalendarUtils.isSameDay(oldWidget.selectedDate, widget.selectedDate) ||
        oldWidget.lessons.length != widget.lessons.length) {
      _scheduleScrollToSelectedDay();
    }
  }

  @override
  Widget build(BuildContext context) {
    final weekDays = CalendarUtils.getWeekDays(widget.selectedDate);
    final hasAnyLessons = weekDays.any(
      (day) => widget.getLessonsForSpecificDate(day).isNotEmpty,
    );

    if (!hasAnyLessons) {
      return _buildEmptyState(context);
    }

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: weekDays.length,
        separatorBuilder: (context, index) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final date = weekDays[index];
          final lessonsForDay = widget.getLessonsForSpecificDate(date);

          return _buildDaySection(
            context,
            date,
            lessonsForDay,
            key: _daySectionKeys[_dayId(date)],
          );
        },
      ),
    );
  }

  Widget _buildDaySection(
    BuildContext context,
    DateTime date,
    List<LessonModel> lessonsForDay, {
    Key? key,
  }) {
    final isSelected = CalendarUtils.isSameDay(date, widget.selectedDate);
    final isToday = CalendarUtils.isToday(date);

    return Container(
      key: key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDateHeader(context, date, isSelected: isSelected),
          const SizedBox(height: 8),
          if (lessonsForDay.isEmpty)
            _buildEmptyDayCard(
              context,
              isSelected: isSelected,
              isToday: isToday,
            )
          else
            ...lessonsForDay.map(
              (lesson) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: MobileLessonCard(
                  lesson: lesson,
                  onTap: () => widget.onLessonTap?.call(lesson),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDateHeader(
    BuildContext context,
    DateTime date, {
    required bool isSelected,
  }) {
    final isToday = CalendarUtils.isToday(date);
    final primaryColor = Theme.of(context).primaryColor;
    final todayColors = AppTheme.infoStatus;
    final shouldHighlight = isSelected || isToday;
    final backgroundColor = isToday
        ? todayColors.background
        : isSelected
        ? AppTheme.surfaceRaised
        : AppTheme.surfaceOverlay;
    final borderColor = isToday
        ? todayColors.border
        : isSelected
        ? primaryColor.withOpacity(0.5)
        : AppTheme.borderSubtle;
    final foregroundColor = isToday
        ? todayColors.foreground
        : isSelected
        ? primaryColor
        : AppTheme.textPrimary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: isToday ? 1.5 : 1),
        boxShadow: shouldHighlight
            ? const [
                BoxShadow(
                  color: Color(0x16000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              DateFormat('EEEE, dd MMMM', 'uk').format(date),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: foregroundColor,
              ),
            ),
          ),
          if (isToday) ...[
            _buildHeaderBadge(
              context,
              label: 'Сьогодні',
              backgroundColor: todayColors.border,
              foregroundColor: todayColors.foreground,
            ),
            const SizedBox(width: 8),
          ],
          if (isSelected)
            _buildHeaderBadge(
              context,
              label: 'Обрано',
              backgroundColor: primaryColor.withOpacity(0.12),
              foregroundColor: primaryColor,
            ),
        ],
      ),
    );
  }

  Widget _buildHeaderBadge(
    BuildContext context, {
    required String label,
    required Color backgroundColor,
    required Color foregroundColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foregroundColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildEmptyDayCard(
    BuildContext context, {
    required bool isSelected,
    required bool isToday,
  }) {
    final primaryColor = Theme.of(context).primaryColor;
    final todayColors = AppTheme.infoStatus;
    final shouldHighlight = isSelected || isToday;
    final backgroundColor = isToday
        ? todayColors.background.withOpacity(0.55)
        : isSelected
        ? AppTheme.surfaceRaised
        : Colors.grey.shade50;
    final borderColor = isToday
        ? todayColors.border.withOpacity(0.75)
        : isSelected
        ? primaryColor.withOpacity(0.25)
        : Colors.grey.shade200;
    final foregroundColor = isToday
        ? todayColors.foreground
        : shouldHighlight
        ? primaryColor
        : Colors.grey.shade700;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        'Немає занять на цей день',
        style: TextStyle(
          color: foregroundColor,
          fontWeight: shouldHighlight ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Немає занять на цьому тижні',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: widget.onRefresh,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Оновити'),
          ),
        ],
      ),
    );
  }

  void _syncDaySectionKeys() {
    final activeIds = CalendarUtils.getWeekDays(
      widget.selectedDate,
    ).map(_dayId).toSet();

    _daySectionKeys.removeWhere((dayId, _) => !activeIds.contains(dayId));

    for (final dayId in activeIds) {
      _daySectionKeys.putIfAbsent(dayId, () => GlobalKey());
    }
  }

  void _scheduleScrollToSelectedDay() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final selectedContext =
          _daySectionKeys[_dayId(widget.selectedDate)]?.currentContext;
      if (selectedContext == null) {
        return;
      }

      Scrollable.ensureVisible(
        selectedContext,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        alignment: 0.14,
      );
    });
  }

  String _dayId(DateTime date) {
    return '${date.year}-${date.month}-${date.day}';
  }
}
