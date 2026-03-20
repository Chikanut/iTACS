class NotificationPreferenceDefinition {
  final String key;
  final String title;
  final String description;

  const NotificationPreferenceDefinition({
    required this.key,
    required this.title,
    required this.description,
  });
}

class NotificationPreferences {
  static const String groupAnnouncementsKey = 'groupAnnouncements';
  static const String lessonAssignedKey = 'lessonAssigned';
  static const String lessonRemovedKey = 'lessonRemoved';
  static const String lessonCriticalChangedKey = 'lessonCriticalChanged';
  static const String absenceRequestResultKey = 'absenceRequestResult';
  static const String adminAbsenceAssignmentKey = 'adminAbsenceAssignment';
  static const String adminLessonAcknowledgedKey = 'adminLessonAcknowledged';

  static const List<String> keys = [
    groupAnnouncementsKey,
    lessonAssignedKey,
    lessonRemovedKey,
    lessonCriticalChangedKey,
    absenceRequestResultKey,
    adminAbsenceAssignmentKey,
    adminLessonAcknowledgedKey,
  ];

  static const List<NotificationPreferenceDefinition> generalDefinitions = [
    NotificationPreferenceDefinition(
      key: groupAnnouncementsKey,
      title: 'Оголошення для групи',
      description:
          'Загальні важливі повідомлення та оголошення для всієї групи.',
    ),
    NotificationPreferenceDefinition(
      key: lessonAssignedKey,
      title: 'Призначення на заняття',
      description: 'Коли вас додають викладачем до нового заняття.',
    ),
    NotificationPreferenceDefinition(
      key: lessonRemovedKey,
      title: 'Зняття із заняття',
      description: 'Коли вас прибирають зі складу викладачів заняття.',
    ),
    NotificationPreferenceDefinition(
      key: lessonCriticalChangedKey,
      title: 'Критичні зміни заняття',
      description:
          'Коли у вашому занятті змінюються дата, час або підрозділ і потрібно переознайомлення.',
    ),
    NotificationPreferenceDefinition(
      key: absenceRequestResultKey,
      title: 'Результат запиту на відсутність',
      description:
          'Рішення по вашому запиту на відпустку або лікарняний, а також його скасування.',
    ),
    NotificationPreferenceDefinition(
      key: adminAbsenceAssignmentKey,
      title: 'Наряд та відрядження',
      description:
          'Коли вам призначають, змінюють або скасовують наряд чи відрядження.',
    ),
  ];

  static const List<NotificationPreferenceDefinition> adminDefinitions = [
    NotificationPreferenceDefinition(
      key: adminLessonAcknowledgedKey,
      title: 'Ознайомлення із заняттям',
      description:
          'Коли викладач ознайомився із заняттям, призначеним на нього.',
    ),
  ];

  final bool groupAnnouncements;
  final bool lessonAssigned;
  final bool lessonRemoved;
  final bool lessonCriticalChanged;
  final bool absenceRequestResult;
  final bool adminAbsenceAssignment;
  final bool adminLessonAcknowledged;

  const NotificationPreferences({
    this.groupAnnouncements = true,
    this.lessonAssigned = true,
    this.lessonRemoved = true,
    this.lessonCriticalChanged = true,
    this.absenceRequestResult = true,
    this.adminAbsenceAssignment = true,
    this.adminLessonAcknowledged = true,
  });

  static const defaults = NotificationPreferences();

  factory NotificationPreferences.fromMap(Map<String, dynamic>? map) {
    final source = map ?? const <String, dynamic>{};
    return NotificationPreferences(
      groupAnnouncements: _readBool(source[groupAnnouncementsKey]),
      lessonAssigned: _readBool(source[lessonAssignedKey]),
      lessonRemoved: _readBool(source[lessonRemovedKey]),
      lessonCriticalChanged: _readBool(source[lessonCriticalChangedKey]),
      absenceRequestResult: _readBool(source[absenceRequestResultKey]),
      adminAbsenceAssignment: _readBool(source[adminAbsenceAssignmentKey]),
      adminLessonAcknowledged: _readBool(source[adminLessonAcknowledgedKey]),
    );
  }

  Map<String, bool> toMap() {
    return {
      groupAnnouncementsKey: groupAnnouncements,
      lessonAssignedKey: lessonAssigned,
      lessonRemovedKey: lessonRemoved,
      lessonCriticalChangedKey: lessonCriticalChanged,
      absenceRequestResultKey: absenceRequestResult,
      adminAbsenceAssignmentKey: adminAbsenceAssignment,
      adminLessonAcknowledgedKey: adminLessonAcknowledged,
    };
  }

  NotificationPreferences copyWith({
    bool? groupAnnouncements,
    bool? lessonAssigned,
    bool? lessonRemoved,
    bool? lessonCriticalChanged,
    bool? absenceRequestResult,
    bool? adminAbsenceAssignment,
    bool? adminLessonAcknowledged,
  }) {
    return NotificationPreferences(
      groupAnnouncements: groupAnnouncements ?? this.groupAnnouncements,
      lessonAssigned: lessonAssigned ?? this.lessonAssigned,
      lessonRemoved: lessonRemoved ?? this.lessonRemoved,
      lessonCriticalChanged:
          lessonCriticalChanged ?? this.lessonCriticalChanged,
      absenceRequestResult: absenceRequestResult ?? this.absenceRequestResult,
      adminAbsenceAssignment:
          adminAbsenceAssignment ?? this.adminAbsenceAssignment,
      adminLessonAcknowledged:
          adminLessonAcknowledged ?? this.adminLessonAcknowledged,
    );
  }

  bool valueForKey(String key) {
    switch (key) {
      case groupAnnouncementsKey:
        return groupAnnouncements;
      case lessonAssignedKey:
        return lessonAssigned;
      case lessonRemovedKey:
        return lessonRemoved;
      case lessonCriticalChangedKey:
        return lessonCriticalChanged;
      case absenceRequestResultKey:
        return absenceRequestResult;
      case adminAbsenceAssignmentKey:
        return adminAbsenceAssignment;
      case adminLessonAcknowledgedKey:
        return adminLessonAcknowledged;
      default:
        return true;
    }
  }

  static bool _readBool(dynamic value) {
    return value is bool ? value : true;
  }
}
