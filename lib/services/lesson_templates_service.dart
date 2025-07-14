// lib/services/lesson_templates_service.dart

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:convert';

class LessonTemplate {
  final String id;
  final String title;
  final String description;
  final String location;
  final String unit;
  final List<String> tags;
  final int durationMinutes;
  final bool isDefault;

  LessonTemplate({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.unit,
    required this.tags,
    required this.durationMinutes,
    this.isDefault = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'location': location,
    'unit': unit,
    'tags': tags,
    'durationMinutes': durationMinutes,
    'isDefault': isDefault,
  };

  factory LessonTemplate.fromJson(Map<String, dynamic> json) => LessonTemplate(
    id: json['id'] ?? '',
    title: json['title'] ?? '',
    description: json['description'] ?? '',
    location: json['location'] ?? '',
    unit: json['unit'] ?? '',
    tags: List<String>.from(json['tags'] ?? []),
    durationMinutes: json['durationMinutes'] ?? 90,
    isDefault: json['isDefault'] ?? false,
  );
}

class LessonTemplatesService {
  static final LessonTemplatesService _instance = LessonTemplatesService._internal();
  factory LessonTemplatesService() => _instance;
  LessonTemplatesService._internal();

  // Hive boxes
  static const String _templatesBoxName = 'lesson_templates';
  static const String _autoCompleteBoxName = 'autocomplete_data';
  
  Box<String>? _templatesBox;
  Box<List<String>>? _autoCompleteBox;

  List<LessonTemplate> _templates = [];
  Set<String> _instructors = {};
  Set<String> _locations = {};
  Set<String> _units = {};
  Set<String> _allTags = {};

  // Дефолтні шаблони занять
  final List<LessonTemplate> _defaultTemplates = [
    LessonTemplate(
      id: 'tactical_theory',
      title: 'Тактична підготовка (теорія)',
      description: 'Вивчення основ тактики піхотного підрозділу',
      location: 'Навчальний клас',
      unit: '',
      tags: ['тактика', 'теорія'],
      durationMinutes: 90,
      isDefault: true,
    ),
    LessonTemplate(
      id: 'tactical_practice',
      title: 'Тактична підготовка (практика)',
      description: 'Відпрацювання тактичних прийомів на місцевості',
      location: 'Навчальний полігон',
      unit: '',
      tags: ['тактика', 'практика'],
      durationMinutes: 180,
      isDefault: true,
    ),
    LessonTemplate(
      id: 'physical_training',
      title: 'Фізична підготовка',
      description: 'Загальна фізична підготовка військовослужбовців',
      location: 'Спортивний зал',
      unit: '',
      tags: ['фізична', 'практика'],
      durationMinutes: 90,
      isDefault: true,
    ),
    LessonTemplate(
      id: 'drill_training',
      title: 'Стройова підготовка',
      description: 'Відпрацювання стройових прийомів та рухів',
      location: 'Плац',
      unit: '',
      tags: ['стройова', 'практика'],
      durationMinutes: 60,
      isDefault: true,
    ),
    LessonTemplate(
      id: 'shooting_theory',
      title: 'Вогнева підготовка (теорія)',
      description: 'Основи стрільби та поводження зі зброєю',
      location: 'Навчальний клас',
      unit: '',
      tags: ['стрільби', 'теорія'],
      durationMinutes: 90,
      isDefault: true,
    ),
    LessonTemplate(
      id: 'shooting_practice',
      title: 'Вогнева підготовка (практика)',
      description: 'Практичні стрільби на полігоні',
      location: 'Стрілецький тир',
      unit: '',
      tags: ['стрільби', 'практика'],
      durationMinutes: 120,
      isDefault: true,
    ),
    LessonTemplate(
      id: 'technical_training',
      title: 'Технічна підготовка',
      description: 'Вивчення та обслуговування техніки',
      location: 'Технічний парк',
      unit: '',
      tags: ['технічна', 'практика'],
      durationMinutes: 120,
      isDefault: true,
    ),
  ];

  // Дефолтні списки для автодоповнення
  final Set<String> _defaultInstructors = {
    'Не призначено',
  };

  final Set<String> _defaultLocations = {
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
  };

  final Set<String> _defaultUnits = {
    '1-й батальйон',
    '2-й батальйон',
    '3-й батальйон',
    '1-а рота',
    '2-а рота',
    '3-я рота',
    '4-а рота',
    '5-а рота',
    '6-а рота',
    'Штабна рота',
    'Розвідувальна рота',
    'Саперна рота',
    'Рота зв\'язку',
    'Медична рота',
  };

  final Set<String> _defaultTags = {
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
  };

  Future<void> initialize() async {
    try {
      // Відкриваємо Hive boxes
      _templatesBox = await Hive.openBox<String>(_templatesBoxName);
      _autoCompleteBox = await Hive.openBox<List<String>>(_autoCompleteBoxName);
      
      await _loadTemplates();
      await _loadAutocompleteLists();
      _addDefaultData();
      
      debugPrint('LessonTemplatesService: Ініціалізовано успішно');
    } catch (e) {
      debugPrint('LessonTemplatesService: Помилка ініціалізації: $e');
    }
  }

  // Методи для роботи з шаблонами
  List<LessonTemplate> getTemplates() => List.from(_templates);

  Future<void> saveTemplate(LessonTemplate template) async {
    try {
      final existingIndex = _templates.indexWhere((t) => t.id == template.id);
      if (existingIndex >= 0) {
        _templates[existingIndex] = template;
      } else {
        _templates.add(template);
      }
      await _saveTemplates();
    } catch (e) {
      debugPrint('LessonTemplatesService: Помилка збереження шаблону: $e');
    }
  }

  Future<void> deleteTemplate(String templateId) async {
    try {
      _templates.removeWhere((template) => template.id == templateId);
      await _saveTemplates();
    } catch (e) {
      debugPrint('LessonTemplatesService: Помилка видалення шаблону: $e');
    }
  }

  // Методи для автодоповнення
  List<String> getInstructorSuggestions(String query) {
    return _instructors
        .where((instructor) => instructor.toLowerCase().contains(query.toLowerCase()))
        .take(5)
        .toList();
  }

  List<String> getLocationSuggestions(String query) {
    return _locations
        .where((location) => location.toLowerCase().contains(query.toLowerCase()))
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

  // Додавання нових значень до списків автодоповнення
  Future<void> addInstructor(String instructor) async {
    if (instructor.trim().isNotEmpty) {
      _instructors.add(instructor.trim());
      await _saveAutocompleteLists();
    }
  }

  Future<void> addLocation(String location) async {
    if (location.trim().isNotEmpty) {
      _locations.add(location.trim());
      await _saveAutocompleteLists();
    }
  }

  Future<void> addUnit(String unit) async {
    if (unit.trim().isNotEmpty) {
      _units.add(unit.trim());
      await _saveAutocompleteLists();
    }
  }

  Future<void> addTag(String tag) async {
    if (tag.trim().isNotEmpty) {
      _allTags.add(tag.trim().toLowerCase());
      await _saveAutocompleteLists();
    }
  }

  // Приватні методи для збереження/завантаження з Hive
  Future<void> _loadTemplates() async {
    try {
      final templatesJson = _templatesBox?.get('templates');
      if (templatesJson != null) {
        final List<dynamic> templatesList = json.decode(templatesJson);
        _templates = templatesList
            .map((json) => LessonTemplate.fromJson(json))
            .toList();
      }
    } catch (e) {
      debugPrint('LessonTemplatesService: Помилка завантаження шаблонів: $e');
    }
  }

  Future<void> _saveTemplates() async {
    try {
      final templatesJson = json.encode(_templates.map((t) => t.toJson()).toList());
      await _templatesBox?.put('templates', templatesJson);
    } catch (e) {
      debugPrint('LessonTemplatesService: Помилка збереження шаблонів: $e');
    }
  }

  Future<void> _loadAutocompleteLists() async {
    try {
      final instructors = _autoCompleteBox?.get('instructors');
      if (instructors != null) {
        _instructors = Set<String>.from(instructors);
      }
      
      final locations = _autoCompleteBox?.get('locations');
      if (locations != null) {
        _locations = Set<String>.from(locations);
      }
      
      final units = _autoCompleteBox?.get('units');
      if (units != null) {
        _units = Set<String>.from(units);
      }
      
      final tags = _autoCompleteBox?.get('tags');
      if (tags != null) {
        _allTags = Set<String>.from(tags);
      }
    } catch (e) {
      debugPrint('LessonTemplatesService: Помилка завантаження автодоповнення: $e');
    }
  }

  Future<void> _saveAutocompleteLists() async {
    try {
      await _autoCompleteBox?.put('instructors', _instructors.toList());
      await _autoCompleteBox?.put('locations', _locations.toList());
      await _autoCompleteBox?.put('units', _units.toList());
      await _autoCompleteBox?.put('tags', _allTags.toList());
    } catch (e) {
      debugPrint('LessonTemplatesService: Помилка збереження автодоповнення: $e');
    }
  }

  void _addDefaultData() {
    // Додаємо дефолтні шаблони якщо їх немає
    if (_templates.isEmpty) {
      _templates.addAll(_defaultTemplates);
      _saveTemplates();
    }

    // Додаємо дефолтні списки
    _instructors.addAll(_defaultInstructors);
    _locations.addAll(_defaultLocations);
    _units.addAll(_defaultUnits);
    _allTags.addAll(_defaultTags);
  }

  // Метод для створення заняття з шаблону
  Map<String, dynamic> createLessonFromTemplate(LessonTemplate template) {
    return {
      'title': template.title,
      'description': template.description,
      'location': template.location,
      'unit': template.unit,
      'tags': List.from(template.tags),
      'durationMinutes': template.durationMinutes,
    };
  }

  // Очищення даних (для тестування)
  Future<void> clearAllData() async {
    try {
      _templates.clear();
      _instructors.clear();
      _locations.clear();
      _units.clear();
      _allTags.clear();
      
      await _templatesBox?.clear();
      await _autoCompleteBox?.clear();
      
      _addDefaultData();
    } catch (e) {
      debugPrint('LessonTemplatesService: Помилка очищення даних: $e');
    }
  }

  // Закриття boxes при завершенні роботи
  Future<void> dispose() async {
    await _templatesBox?.close();
    await _autoCompleteBox?.close();
  }
}