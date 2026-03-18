class CalendarFilters {
  final bool showMineOnly;
  final Set<String> userIds;
  final Set<String> templateTitles;

  const CalendarFilters({
    this.showMineOnly = false,
    this.userIds = const <String>{},
    this.templateTitles = const <String>{},
  });

  static const CalendarFilters empty = CalendarFilters();

  bool get hasActiveFilters {
    return showMineOnly || userIds.isNotEmpty || templateTitles.isNotEmpty;
  }

  int get activeFiltersCount {
    return (showMineOnly ? 1 : 0) + userIds.length + templateTitles.length;
  }
}
