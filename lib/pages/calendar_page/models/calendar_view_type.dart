enum CalendarViewType {
  day,
  week,
  month,
  year,
}

extension CalendarViewTypeExtension on CalendarViewType {
  String get label {
    switch (this) {
      case CalendarViewType.day:
        return 'День';
      case CalendarViewType.week:
        return 'Тиждень';
      case CalendarViewType.month:
        return 'Місяць';
      case CalendarViewType.year:
        return 'Рік';
    }
  }
}
