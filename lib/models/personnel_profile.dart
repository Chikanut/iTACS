import 'package:intl/intl.dart';

String _text(dynamic value) => value?.toString().trim() ?? '';

DateTime? _date(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String && value.trim().isNotEmpty) {
    return DateTime.tryParse(value.trim());
  }

  try {
    final dynamicValue = value as dynamic;
    final converted = dynamicValue.toDate();
    if (converted is DateTime) return converted;
  } catch (_) {}

  return null;
}

List<Map<String, dynamic>> _mapList(dynamic value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((entry) => Map<String, dynamic>.from(entry))
      .toList(growable: false);
}

class PersonnelProfile {
  static final DateFormat exportDateFormat = DateFormat('dd.MM.yyyy');

  final String uid;
  final String email;
  final String firstName;
  final String lastName;
  final String patronymic;
  final String militaryUnit;
  final String position;
  final String staffRank;
  final String rank;
  final String militarySpecialty;
  final DateTime? birthDate;
  final String phone;
  final String positionOrderNumber;
  final DateTime? positionOrderDate;
  final List<RankHistoryEntry> rankHistory;
  final String serviceType;
  final DateTime? serviceStartDate;
  final DateTime? contractEndDate;
  final DateTime? mobilizationDate;
  final bool? relocationReady;
  final List<EducationEntry> education;
  final List<OnlineCourseEntry> onlineCourses;
  final String familyStatus;
  final List<FamilyMemberEntry> familyMembers;
  final String housingStatus;
  final String homeAddress;
  final String currentStatus;
  final String rating;
  final List<AwardEntry> awards;
  final List<EventHistoryEntry> combatParticipation;
  final List<EventHistoryEntry> wounds;
  final List<LanguageSkillEntry> languageSkills;
  final DateTime? updatedAt;
  final String updatedBy;

  const PersonnelProfile({
    required this.uid,
    required this.email,
    this.firstName = '',
    this.lastName = '',
    this.patronymic = '',
    this.militaryUnit = '',
    this.position = '',
    this.staffRank = '',
    this.rank = '',
    this.militarySpecialty = '',
    this.birthDate,
    this.phone = '',
    this.positionOrderNumber = '',
    this.positionOrderDate,
    this.rankHistory = const [],
    this.serviceType = '',
    this.serviceStartDate,
    this.contractEndDate,
    this.mobilizationDate,
    this.relocationReady,
    this.education = const [],
    this.onlineCourses = const [],
    this.familyStatus = '',
    this.familyMembers = const [],
    this.housingStatus = '',
    this.homeAddress = '',
    this.currentStatus = '',
    this.rating = '',
    this.awards = const [],
    this.combatParticipation = const [],
    this.wounds = const [],
    this.languageSkills = const [],
    this.updatedAt,
    this.updatedBy = '',
  });

  factory PersonnelProfile.empty({
    required String uid,
    required String email,
    String firstName = '',
    String lastName = '',
    String rank = '',
    String position = '',
    String phone = '',
  }) {
    return PersonnelProfile(
      uid: uid,
      email: email,
      firstName: firstName,
      lastName: lastName,
      rank: rank,
      position: position,
      phone: phone,
      currentStatus: 'в строю',
      serviceType: 'contract',
      relocationReady: false,
    );
  }

  factory PersonnelProfile.fromMap(Map<String, dynamic> map) {
    return PersonnelProfile(
      uid: _text(map['uid']),
      email: _text(map['email']),
      firstName: _text(map['firstName']),
      lastName: _text(map['lastName']),
      patronymic: _text(map['patronymic']),
      militaryUnit: _text(map['militaryUnit']),
      position: _text(map['position']),
      staffRank: _text(map['staffRank']),
      rank: _text(map['rank']),
      militarySpecialty: _text(map['militarySpecialty']),
      birthDate: _date(map['birthDate']),
      phone: _text(map['phone']),
      positionOrderNumber: _text(map['positionOrderNumber']),
      positionOrderDate: _date(map['positionOrderDate']),
      rankHistory: _mapList(
        map['rankHistory'],
      ).map(RankHistoryEntry.fromMap).toList(growable: false),
      serviceType: _text(map['serviceType']),
      serviceStartDate: _date(map['serviceStartDate']),
      contractEndDate: _date(map['contractEndDate']),
      mobilizationDate: _date(map['mobilizationDate']),
      relocationReady: map['relocationReady'] is bool
          ? map['relocationReady'] as bool
          : null,
      education: _mapList(
        map['education'],
      ).map(EducationEntry.fromMap).toList(growable: false),
      onlineCourses: _mapList(
        map['onlineCourses'],
      ).map(OnlineCourseEntry.fromMap).toList(growable: false),
      familyStatus: _text(map['familyStatus']),
      familyMembers: _mapList(
        map['familyMembers'],
      ).map(FamilyMemberEntry.fromMap).toList(growable: false),
      housingStatus: _text(map['housingStatus']),
      homeAddress: _text(map['homeAddress']),
      currentStatus: _text(map['currentStatus']),
      rating: _text(map['rating']),
      awards: _mapList(
        map['awards'],
      ).map(AwardEntry.fromMap).toList(growable: false),
      combatParticipation: _mapList(
        map['combatParticipation'],
      ).map(EventHistoryEntry.fromMap).toList(growable: false),
      wounds: _mapList(
        map['wounds'],
      ).map(EventHistoryEntry.fromMap).toList(growable: false),
      languageSkills: _mapList(
        map['languageSkills'],
      ).map(LanguageSkillEntry.fromMap).toList(growable: false),
      updatedAt: _date(map['updatedAt']),
      updatedBy: _text(map['updatedBy']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'patronymic': patronymic,
      'militaryUnit': militaryUnit,
      'position': position,
      'staffRank': staffRank,
      'rank': rank,
      'militarySpecialty': militarySpecialty,
      'birthDate': birthDate?.toIso8601String(),
      'phone': phone,
      'positionOrderNumber': positionOrderNumber,
      'positionOrderDate': positionOrderDate?.toIso8601String(),
      'rankHistory': rankHistory.map((entry) => entry.toMap()).toList(),
      'serviceType': serviceType,
      'serviceStartDate': serviceStartDate?.toIso8601String(),
      'contractEndDate': contractEndDate?.toIso8601String(),
      'mobilizationDate': mobilizationDate?.toIso8601String(),
      'relocationReady': relocationReady,
      'education': education.map((entry) => entry.toMap()).toList(),
      'onlineCourses': onlineCourses.map((entry) => entry.toMap()).toList(),
      'familyStatus': familyStatus,
      'familyMembers': familyMembers.map((entry) => entry.toMap()).toList(),
      'housingStatus': housingStatus,
      'homeAddress': homeAddress,
      'currentStatus': currentStatus,
      'rating': rating,
      'awards': awards.map((entry) => entry.toMap()).toList(),
      'combatParticipation': combatParticipation
          .map((entry) => entry.toMap())
          .toList(),
      'wounds': wounds.map((entry) => entry.toMap()).toList(),
      'languageSkills': languageSkills.map((entry) => entry.toMap()).toList(),
      'updatedAt': updatedAt?.toIso8601String(),
      'updatedBy': updatedBy,
    };
  }

  PersonnelProfile copyWith({
    String? uid,
    String? email,
    String? firstName,
    String? lastName,
    String? patronymic,
    String? militaryUnit,
    String? position,
    String? staffRank,
    String? rank,
    String? militarySpecialty,
    DateTime? birthDate,
    String? phone,
    String? positionOrderNumber,
    DateTime? positionOrderDate,
    List<RankHistoryEntry>? rankHistory,
    String? serviceType,
    DateTime? serviceStartDate,
    DateTime? contractEndDate,
    DateTime? mobilizationDate,
    bool? relocationReady,
    List<EducationEntry>? education,
    List<OnlineCourseEntry>? onlineCourses,
    String? familyStatus,
    List<FamilyMemberEntry>? familyMembers,
    String? housingStatus,
    String? homeAddress,
    String? currentStatus,
    String? rating,
    List<AwardEntry>? awards,
    List<EventHistoryEntry>? combatParticipation,
    List<EventHistoryEntry>? wounds,
    List<LanguageSkillEntry>? languageSkills,
    DateTime? updatedAt,
    String? updatedBy,
  }) {
    return PersonnelProfile(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      patronymic: patronymic ?? this.patronymic,
      militaryUnit: militaryUnit ?? this.militaryUnit,
      position: position ?? this.position,
      staffRank: staffRank ?? this.staffRank,
      rank: rank ?? this.rank,
      militarySpecialty: militarySpecialty ?? this.militarySpecialty,
      birthDate: birthDate ?? this.birthDate,
      phone: phone ?? this.phone,
      positionOrderNumber: positionOrderNumber ?? this.positionOrderNumber,
      positionOrderDate: positionOrderDate ?? this.positionOrderDate,
      rankHistory: rankHistory ?? this.rankHistory,
      serviceType: serviceType ?? this.serviceType,
      serviceStartDate: serviceStartDate ?? this.serviceStartDate,
      contractEndDate: contractEndDate ?? this.contractEndDate,
      mobilizationDate: mobilizationDate ?? this.mobilizationDate,
      relocationReady: relocationReady ?? this.relocationReady,
      education: education ?? this.education,
      onlineCourses: onlineCourses ?? this.onlineCourses,
      familyStatus: familyStatus ?? this.familyStatus,
      familyMembers: familyMembers ?? this.familyMembers,
      housingStatus: housingStatus ?? this.housingStatus,
      homeAddress: homeAddress ?? this.homeAddress,
      currentStatus: currentStatus ?? this.currentStatus,
      rating: rating ?? this.rating,
      awards: awards ?? this.awards,
      combatParticipation: combatParticipation ?? this.combatParticipation,
      wounds: wounds ?? this.wounds,
      languageSkills: languageSkills ?? this.languageSkills,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  String get fullName => [
    lastName,
    firstName,
    patronymic,
  ].where((part) => part.isNotEmpty).join(' ');

  RankHistoryEntry? get currentRankRecord {
    if (rankHistory.isEmpty) return null;
    final marked = rankHistory.where((entry) => entry.isCurrent).toList();
    final candidates = marked.isNotEmpty ? marked : rankHistory;
    candidates.sort((a, b) {
      final aDate = a.orderDate ?? DateTime(1900);
      final bDate = b.orderDate ?? DateTime(1900);
      return bDate.compareTo(aDate);
    });
    return candidates.first;
  }

  String get currentRankText {
    final record = currentRankRecord;
    if (record != null && record.rank.isNotEmpty) return record.rank;
    return rank;
  }

  String get staffAndCurrentRank {
    final parts = <String>[
      if (staffRank.isNotEmpty) staffRank,
      if (currentRankText.isNotEmpty) currentRankText,
    ];
    return parts.join(' / ');
  }

  String get positionOrderText =>
      _orderText(positionOrderNumber, positionOrderDate);

  String get rankOrderText {
    final record = currentRankRecord;
    if (record == null) return '';
    return _orderText(record.orderNumber, record.orderDate);
  }

  String get serviceText {
    if (serviceType == 'contract') {
      final end = formatDate(contractEndDate);
      return end.isEmpty ? 'контракт' : 'контракт до $end';
    }

    if (serviceType == 'mobilization') {
      final date = formatDate(mobilizationDate ?? serviceStartDate);
      return date.isEmpty
          ? 'призваний під час мобілізації'
          : 'призваний під час мобілізації $date';
    }

    return '';
  }

  String get relocationText {
    if (relocationReady == null) return '';
    return relocationReady! ? 'готовий' : 'не готовий';
  }

  String get educationText =>
      _numbered(education.map((entry) => entry.summary));

  String get onlineCoursesText =>
      _numbered(onlineCourses.map((entry) => entry.summary));

  String get familyText {
    final parts = <String>[
      if (familyStatus.isNotEmpty) familyStatus,
      ...familyMembers
          .map((entry) => entry.summary)
          .where((line) => line.isNotEmpty),
    ];
    return parts.join('\n');
  }

  String get housingText {
    return [
      if (housingStatus.isNotEmpty) housingStatus,
      if (homeAddress.isNotEmpty) homeAddress,
      if (phone.isNotEmpty) phone,
    ].join('. ');
  }

  String get awardsText => _numbered(awards.map((entry) => entry.summary));

  String get combatText =>
      _numbered(combatParticipation.map((entry) => entry.summary));

  String get woundsText => _numbered(wounds.map((entry) => entry.summary));

  String get languagesText =>
      _numbered(languageSkills.map((entry) => entry.summary));

  Map<String, String> toExportFields() {
    return {
      'militaryUnit': militaryUnit,
      'position': position,
      'staffAndRank': staffAndCurrentRank,
      'militarySpecialty': militarySpecialty,
      'fullName': fullName,
      'positionOrder': positionOrderText,
      'rankOrder': rankOrderText,
      'birthDate': formatDate(birthDate),
      'education': educationText,
      'onlineCourses': onlineCoursesText,
      'service': serviceText,
      'relocationReady': relocationText,
      'family': familyText,
      'housing': housingText,
      'currentStatus': currentStatus,
      'rating': rating,
      'awards': awardsText,
      'combatParticipation': combatText,
      'wounds': woundsText,
      'languages': languagesText,
    };
  }

  static String formatDate(DateTime? date) {
    return date == null ? '' : exportDateFormat.format(date);
  }

  static String _orderText(String number, DateTime? date) {
    if (number.isEmpty && date == null) return '';
    final dateText = formatDate(date);
    if (number.isEmpty) return dateText;
    if (dateText.isEmpty) return '№$number';
    return '№$number від $dateText';
  }

  static String _numbered(Iterable<String> lines) {
    final clean = lines.where((line) => line.trim().isNotEmpty).toList();
    if (clean.isEmpty) return '';
    return [
      for (var i = 0; i < clean.length; i++) '${i + 1}. ${clean[i]}',
    ].join('\n');
  }
}

class RankHistoryEntry {
  final String rank;
  final String orderNumber;
  final DateTime? orderDate;
  final bool isCurrent;

  const RankHistoryEntry({
    this.rank = '',
    this.orderNumber = '',
    this.orderDate,
    this.isCurrent = false,
  });

  factory RankHistoryEntry.fromMap(Map<String, dynamic> map) {
    return RankHistoryEntry(
      rank: _text(map['rank']),
      orderNumber: _text(map['orderNumber']),
      orderDate: _date(map['orderDate']),
      isCurrent: map['isCurrent'] == true,
    );
  }

  Map<String, dynamic> toMap() => {
    'rank': rank,
    'orderNumber': orderNumber,
    'orderDate': orderDate?.toIso8601String(),
    'isCurrent': isCurrent,
  };
}

class EducationEntry {
  final String type;
  final String institution;
  final String specialty;
  final String degree;
  final String year;
  final String notes;

  const EducationEntry({
    this.type = '',
    this.institution = '',
    this.specialty = '',
    this.degree = '',
    this.year = '',
    this.notes = '',
  });

  factory EducationEntry.fromMap(Map<String, dynamic> map) {
    return EducationEntry(
      type: _text(map['type']),
      institution: _text(map['institution']),
      specialty: _text(map['specialty']),
      degree: _text(map['degree']),
      year: _text(map['year']),
      notes: _text(map['notes']),
    );
  }

  Map<String, dynamic> toMap() => {
    'type': type,
    'institution': institution,
    'specialty': specialty,
    'degree': degree,
    'year': year,
    'notes': notes,
  };

  String get summary {
    return [
      if (type.isNotEmpty) type,
      if (institution.isNotEmpty) institution,
      if (specialty.isNotEmpty) 'спеціальність - $specialty',
      if (degree.isNotEmpty || year.isNotEmpty)
        [if (year.isNotEmpty) year, if (degree.isNotEmpty) degree].join(' - '),
      if (notes.isNotEmpty) notes,
    ].join(', ');
  }
}

class OnlineCourseEntry {
  final String topic;
  final DateTime? date;
  final String certificateNumber;

  const OnlineCourseEntry({
    this.topic = '',
    this.date,
    this.certificateNumber = '',
  });

  factory OnlineCourseEntry.fromMap(Map<String, dynamic> map) {
    return OnlineCourseEntry(
      topic: _text(map['topic']),
      date: _date(map['date']),
      certificateNumber: _text(map['certificateNumber']),
    );
  }

  Map<String, dynamic> toMap() => {
    'topic': topic,
    'date': date?.toIso8601String(),
    'certificateNumber': certificateNumber,
  };

  String get summary {
    return [
      if (topic.isNotEmpty) topic,
      if (date != null) 'сертифікат від ${PersonnelProfile.formatDate(date)}',
      if (certificateNumber.isNotEmpty) '№ $certificateNumber',
    ].join(', ');
  }
}

class FamilyMemberEntry {
  final String relation;
  final String fullName;
  final DateTime? birthDate;
  final String profession;
  final String address;
  final String phone;

  const FamilyMemberEntry({
    this.relation = '',
    this.fullName = '',
    this.birthDate,
    this.profession = '',
    this.address = '',
    this.phone = '',
  });

  factory FamilyMemberEntry.fromMap(Map<String, dynamic> map) {
    return FamilyMemberEntry(
      relation: _text(map['relation']),
      fullName: _text(map['fullName']),
      birthDate: _date(map['birthDate']),
      profession: _text(map['profession']),
      address: _text(map['address']),
      phone: _text(map['phone']),
    );
  }

  Map<String, dynamic> toMap() => {
    'relation': relation,
    'fullName': fullName,
    'birthDate': birthDate?.toIso8601String(),
    'profession': profession,
    'address': address,
    'phone': phone,
  };

  String get summary {
    return [
      if (relation.isNotEmpty) '$relation:',
      if (fullName.isNotEmpty) fullName,
      if (birthDate != null) '${PersonnelProfile.formatDate(birthDate)} р.н.',
      if (profession.isNotEmpty) profession,
      if (address.isNotEmpty) address,
      if (phone.isNotEmpty) phone,
    ].join(' ');
  }
}

class AwardEntry {
  final String name;
  final String orderNumber;
  final DateTime? date;

  const AwardEntry({this.name = '', this.orderNumber = '', this.date});

  factory AwardEntry.fromMap(Map<String, dynamic> map) {
    return AwardEntry(
      name: _text(map['name']),
      orderNumber: _text(map['orderNumber']),
      date: _date(map['date']),
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'orderNumber': orderNumber,
    'date': date?.toIso8601String(),
  };

  String get summary {
    return [
      if (name.isNotEmpty) name,
      if (orderNumber.isNotEmpty) '№$orderNumber',
      if (date != null) 'від ${PersonnelProfile.formatDate(date)}',
    ].join(' ');
  }
}

class EventHistoryEntry {
  final DateTime? startDate;
  final DateTime? endDate;
  final String time;
  final String place;
  final String circumstances;

  const EventHistoryEntry({
    this.startDate,
    this.endDate,
    this.time = '',
    this.place = '',
    this.circumstances = '',
  });

  factory EventHistoryEntry.fromMap(Map<String, dynamic> map) {
    return EventHistoryEntry(
      startDate: _date(map['startDate']),
      endDate: _date(map['endDate']),
      time: _text(map['time']),
      place: _text(map['place']),
      circumstances: _text(map['circumstances']),
    );
  }

  Map<String, dynamic> toMap() => {
    'startDate': startDate?.toIso8601String(),
    'endDate': endDate?.toIso8601String(),
    'time': time,
    'place': place,
    'circumstances': circumstances,
  };

  String get summary {
    final dateText = endDate == null || startDate == endDate
        ? PersonnelProfile.formatDate(startDate)
        : '${PersonnelProfile.formatDate(startDate)} - ${PersonnelProfile.formatDate(endDate)}';
    return [
      if (dateText.isNotEmpty) dateText,
      if (time.isNotEmpty) time,
      if (place.isNotEmpty) place,
      if (circumstances.isNotEmpty) circumstances,
    ].join(', ');
  }
}

class LanguageSkillEntry {
  final String language;
  final String civilianLevel;
  final String militaryLevel;

  const LanguageSkillEntry({
    this.language = '',
    this.civilianLevel = '',
    this.militaryLevel = '',
  });

  factory LanguageSkillEntry.fromMap(Map<String, dynamic> map) {
    return LanguageSkillEntry(
      language: _text(map['language']),
      civilianLevel: _text(map['civilianLevel']),
      militaryLevel: _text(map['militaryLevel']),
    );
  }

  Map<String, dynamic> toMap() => {
    'language': language,
    'civilianLevel': civilianLevel,
    'militaryLevel': militaryLevel,
  };

  String get summary {
    return [
      if (language.isNotEmpty) language,
      if (civilianLevel.isNotEmpty) 'цивільний: $civilianLevel',
      if (militaryLevel.isNotEmpty) 'військовий: $militaryLevel',
    ].join(', ');
  }
}

class PersonnelExportColumn {
  final String key;
  final String title;

  const PersonnelExportColumn(this.key, this.title);

  static const standard = <PersonnelExportColumn>[
    PersonnelExportColumn('militaryUnit', 'В/ч'),
    PersonnelExportColumn('position', 'Посада'),
    PersonnelExportColumn('staffAndRank', 'ШПК Військове звання'),
    PersonnelExportColumn('militarySpecialty', 'ВОС'),
    PersonnelExportColumn('fullName', 'Прізвище, імя та по батькові'),
    PersonnelExportColumn(
      'positionOrder',
      '№ наказу та дата призначення на посаду',
    ),
    PersonnelExportColumn(
      'rankOrder',
      '№ наказу та дата присвоєння останнього військового звання',
    ),
    PersonnelExportColumn('birthDate', 'Дата народження'),
    PersonnelExportColumn('education', 'Освіта (перепідготовка)'),
    PersonnelExportColumn(
      'onlineCourses',
      'Проходження онлайн курсів, тематика, дата та № сертифікату',
    ),
    PersonnelExportColumn(
      'service',
      'Дія контракту (дата призову за мобілізацією)',
    ),
    PersonnelExportColumn(
      'relocationReady',
      'Готовність до переїзду до іншого гарнізону',
    ),
    PersonnelExportColumn('family', 'Сімейний стан'),
    PersonnelExportColumn(
      'housing',
      'Забезпеченість житлом, домашня адреса, контактний телефон',
    ),
    PersonnelExportColumn('currentStatus', 'Місце перебування на даний момент'),
    PersonnelExportColumn('rating', 'Рейтинг'),
    PersonnelExportColumn('awards', 'Державні та відомчі нагороди'),
    PersonnelExportColumn('combatParticipation', 'Безпосередня участь в діях'),
    PersonnelExportColumn('wounds', 'Поранення'),
    PersonnelExportColumn('languages', 'Іноземні мови'),
  ];
}
