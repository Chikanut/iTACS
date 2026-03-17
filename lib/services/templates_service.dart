// lib/services/group_templates_service.dart - Фінальна версія з підколекціями

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'dart:async';
import '../globals.dart';

// Енум для типів темплейтів
enum TemplateType {
  lesson('lesson', 'Заняття', '📚'),
  event('event', 'Подія', '🎯'),
  meeting('meeting', 'Нарада', '👥'),
  inspection('inspection', 'Перевірка', '🔍'),
  training('training', 'Тренування', '💪'),
  ceremony('ceremony', 'Церемонія', '🎖️'),
  maintenance('maintenance', 'Обслуговування', '🔧'),
  other('other', 'Інше', '📋');

  const TemplateType(this.id, this.displayName, this.emoji);

  final String id;
  final String displayName;
  final String emoji;

  static TemplateType fromId(String id) {
    return TemplateType.values.firstWhere(
      (type) => type.id == id,
      orElse: () => TemplateType.other,
    );
  }
}

class GroupTemplate {
  final String id;
  final String title;
  final String description;
  final String location;
  final String unit;
  final List<String> tags;
  final int durationMinutes;
  final TemplateType type;
  final bool isDefault;
  final String groupId;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic> customFields;

  GroupTemplate({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.unit,
    required this.tags,
    required this.durationMinutes,
    required this.type,
    this.isDefault = false,
    required this.groupId,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.customFields = const {},
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'location': location,
    'unit': unit,
    'tags': tags,
    'durationMinutes': durationMinutes,
    'type': type.id,
    'isDefault': isDefault,
    'groupId': groupId,
    'createdBy': createdBy,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'customFields': customFields,
  };

  Map<String, dynamic> toFirestore() => {
    'title': title,
    'description': description,
    'location': location,
    'unit': unit,
    'tags': tags,
    'durationMinutes': durationMinutes,
    'type': type.id,
    'isDefault': isDefault,
    'groupId': groupId,
    'createdBy': createdBy,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
    'customFields': customFields,
  };

  factory GroupTemplate.fromJson(Map<String, dynamic> json) => GroupTemplate(
    id: json['id'] ?? '',
    title: json['title'] ?? '',
    description: json['description'] ?? '',
    location: json['location'] ?? '',
    unit: json['unit'] ?? '',
    tags: List<String>.from(json['tags'] ?? []),
    durationMinutes: json['durationMinutes'] ?? 90,
    type: TemplateType.fromId(json['type'] ?? 'other'),
    isDefault: json['isDefault'] ?? false,
    groupId: json['groupId'] ?? '',
    createdBy: json['createdBy'] ?? '',
    createdAt: json['createdAt'] is String
        ? DateTime.parse(json['createdAt'])
        : DateTime.now(),
    updatedAt: json['updatedAt'] is String
        ? DateTime.parse(json['updatedAt'])
        : DateTime.now(),
    customFields: Map<String, dynamic>.from(json['customFields'] ?? {}),
  );

  factory GroupTemplate.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GroupTemplate(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      location: data['location'] ?? '',
      unit: data['unit'] ?? '',
      tags: List<String>.from(data['tags'] ?? []),
      durationMinutes: data['durationMinutes'] ?? 90,
      type: TemplateType.fromId(data['type'] ?? 'other'),
      isDefault: data['isDefault'] ?? false,
      groupId: data['groupId'] ?? '',
      createdBy: data['createdBy'] ?? '',
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] is Timestamp
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
      customFields: Map<String, dynamic>.from(data['customFields'] ?? {}),
    );
  }

  GroupTemplate copyWith({
    String? title,
    String? description,
    String? location,
    String? unit,
    List<String>? tags,
    int? durationMinutes,
    TemplateType? type,
    bool? isDefault,
    Map<String, dynamic>? customFields,
  }) => GroupTemplate(
    id: id,
    title: title ?? this.title,
    description: description ?? this.description,
    location: location ?? this.location,
    unit: unit ?? this.unit,
    tags: tags ?? this.tags,
    durationMinutes: durationMinutes ?? this.durationMinutes,
    type: type ?? this.type,
    isDefault: isDefault ?? this.isDefault,
    groupId: groupId,
    createdBy: createdBy,
    createdAt: createdAt,
    updatedAt: DateTime.now(),
    customFields: customFields ?? this.customFields,
  );
}

class GroupTemplatesService {
  static final GroupTemplatesService _instance =
      GroupTemplatesService._internal();
  factory GroupTemplatesService() => _instance;
  GroupTemplatesService._internal();

  // Hive boxes
  static const String _templatesBoxName = 'group_templates';
  static const String _autoCompleteBoxName = 'group_autocomplete_data';

  Box<String>? _templatesBox;
  Box<String>? _autoCompleteBox;

  // Кеш для поточної групи
  String? _currentGroupId;
  List<GroupTemplate> _templates = [];
  Set<String> _locations = {};
  Set<String> _units = {};
  Set<String> _allTags = {};

  // Слухач змін в Firestore
  StreamSubscription<QuerySnapshot>? _templatesSubscription;
  StreamSubscription<QuerySnapshot>? _autocompleteSubscription;

  Future<void> initialize() async {
    try {
      await _initializeHive();
      await _initializeForCurrentGroup();
      debugPrint('GroupTemplatesService: Ініціалізовано успішно');
    } catch (e) {
      debugPrint('GroupTemplatesService: Помилка ініціалізації: $e');
    }
  }

  Future<void> _initializeHive() async {
    _templatesBox = await Hive.openBox<String>(_templatesBoxName);
    _autoCompleteBox = await Hive.openBox<String>(_autoCompleteBoxName);
  }

  Future<void> _initializeForCurrentGroup() async {
    final groupId = Globals.profileManager.currentGroupId;
    if (groupId == null) {
      debugPrint('GroupTemplatesService: Немає активної групи');
      return;
    }

    if (_currentGroupId != groupId) {
      await _switchToGroup(groupId);
    }
  }

  Future<void> _switchToGroup(String groupId) async {
    // Очищуємо попередні слухачі
    await _templatesSubscription?.cancel();
    await _autocompleteSubscription?.cancel();

    _currentGroupId = groupId;

    // Завантажуємо з кешу
    await _loadFromCache(groupId);

    // Запускаємо слухачі Firestore
    _startFirestoreListeners(groupId);

    // Завантажуємо з Firestore і оновлюємо кеш
    await _syncWithFirestore(groupId);
  }

  void _startFirestoreListeners(String groupId) {
    // Слухач для темплейтів
    _templatesSubscription = FirebaseFirestore.instance
        .collection('groups')
        .doc(groupId)
        .collection('templates')
        .snapshots()
        .listen((snapshot) {
          try {
            _updateTemplatesFromSnapshot(snapshot);
            _saveToCache(groupId);
          } catch (e) {
            debugPrint('GroupTemplatesService: Помилка слухача темплейтів: $e');
          }
        });

    // Слухач для автодоповнення
    _autocompleteSubscription = FirebaseFirestore.instance
        .collection('groups')
        .doc(groupId)
        .collection('autocomplete_data')
        .snapshots()
        .listen((snapshot) {
          try {
            _updateAutocompleteFromSnapshot(snapshot);
            _saveToCache(groupId);
          } catch (e) {
            debugPrint(
              'GroupTemplatesService: Помилка слухача автодоповнення: $e',
            );
          }
        });
  }

  void _updateTemplatesFromSnapshot(QuerySnapshot snapshot) {
    _templates.clear();

    for (final doc in snapshot.docs) {
      try {
        final template = GroupTemplate.fromFirestore(doc);
        _templates.add(template);
      } catch (e) {
        debugPrint(
          'GroupTemplatesService: Помилка парсингу темплейту ${doc.id}: $e',
        );
      }
    }

    debugPrint(
      'GroupTemplatesService: Оновлено ${_templates.length} темплейтів',
    );
  }

  void _updateAutocompleteFromSnapshot(QuerySnapshot snapshot) {
    _locations.clear();
    _units.clear();
    _allTags.clear();

    for (final doc in snapshot.docs) {
      try {
        final data = doc.data() as Map<String, dynamic>;
        final items = List<String>.from(data['items'] ?? []);

        switch (doc.id) {
          case 'locations':
            _locations.addAll(items);
            break;
          case 'units':
            _units.addAll(items);
            break;
          case 'tags':
            _allTags.addAll(items);
            break;
        }
      } catch (e) {
        debugPrint(
          'GroupTemplatesService: Помилка парсингу автодоповнення ${doc.id}: $e',
        );
      }
    }

    // Також додаємо автодоповнення з темплейтів
    for (final template in _templates) {
      if (template.location.isNotEmpty) _locations.add(template.location);
      if (template.unit.isNotEmpty) _units.add(template.unit);
      _allTags.addAll(template.tags);
    }

    debugPrint(
      'GroupTemplatesService: Оновлено автодоповнення: ${_locations.length} локацій, ${_units.length} підрозділів, ${_allTags.length} тегів',
    );
  }

  Future<void> _syncWithFirestore(String groupId) async {
    try {
      // Завантажуємо темплейти
      final templatesSnapshot = await FirebaseFirestore.instance
          .collection('groups')
          .doc(groupId)
          .collection('templates')
          .get();

      _updateTemplatesFromSnapshot(templatesSnapshot);

      // Завантажуємо автодоповнення
      final autocompleteSnapshot = await FirebaseFirestore.instance
          .collection('groups')
          .doc(groupId)
          .collection('autocomplete_data')
          .get();

      _updateAutocompleteFromSnapshot(autocompleteSnapshot);

      await _saveToCache(groupId);

      // Створюємо дефолтні темплейти якщо їх немає
      if (_templates.isEmpty) {
        await _createDefaultTemplates(groupId);
      }
    } catch (e) {
      debugPrint(
        'GroupTemplatesService: Помилка синхронізації з Firestore: $e',
      );
    }
  }

  Future<void> _createDefaultTemplates(String groupId) async {
    final currentUser = Globals.firebaseAuth.currentUser;
    if (currentUser == null) return;

    final defaultTemplates = _getDefaultTemplatesForGroup(groupId);

    try {
      final batch = FirebaseFirestore.instance.batch();

      for (final template in defaultTemplates) {
        final docRef = FirebaseFirestore.instance
            .collection('groups')
            .doc(groupId)
            .collection('templates')
            .doc();

        batch.set(docRef, template.toFirestore());
      }

      await batch.commit();

      // Також створюємо дефолтні автодоповнення
      await _createDefaultAutocomplete(groupId);

      debugPrint(
        'GroupTemplatesService: Створено ${defaultTemplates.length} дефолтних темплейтів',
      );
    } catch (e) {
      debugPrint(
        'GroupTemplatesService: Помилка створення дефолтних темплейтів: $e',
      );
    }
  }

  Future<void> _createDefaultAutocomplete(String groupId) async {
    try {
      final autocompleteRef = FirebaseFirestore.instance
          .collection('groups')
          .doc(groupId)
          .collection('autocomplete_data');

      final batch = FirebaseFirestore.instance.batch();

      batch.set(autocompleteRef.doc('locations'), {
        'items': _getDefaultLocations(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      batch.set(autocompleteRef.doc('units'), {
        'items': _getDefaultUnits(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      batch.set(autocompleteRef.doc('tags'), {
        'items': _getDefaultTags(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
    } catch (e) {
      debugPrint(
        'GroupTemplatesService: Помилка створення дефолтного автодоповнення: $e',
      );
    }
  }

  List<GroupTemplate> _getDefaultTemplatesForGroup(String groupId) {
    final currentUser = Globals.firebaseAuth.currentUser;
    final now = DateTime.now();

    return [
      GroupTemplate(
        id: '',
        title: 'Т1',
        description:
            'Прийоми психічної саморегуляції. Перша психологічна допомога та самодопомога',
        location: 'Навчальний клас',
        unit: '',
        tags: ['психологія', 'теорія'],
        durationMinutes: 180,
        type: TemplateType.lesson,
        isDefault: true,
        groupId: groupId,
        createdBy: currentUser?.uid ?? 'system',
        createdAt: now,
        updatedAt: now,
      ),
      GroupTemplate(
        id: '',
        title: 'Щоденна планерка',
        description: 'Планування завдань на день, розподіл обов\'язків',
        location: 'Кабінет командира',
        unit: '',
        tags: ['планування', 'нарада'],
        durationMinutes: 30,
        type: TemplateType.meeting,
        isDefault: true,
        groupId: groupId,
        createdBy: currentUser?.uid ?? 'system',
        createdAt: now,
        updatedAt: now,
      ),
      GroupTemplate(
        id: '',
        title: 'Стройова підготовка',
        description:
            'Заняття зі стройової підготовки: строї, повороти, пересування',
        location: 'Плац',
        unit: '',
        tags: ['стройова', 'практика'],
        durationMinutes: 90,
        type: TemplateType.training,
        isDefault: true,
        groupId: groupId,
        createdBy: currentUser?.uid ?? 'system',
        createdAt: now,
        updatedAt: now,
      ),
    ];
  }

  List<String> _getDefaultLocations() => [
    'Навчальний клас №1',
    'Навчальний клас №2',
    'Навчальний клас №3',
    'Актовий зал',
    'Спортивний зал',
    'Плац',
    'Стрілецький тир',
    'Навчальний полігон',
    'Технічний парк',
    'Майстерня',
    'Їдальня',
    'Казарма',
    'Автопарк',
    'Медичний пункт',
    'НТК ПСП',
    'Обкатка танком',
    'Кабінет командира',
  ];

  List<String> _getDefaultUnits() => [
    '1 НБ 1 НР',
    '1 НБ 2 НР',
    '1 НБ 3 НР',
    '1 НБ 4 НР',
    '1 НБ 5 НР',
    '2 НБ 1 НР',
    '2 НБ 2 НР',
    '2 НБ 3 НР',
    '2 НБ 4 НР',
    '2 НБ 5 НР',
    'Граніт-1 1 НР',
    'Граніт-1 2 НР',
    'Граніт-1 3 НР',
    'Граніт-95 1 НР',
    'Граніт-95 2 НР',
    'ШПР',
    '190 НЦ',
  ];

  List<String> _getDefaultTags() => [
    'тактика',
    'фізична',
    'стройова',
    'теорія',
    'практика',
    'технічна',
    'водіння',
    'стрільби',
    'медична',
    'зв\'язок',
    'інженерна',
    'хімзахист',
    'топографія',
    'статути',
    'психологія',
    'бронетехніка',
    'артилерія',
  ];

  // Робота з кешем
  Future<void> _loadFromCache(String groupId) async {
    try {
      final templatesJson = _templatesBox?.get('templates_$groupId');
      if (templatesJson != null) {
        final List<dynamic> templatesList = json.decode(templatesJson);
        _templates = templatesList
            .map((json) => GroupTemplate.fromJson(json))
            .toList();
      }

      final autoCompleteJson = _autoCompleteBox?.get('autocomplete_$groupId');
      if (autoCompleteJson != null) {
        final data = json.decode(autoCompleteJson);
        _locations = Set<String>.from(data['locations'] ?? []);
        _units = Set<String>.from(data['units'] ?? []);
        _allTags = Set<String>.from(data['tags'] ?? []);
      }
    } catch (e) {
      debugPrint('GroupTemplatesService: Помилка завантаження з кешу: $e');
    }
  }

  Future<void> _saveToCache(String groupId) async {
    try {
      final templatesJson = json.encode(
        _templates.map((t) => t.toJson()).toList(),
      );
      await _templatesBox?.put('templates_$groupId', templatesJson);

      final autoCompleteData = {
        'locations': _locations.toList(),
        'units': _units.toList(),
        'tags': _allTags.toList(),
      };
      await _autoCompleteBox?.put(
        'autocomplete_$groupId',
        json.encode(autoCompleteData),
      );
    } catch (e) {
      debugPrint('GroupTemplatesService: Помилка збереження в кеш: $e');
    }
  }

  // Публічні методи
  Future<void> ensureInitializedForCurrentGroup() async {
    final groupId = Globals.profileManager.currentGroupId;
    if (groupId != null && _currentGroupId != groupId) {
      await _switchToGroup(groupId);
    }
  }

  List<GroupTemplate> getTemplates([TemplateType? type]) {
    final templates = List<GroupTemplate>.from(_templates);
    if (type != null) {
      return templates.where((t) => t.type == type).toList();
    }
    return templates;
  }

  List<GroupTemplate> getTemplatesByType(TemplateType type) {
    return _templates.where((t) => t.type == type).toList();
  }

  Future<bool> saveTemplate(GroupTemplate template) async {
    try {
      await ensureInitializedForCurrentGroup();

      final currentUser = Globals.firebaseAuth.currentUser;
      if (currentUser == null) {
        throw Exception('Користувач не авторизований');
      }

      final groupId = _currentGroupId;
      if (groupId == null) {
        throw Exception('Немає активної групи');
      }

      final templatesRef = FirebaseFirestore.instance
          .collection('groups')
          .doc(groupId)
          .collection('templates');

      final now = DateTime.now();

      if (template.id.isEmpty) {
        // Створення нового
        final newTemplate = GroupTemplate(
          id: '',
          title: template.title,
          description: template.description,
          location: template.location,
          unit: template.unit,
          tags: template.tags,
          durationMinutes: template.durationMinutes,
          type: template.type,
          isDefault: template.isDefault,
          groupId: groupId,
          createdBy: currentUser.uid,
          createdAt: now,
          updatedAt: now,
          customFields: template.customFields,
        );

        await templatesRef.add(newTemplate.toFirestore());
        _addTemplateValuesToAutocomplete(newTemplate);
      } else {
        // Оновлення існуючого
        final updatedTemplate = template.copyWith();
        await templatesRef
            .doc(template.id)
            .update(updatedTemplate.toFirestore());
        _addTemplateValuesToAutocomplete(updatedTemplate);
      }

      // Оновлюємо автодоповнення
      await _updateAutocompleteData();

      return true;
    } catch (e) {
      debugPrint('GroupTemplatesService: Помилка збереження темплейту: $e');
      return false;
    }
  }

  Future<bool> deleteTemplate(String templateId) async {
    try {
      final groupId = _currentGroupId;
      if (groupId == null) {
        throw Exception('Немає активної групи');
      }

      await FirebaseFirestore.instance
          .collection('groups')
          .doc(groupId)
          .collection('templates')
          .doc(templateId)
          .delete();

      return true;
    } catch (e) {
      debugPrint('GroupTemplatesService: Помилка видалення темплейту: $e');
      return false;
    }
  }

  void _addTemplateValuesToAutocomplete(GroupTemplate template) {
    if (template.location.trim().isNotEmpty) {
      _locations.add(template.location.trim());
    }
    if (template.unit.trim().isNotEmpty) {
      _units.add(template.unit.trim());
    }
    for (final tag in template.tags) {
      final normalizedTag = tag.trim().toLowerCase();
      if (normalizedTag.isNotEmpty) {
        _allTags.add(normalizedTag);
      }
    }
  }

  // Автодоповнення
  List<String> getLocationSuggestions(String query) {
    return _locations
        .where(
          (location) => location.toLowerCase().contains(query.toLowerCase()),
        )
        .take(5)
        .toList();
  }

  List<String> getUnitSuggestions(String query) {
    return _units
        .where((unit) => unit.toLowerCase().contains(query.toLowerCase()))
        .take(5)
        .toList();
  }

  List<String> getTagSuggestions(String query) {
    return _allTags
        .where((tag) => tag.toLowerCase().contains(query.toLowerCase()))
        .take(10)
        .toList();
  }

  Future<void> addLocation(String location) async {
    if (location.trim().isNotEmpty) {
      _locations.add(location.trim());
      await _updateAutocompleteData();
    }
  }

  Future<void> addUnit(String unit) async {
    if (unit.trim().isNotEmpty) {
      _units.add(unit.trim());
      await _updateAutocompleteData();
    }
  }

  Future<void> addTag(String tag) async {
    if (tag.trim().isNotEmpty) {
      _allTags.add(tag.trim().toLowerCase());
      await _updateAutocompleteData();
    }
  }

  Future<void> removeLocation(String location) async {
    _locations.remove(location.trim());
    await _updateAutocompleteData();
  }

  Future<void> removeUnit(String unit) async {
    _units.remove(unit.trim());
    await _updateAutocompleteData();
  }

  Future<void> removeTag(String tag) async {
    _allTags.remove(tag.trim().toLowerCase());
    await _updateAutocompleteData();
  }

  Future<void> _updateAutocompleteData() async {
    try {
      final groupId = _currentGroupId;
      if (groupId == null) return;

      final autocompleteRef = FirebaseFirestore.instance
          .collection('groups')
          .doc(groupId)
          .collection('autocomplete_data');

      final batch = FirebaseFirestore.instance.batch();

      batch.set(autocompleteRef.doc('locations'), {
        'items': _locations.toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      batch.set(autocompleteRef.doc('units'), {
        'items': _units.toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      batch.set(autocompleteRef.doc('tags'), {
        'items': _allTags.toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
    } catch (e) {
      debugPrint('GroupTemplatesService: Помилка оновлення автодоповнення: $e');
    }
  }

  // Методи для створення об'єктів з темплейтів
  Map<String, dynamic> createEventFromTemplate(GroupTemplate template) {
    return {
      'title': template.title,
      'description': template.description,
      'location': template.location,
      'unit': template.unit,
      'tags': List.from(template.tags),
      'durationMinutes': template.durationMinutes,
      'type': template.type.id,
      'customFields': Map.from(template.customFields),
    };
  }

  // Для зворотної сумісності з LessonModel
  Map<String, dynamic> createLessonFromTemplate(GroupTemplate template) {
    if (template.type != TemplateType.lesson) {
      debugPrint(
        'GroupTemplatesService: Використання не-урочного темплейту для створення уроку',
      );
    }
    return createEventFromTemplate(template);
  }

  // Очищення даних
  Future<void> clearAllData() async {
    try {
      await _templatesSubscription?.cancel();
      await _autocompleteSubscription?.cancel();

      _templates.clear();
      _locations.clear();
      _units.clear();
      _allTags.clear();

      await _templatesBox?.clear();
      await _autoCompleteBox?.clear();

      _currentGroupId = null;
    } catch (e) {
      debugPrint('GroupTemplatesService: Помилка очищення даних: $e');
    }
  }

  // Закриття сервісу
  Future<void> dispose() async {
    await _templatesSubscription?.cancel();
    await _autocompleteSubscription?.cancel();
    await _templatesBox?.close();
    await _autoCompleteBox?.close();
  }

  // Геттери для статистики
  int get templatesCount => _templates.length;
  int get locationsCount => _locations.length;
  int get unitsCount => _units.length;
  int get tagsCount => _allTags.length;
  List<String> get allLocations => _locations.toList()..sort();
  List<String> get allUnits => _units.toList()..sort();
  List<String> get allTags => _allTags.toList()..sort();

  Map<TemplateType, int> get templatesByType {
    final Map<TemplateType, int> counts = {};
    for (final template in _templates) {
      counts[template.type] = (counts[template.type] ?? 0) + 1;
    }
    return counts;
  }

  String? get currentGroupId => _currentGroupId;
}
