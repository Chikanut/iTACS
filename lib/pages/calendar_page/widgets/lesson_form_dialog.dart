// lib/pages/calendar_page/widgets/lesson_form_dialog.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../models/custom_field_model.dart';
import '../../../models/lesson_model.dart';
import '../../../models/lesson_progress_reminder.dart';
import '../../../services/calendar_service.dart';
import '../calendar_utils.dart';
import '../../../globals.dart';
import '../../../services/templates_service.dart';
import '../../../widgets/custom_fields_dialogs.dart';
import '../../../widgets/lesson_progress_reminder_editor.dart';
import 'autocomplete_field.dart';

class LessonFormDialog extends StatefulWidget {
  final LessonModel? lesson; // null для створення нового
  final DateTime? initialDate;
  final TimeOfDay? initialStartTime;
  final Map<String, dynamic>? templateData;
  final VoidCallback? onSaved;

  const LessonFormDialog({
    super.key,
    this.lesson,
    this.initialDate,
    this.initialStartTime,
    this.templateData,
    this.onSaved,
  });

  @override
  State<LessonFormDialog> createState() => _LessonFormDialogState();
}

class _LessonFormDialogState extends State<LessonFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final CalendarService _calendarService = CalendarService();

  // В клас _LessonFormDialogState додати:
  final GroupTemplatesService _templatesService = GroupTemplatesService();
  List<GroupTemplate> _availableTemplates = [];
  List<Map<String, dynamic>> _availableInstructors = [];

  // Контролери для текстових полів
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _locationController;
  late final TextEditingController _unitController;
  late final TextEditingController _maxParticipantsController;
  late final TextEditingController _tagsController;

  // Дані форми
  DateTime _selectedDate = CalendarUtils.startOfDay(DateTime.now());
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 15);
  TimeOfDay _endTime = const TimeOfDay(hour: 11, minute: 45);
  String _selectedTemplateId = '';
  String _selectedTypeId = '';
  List<String> _selectedTags = [];
  List<LessonCustomFieldDefinition> _customFieldDefinitions = [];
  Map<String, LessonCustomFieldValue> _customFieldValues = {};
  List<LessonProgressReminder> _progressReminders = [];
  bool _isLoading = false;

  // Повторювані заняття
  bool _isRecurring = false;
  String _recurrenceType = 'weekly';
  int _recurrenceInterval = 1;
  DateTime? _recurrenceEndDate;

  // Валідація часу
  String? _timeValidationError;
  bool _isLoadingInstructors = false;
  final Map<String, String> _selectedInstructors = {};

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadInitialData();
    _loadTemplates();
    _loadAssignableInstructors();
  }

  Future<void> _loadTemplates() async {
    _availableTemplates = _templatesService.getTemplates(TemplateType.lesson);
    setState(() {});
  }

  void _initializeControllers() {
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
    _locationController = TextEditingController();
    _unitController = TextEditingController();
    _maxParticipantsController = TextEditingController(text: '180');
    _tagsController = TextEditingController();
  }

  void _loadInitialData() {
    if (widget.lesson != null) {
      // Редагування існуючого заняття
      final lesson = widget.lesson!;
      _titleController.text = lesson.title;
      _descriptionController.text = lesson.description;
      _locationController.text = lesson.location;
      _unitController.text = lesson.unit;
      _maxParticipantsController.text = lesson.maxParticipants.toString();
      _selectedDate = lesson.startTime;
      _startTime = TimeOfDay.fromDateTime(lesson.startTime);
      _endTime = TimeOfDay.fromDateTime(lesson.endTime);
      _selectedTemplateId = lesson.templateId;
      _selectedTypeId = lesson.typeId;
      _selectedTags = List.from(lesson.tags);
      _tagsController.text = _selectedTags.join(', ');
      _customFieldDefinitions = List<LessonCustomFieldDefinition>.from(
        lesson.customFieldDefinitions,
      );
      _customFieldValues = Map<String, LessonCustomFieldValue>.from(
        lesson.customFieldValues,
      );
      _progressReminders = List<LessonProgressReminder>.from(
        lesson.progressReminders,
      );
      _selectedInstructors
        ..clear()
        ..addAll(
          _pairInstructors(lesson.instructorIds, lesson.instructorNames),
        );

      if (lesson.recurrence != null) {
        _isRecurring = true;
        _recurrenceType = lesson.recurrence!.type;
        _recurrenceInterval = lesson.recurrence!.interval;
        _recurrenceEndDate = lesson.recurrence!.endDate;
      }
    } else {
      // Створення нового заняття
      if (widget.initialDate != null) {
        _selectedDate = CalendarUtils.startOfDay(widget.initialDate!);
      }
      if (widget.initialStartTime != null) {
        _startTime = widget.initialStartTime!;
        _endTime = TimeOfDay(
          hour: (_startTime.hour + 1) % 24,
          minute: _startTime.minute,
        );
      }

      // 👈 ДОДАТИ: Якщо є templateData, заповнюємо поля
      if (widget.templateData != null) {
        final template = widget.templateData!;
        _titleController.text = template['title'] ?? '';
        _descriptionController.text = template['description'] ?? '';
        _locationController.text = template['location'] ?? '';
        _unitController.text = template['unit'] ?? '';
        _selectedTemplateId = (template['templateId'] ?? '').toString().trim();
        _selectedTypeId = (template['type'] ?? '').toString().trim();
        _selectedTags = List<String>.from(template['tags'] ?? []);
        _tagsController.text = _selectedTags.join(', ');
        _customFieldDefinitions = LessonCustomFieldDefinition.parseDefinitions(
          template['customFieldDefinitions'] ?? template['customFields'],
        );
        _customFieldValues = LessonCustomFieldValue.sanitizeValues(
          definitions: _customFieldDefinitions,
          values: LessonCustomFieldValue.parseValues(
            template['customFieldValues'],
          ),
        );
        _progressReminders = LessonProgressReminder.parseList(
          template['progressReminders'],
        );
        _selectedInstructors
          ..clear()
          ..addAll(
            _pairInstructors(
              List<String>.from(template['instructorIds'] ?? const []),
              List<String>.from(template['instructorNames'] ?? const []),
              fallbackId: template['instructorId'] ?? '',
              fallbackName: template['instructorName'] ?? '',
            ),
          );

        if (template['durationMinutes'] != null) {
          final duration = template['durationMinutes'] as int;
          final endMinutes =
              (_startTime.hour * 60 + _startTime.minute + duration) % (24 * 60);
          _endTime = TimeOfDay(hour: endMinutes ~/ 60, minute: endMinutes % 60);
        }
      }

      _loadUserDefaults();
    }

    _validateTime();
  }

  Future<void> _loadAssignableInstructors() async {
    if (!_canAssignInstructor()) return;

    final currentGroupId = Globals.profileManager.currentGroupId;
    if (currentGroupId == null) return;

    if (mounted) {
      setState(() => _isLoadingInstructors = true);
    }

    final instructors = await Globals.firestoreManager
        .getGroupMembersWithDetails(currentGroupId);

    if (!mounted) return;
    setState(() {
      _availableInstructors = instructors;
      _isLoadingInstructors = false;
      for (final member in instructors) {
        final assignmentId = _memberAssignmentId(member);
        if (_selectedInstructors.containsKey(assignmentId)) {
          _selectedInstructors[assignmentId] = _memberDisplayName(member);
        }
      }
    });
  }

  void _loadUserDefaults() {
    final currentGroup = Globals.profileManager.currentGroupName;
    if (currentGroup != null && _unitController.text.trim().isEmpty) {
      _unitController.text = currentGroup;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _unitController.dispose();
    _maxParticipantsController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.lesson != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          children: [
            // Шапка
            _buildHeader(isEditing),

            // Контент форми
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildBasicInfoSection(),
                      const SizedBox(height: 20),
                      _buildTimeSection(),
                      const SizedBox(height: 20),
                      _buildProgressRemindersSection(),
                      const SizedBox(height: 20),
                      _buildDetailsSection(),
                      const SizedBox(height: 20),
                      _buildCustomFieldsSection(),
                      const SizedBox(height: 20),
                      _buildRecurrenceSection(),
                      const SizedBox(height: 20),
                      _buildTagsSection(),
                    ],
                  ),
                ),
              ),
            ),

            // Кнопки дій
            _buildActionButtons(isEditing),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isEditing) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Icon(
            isEditing ? Icons.edit : Icons.add,
            color: Theme.of(context).primaryColor,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isEditing ? 'Редагувати заняття' : 'Створити заняття',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Основна інформація',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        // Назва заняття
        TextFormField(
          controller: _titleController,
          decoration: const InputDecoration(
            labelText: 'Назва заняття *',
            hintText: 'Тактична підготовка',
            prefixIcon: Icon(Icons.title),
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Назва заняття обов\'язкова';
            }
            if (value.trim().length < 2) {
              return 'Назва повинна містити мінімум 2 символи';
            }
            return null;
          },
          textCapitalization: TextCapitalization.sentences,
        ),
        if (_availableTemplates.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text(
            'Шаблони занять:',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: _availableTemplates
                .map(
                  (template) => ActionChip(
                    label: Text(template.title),
                    onPressed: () => _applyTemplate(template),
                    backgroundColor: Theme.of(
                      context,
                    ).primaryColor.withOpacity(0.1),
                  ),
                )
                .toList(),
          ),
        ],

        const SizedBox(height: 16),

        // Опис
        TextFormField(
          controller: _descriptionController,
          decoration: const InputDecoration(
            labelText: 'Опис заняття',
            hintText: 'Детальний опис програми заняття...',
            prefixIcon: Icon(Icons.description),
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
        ),
      ],
    );
  }

  void _applyTemplate(GroupTemplate template) {
    _titleController.text = template.title;
    _descriptionController.text = template.description;
    _locationController.text = template.location;
    _unitController.text = template.unit;
    _selectedTemplateId = template.id;
    _selectedTypeId = template.type.id;
    _selectedTags = List.from(template.tags);
    _tagsController.text = _selectedTags.join(', ');
    _customFieldDefinitions = List<LessonCustomFieldDefinition>.from(
      template.customFieldDefinitions,
    );
    _customFieldValues = LessonCustomFieldValue.retainCompatibleValues(
      definitions: _customFieldDefinitions,
      currentValues: _customFieldValues,
    );
    _progressReminders = List<LessonProgressReminder>.from(
      template.progressReminders,
    );

    // Встановлюємо тривалість
    final endMinutes =
        (_startTime.hour * 60 + _startTime.minute + template.durationMinutes) %
        (24 * 60);
    _endTime = TimeOfDay(hour: endMinutes ~/ 60, minute: endMinutes % 60);

    setState(() {});
    _validateTime();
  }

  Widget _buildTimeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Час та дата',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        // Дата
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: _selectDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Дата проведення *',
                    prefixIcon: Icon(Icons.calendar_today),
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    DateFormat('dd.MM.yyyy, EEEE', 'uk').format(_selectedDate),
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Час початку та закінчення
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => _selectTime(true),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Час початку *',
                    prefixIcon: Icon(Icons.schedule),
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    CalendarUtils.formatTime(_startTime),
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: InkWell(
                onTap: () => _selectTime(false),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Час закінчення *',
                    prefixIcon: Icon(Icons.schedule_outlined),
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    CalendarUtils.formatTime(_endTime),
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ),
          ],
        ),

        // Помилка валідації часу
        if (_timeValidationError != null) ...[
          const SizedBox(height: 8),
          Text(
            _timeValidationError!,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildProgressRemindersSection() {
    return LessonProgressReminderEditor(
      reminders: _progressReminders,
      onChanged: (reminders) {
        setState(() {
          _progressReminders = reminders;
        });
      },
      previewStartTime: _selectedStartDateTime,
      previewEndTime: _selectedEndDateTime,
      durationMinutes: _selectedEndDateTime
          .difference(_selectedStartDateTime)
          .inMinutes,
      emptyText:
          'Додайте нагадування, які мають приходити викладачам у певні моменти заняття.',
    );
  }

  Widget _buildDetailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Деталі заняття',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),

        // Місце проведення
        AutocompleteField(
          controller: _locationController,
          labelText: 'Місце проведення *',
          hintText: 'Навчальний клас №1',
          prefixIcon: Icons.location_on,
          getSuggestions: (query) =>
              _templatesService.getLocationSuggestions(query),
          onNewValue: (value) => _templatesService.addLocation(value),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Місце проведення обов\'язкове';
            }
            return null;
          },
          textCapitalization: TextCapitalization.sentences,
        ),

        const SizedBox(height: 16),

        // Підрозділ
        AutocompleteField(
          controller: _unitController,
          labelText: 'Підрозділ',
          hintText: '1-й батальйон',
          prefixIcon: Icons.military_tech,
          getSuggestions: (query) =>
              _templatesService.getUnitSuggestions(query),
          onNewValue: (value) => _templatesService.addUnit(value),
          textCapitalization: TextCapitalization.sentences,
        ),

        const SizedBox(height: 16),

        if (_canAssignInstructor()) ...[
          _buildInstructorSection(),
          const SizedBox(height: 16),
        ],

        // Максимальна кількість учасників
        TextFormField(
          controller: _maxParticipantsController,
          decoration: const InputDecoration(
            labelText: 'Очікувана кількість учнів', // 👈 змінити назву
            hintText: '180',
            prefixIcon: Icon(Icons.group),
            border: OutlineInputBorder(),
            suffixText: 'осіб',
            helperText: 'Для планування та орієнтиру', // 👈 додати пояснення
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(3),
          ],
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Вкажіть очікувану кількість учнів';
            }
            final number = int.tryParse(value);
            if (number == null || number < 1) {
              return 'Мінімум 1 учень';
            }
            if (number > 999) {
              return 'Максимум 999 учнів';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildCustomFieldsSection() {
    final canManageDefinitions = _canManageCustomFieldDefinitions();
    final canEditValues = _canEditCustomFieldValues();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Кастомні параметри',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            if (canManageDefinitions)
              TextButton.icon(
                onPressed: _addCustomFieldDefinition,
                icon: const Icon(Icons.add),
                label: const Text('Додати параметр'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        CustomFieldReadOnlyList(
          definitions: _customFieldDefinitions,
          values: _customFieldValues,
          emptyText: canManageDefinitions
              ? 'Додайте параметри, які має заповнювати інструктор.'
              : 'Кастомні параметри не налаштовані.',
        ),
        if (_customFieldDefinitions.isNotEmpty) ...[
          const SizedBox(height: 12),
          if (canEditValues)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: OutlinedButton.icon(
                onPressed: _editCustomFieldValues,
                icon: const Icon(Icons.edit_note),
                label: const Text('Заповнити значення'),
              ),
            ),
          if (canManageDefinitions)
            Column(
              children: _customFieldDefinitions.map((definition) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${definition.label} (${definition.code})',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _editCustomFieldDefinition(definition),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        onPressed: () =>
                            _removeCustomFieldDefinition(definition),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ],
    );
  }

  Widget _buildInstructorSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Викладачі',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.people),
            helperText:
                'Адмін може призначити кількох викладачів із поточної групи',
          ),
          child: _isLoadingInstructors
              ? const SizedBox(
                  height: 24,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              : _selectedInstructors.isEmpty
              ? const Text('Не призначено')
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _selectedInstructors.entries
                      .map(
                        (entry) => Chip(
                          label: Text(entry.value),
                          onDeleted: () {
                            setState(() {
                              _selectedInstructors.remove(entry.key);
                            });
                          },
                        ),
                      )
                      .toList(),
                ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _isLoadingInstructors ? null : _showInstructorPicker,
              icon: const Icon(Icons.people_alt_outlined, size: 18),
              label: Text(
                _selectedInstructors.isEmpty
                    ? 'Обрати викладачів'
                    : 'Змінити список',
              ),
            ),
            if (_selectedInstructors.isNotEmpty)
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedInstructors.clear();
                  });
                },
                child: const Text('Очистити'),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecurrenceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Повторювані заняття',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            Switch(
              value: _isRecurring,
              onChanged: (value) {
                setState(() {
                  _isRecurring = value;
                  if (!value) {
                    _recurrenceEndDate = null;
                  }
                });
              },
            ),
          ],
        ),

        if (_isRecurring) ...[
          const SizedBox(height: 12),

          // Тип повторення
          DropdownButtonFormField<String>(
            value: _recurrenceType,
            decoration: const InputDecoration(
              labelText: 'Тип повторення',
              prefixIcon: Icon(Icons.repeat),
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'daily', child: Text('Щодня')),
              DropdownMenuItem(value: 'weekly', child: Text('Щотижня')),
              DropdownMenuItem(value: 'monthly', child: Text('Щомісяця')),
            ],
            onChanged: (value) {
              setState(() {
                _recurrenceType = value!;
              });
            },
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              // Інтервал повторення
              Expanded(
                child: TextFormField(
                  initialValue: _recurrenceInterval.toString(),
                  decoration: const InputDecoration(
                    labelText: 'Кожні',
                    border: OutlineInputBorder(),
                    suffixText: 'раз(и)',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(2),
                  ],
                  onChanged: (value) {
                    _recurrenceInterval = int.tryParse(value) ?? 1;
                  },
                ),
              ),
              const SizedBox(width: 16),

              // Дата закінчення повторень
              Expanded(
                flex: 2,
                child: InkWell(
                  onTap: _selectRecurrenceEndDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'До дати',
                      prefixIcon: Icon(Icons.event),
                      border: OutlineInputBorder(),
                    ),
                    child: Text(
                      _recurrenceEndDate != null
                          ? DateFormat('dd.MM.yyyy').format(_recurrenceEndDate!)
                          : 'Оберіть дату',
                      style: TextStyle(
                        fontSize: 16,
                        color: _recurrenceEndDate != null
                            ? null
                            : Theme.of(context).hintColor,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildTagsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Теги та категорії',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        // Поле для введення тегів
        TextFormField(
          controller: _tagsController,
          decoration: const InputDecoration(
            labelText: 'Теги',
            hintText: 'тактика, теорія, практика',
            prefixIcon: Icon(Icons.label),
            border: OutlineInputBorder(),
            helperText: 'Розділяйте теги комами',
          ),
          onChanged: _updateTagsFromText,
          textCapitalization: TextCapitalization.none,
        ),

        const SizedBox(height: 12),

        // Швидкі теги
        const Text(
          'Швидкі теги:',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            'тактика',
            'фізична',
            'стройова',
            'теорія',
            'практика',
            'технічна',
            'водіння',
            'стрільби',
          ].map((tag) => _buildQuickTagChip(tag)).toList(),
        ),

        // Вибрані теги
        if (_selectedTags.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text(
            'Вибрані теги:',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: _selectedTags
                .map(
                  (tag) => Chip(
                    label: Text(tag),
                    backgroundColor: Theme.of(
                      context,
                    ).primaryColor.withOpacity(0.1),
                    onDeleted: () => _removeTag(tag),
                    deleteIcon: const Icon(Icons.close, size: 16),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildQuickTagChip(String tag) {
    final isSelected = _selectedTags.contains(tag);

    return FilterChip(
      label: Text(tag),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          _addTag(tag);
        } else {
          _removeTag(tag);
        }
      },
      backgroundColor: Colors.grey.shade100,
      selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
    );
  }

  Widget _buildActionButtons(bool isEditing) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
              child: const Text('Скасувати'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isLoading || _timeValidationError != null
                  ? null
                  : _saveLesson,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(isEditing ? 'Зберегти зміни' : 'Створити заняття'),
            ),
          ),
        ],
      ),
    );
  }

  // Методи для роботи з датою та часом
  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('uk', 'UA'),
    );

    if (date != null) {
      setState(() {
        _selectedDate = date;
      });
      _validateTime();
    }
  }

  Future<void> _selectTime(bool isStartTime) async {
    final time = await showTimePicker(
      context: context,
      initialTime: isStartTime ? _startTime : _endTime,
    );

    if (time != null) {
      setState(() {
        if (isStartTime) {
          _startTime = time;
          // Автоматично встановлюємо час закінчення на 1.5 години пізніше
          final endMinutes = (time.hour * 60 + time.minute + 90) % (24 * 60);
          _endTime = TimeOfDay(hour: endMinutes ~/ 60, minute: endMinutes % 60);
        } else {
          _endTime = time;
        }
      });
      _validateTime();
    }
  }

  Future<void> _selectRecurrenceEndDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate:
          _recurrenceEndDate ?? _selectedDate.add(const Duration(days: 30)),
      firstDate: _selectedDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('uk', 'UA'),
    );

    if (date != null) {
      setState(() {
        _recurrenceEndDate = date;
      });
    }
  }

  // Методи для роботи з тегами
  void _updateTagsFromText(String text) {
    final tags = text
        .split(',')
        .map((tag) => tag.trim().toLowerCase())
        .where((tag) => tag.isNotEmpty)
        .toSet()
        .toList();

    setState(() {
      _selectedTags = tags;
    });
  }

  void _addTag(String tag) {
    if (!_selectedTags.contains(tag)) {
      setState(() {
        _selectedTags.add(tag);
        _tagsController.text = _selectedTags.join(', ');
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _selectedTags.remove(tag);
      _tagsController.text = _selectedTags.join(', ');
    });
  }

  // Валідація часу
  void _validateTime() {
    setState(() {
      _timeValidationError = CalendarUtils.validateLessonTime(
        _startTime,
        _endTime,
      );
    });
  }

  // Збереження заняття
  Future<void> _saveLesson() async {
    if (!_formKey.currentState!.validate() || _timeValidationError != null) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final startDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _startTime.hour,
        _startTime.minute,
      );

      final endDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _endTime.hour,
        _endTime.minute,
      );

      final currentUser = Globals.firebaseAuth.currentUser;
      final currentGroup =
          Globals.profileManager.currentGroupName ?? 'Невідома група';

      Recurrence? recurrence;
      if (_isRecurring && _recurrenceEndDate != null) {
        recurrence = Recurrence(
          type: _recurrenceType,
          interval: _recurrenceInterval,
          endDate: _recurrenceEndDate!,
        );
      }

      final lesson = LessonModel(
        id: widget.lesson?.id ?? '',
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        startTime: startDateTime,
        endTime: endDateTime,
        groupId: Globals.profileManager.currentGroupId ?? '',
        groupName: currentGroup,
        typeId: _selectedTypeId,
        templateId: _selectedTemplateId,
        unit: _unitController.text.trim(),
        instructorId: _resolvedInstructorIds().isNotEmpty
            ? _resolvedInstructorIds().first
            : '',
        instructorName: _resolvedInstructorNames().isNotEmpty
            ? _resolvedInstructorNames().first
            : '',
        instructorIds: _resolvedInstructorIds(),
        instructorNames: _resolvedInstructorNames(),
        location: _locationController.text.trim(),
        maxParticipants: int.parse(_maxParticipantsController.text),
        participants: widget.lesson?.participants ?? [],
        status: widget.lesson?.status ?? 'scheduled',
        tags: _selectedTags,
        createdBy: widget.lesson?.createdBy ?? currentUser?.uid ?? '',
        createdAt: widget.lesson?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        customFieldDefinitions: _customFieldDefinitions,
        customFieldValues: _customFieldValues,
        progressReminders: _progressReminders,
        recurrence: recurrence,
      );

      bool success;
      if (widget.lesson != null) {
        // Оновлення існуючого заняття
        success = await _calendarService.updateLesson(lesson.id, {
          'title': lesson.title,
          'description': lesson.description,
          'startTime': lesson.startTime,
          'endTime': lesson.endTime,
          'type': lesson.typeId,
          'templateId': lesson.templateId,
          'location': lesson.location,
          'unit': lesson.unit,
          'instructorId': lesson.instructorId,
          'instructorName': lesson.instructorName,
          'instructorIds': lesson.instructorIds,
          'instructorNames': lesson.instructorNames,
          'maxParticipants': lesson.maxParticipants,
          'tags': lesson.tags,
          'customFieldDefinitions': lesson.customFieldDefinitions
              .map((definition) => definition.toFirestore())
              .toList(),
          'customFieldValues': lesson.customFieldValues.map(
            (key, value) => MapEntry(key, value.toFirestore()),
          ),
          'progressReminders': LessonProgressReminder.toFirestoreList(
            lesson.progressReminders,
          ),
          'trainingPeriod': FieldValue.delete(),
          'recurrence': recurrence != null
              ? {
                  'type': recurrence.type,
                  'interval': recurrence.interval,
                  'endDate': recurrence.endDate,
                }
              : null,
        });
      } else {
        // Створення нового заняття
        final lessonId = await _calendarService.createLesson(lesson);
        success = lessonId != null;
      }

      if (success && mounted) {
        widget.onSaved?.call();
        Navigator.of(context).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.lesson != null
                  ? 'Заняття успішно оновлено'
                  : 'Заняття успішно створено',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Помилка збереження: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  bool _canAssignInstructor() {
    return Globals.profileManager.isCurrentGroupEditor;
  }

  bool _canManageCustomFieldDefinitions() {
    final role = Globals.profileManager.currentRole;
    return role == 'admin' || role == 'editor';
  }

  bool _canEditCustomFieldValues() {
    if (_canManageCustomFieldDefinitions()) {
      return true;
    }
    final lesson = widget.lesson;
    return lesson != null && _calendarService.isUserInstructorForLesson(lesson);
  }

  Future<void> _editCustomFieldValues() async {
    final values = await showCustomFieldValuesDialog(
      context,
      title: 'Значення кастомних параметрів',
      definitions: _customFieldDefinitions,
      initialValues: _customFieldValues,
    );
    if (values == null) return;

    setState(() {
      _customFieldValues = values;
    });
  }

  Future<void> _addCustomFieldDefinition() async {
    final definition = await showCustomFieldDefinitionDialog(
      context,
      existingDefinitions: _customFieldDefinitions,
    );
    if (definition == null) return;

    setState(() {
      _customFieldDefinitions = [..._customFieldDefinitions, definition];
      _customFieldValues = LessonCustomFieldValue.retainCompatibleValues(
        definitions: _customFieldDefinitions,
        currentValues: _customFieldValues,
      );
    });
  }

  Future<void> _editCustomFieldDefinition(
    LessonCustomFieldDefinition definition,
  ) async {
    final updatedDefinition = await showCustomFieldDefinitionDialog(
      context,
      initialDefinition: definition,
      existingDefinitions: _customFieldDefinitions,
    );
    if (updatedDefinition == null) return;

    setState(() {
      _customFieldDefinitions = _customFieldDefinitions
          .map(
            (item) => item.code == definition.code ? updatedDefinition : item,
          )
          .toList();

      final nextValues = <String, LessonCustomFieldValue>{};
      for (final entry in _customFieldValues.entries) {
        if (entry.key == definition.code) {
          if (updatedDefinition.type == entry.value.type) {
            nextValues[updatedDefinition.code] = entry.value;
          }
          continue;
        }
        nextValues[entry.key] = entry.value;
      }
      _customFieldValues = LessonCustomFieldValue.retainCompatibleValues(
        definitions: _customFieldDefinitions,
        currentValues: nextValues,
      );
    });
  }

  void _removeCustomFieldDefinition(LessonCustomFieldDefinition definition) {
    setState(() {
      _customFieldDefinitions = _customFieldDefinitions
          .where((item) => item.code != definition.code)
          .toList();
      _customFieldValues = Map<String, LessonCustomFieldValue>.from(
        _customFieldValues,
      )..remove(definition.code);
    });
  }

  List<String> _resolvedInstructorIds() {
    if (_canAssignInstructor()) {
      return _selectedInstructors.keys
          .map(_normalizeInstructorAssignmentId)
          .where((value) => value.isNotEmpty)
          .toList();
    }
    return widget.lesson?.instructorIds ?? const [];
  }

  List<String> _resolvedInstructorNames() {
    if (_canAssignInstructor()) {
      return _selectedInstructors.values
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList();
    }
    return widget.lesson?.instructorNames ?? const [];
  }

  String _memberAssignmentId(Map<String, dynamic> member) {
    final uid = ((member['uid'] as String?) ?? '').trim();
    if (uid.isNotEmpty) {
      return uid;
    }
    return ((member['email'] as String?) ?? '').trim().toLowerCase();
  }

  String _memberDisplayName(Map<String, dynamic> member) {
    final fullName = ((member['fullName'] as String?) ?? '').trim();
    if (fullName.isNotEmpty) {
      return fullName;
    }
    final email = ((member['email'] as String?) ?? '').trim();
    return email.isNotEmpty ? email : 'Без імені';
  }

  String _normalizeInstructorAssignmentId(String instructorId) {
    final normalized = instructorId.trim();
    if (normalized.contains('@')) {
      return normalized.toLowerCase();
    }
    return normalized;
  }

  DateTime get _selectedStartDateTime => DateTime(
    _selectedDate.year,
    _selectedDate.month,
    _selectedDate.day,
    _startTime.hour,
    _startTime.minute,
  );

  DateTime get _selectedEndDateTime => DateTime(
    _selectedDate.year,
    _selectedDate.month,
    _selectedDate.day,
    _endTime.hour,
    _endTime.minute,
  );

  Future<void> _showInstructorPicker() async {
    final availableOptions = _availableInstructorOptions();
    final selectedIds = {..._selectedInstructors.keys};

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Оберіть викладачів'),
              content: SizedBox(
                width: 420,
                child: availableOptions.isEmpty
                    ? const Text('У групі поки немає доступних викладачів.')
                    : SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: availableOptions.entries.map((entry) {
                            return CheckboxListTile(
                              value: selectedIds.contains(entry.key),
                              title: Text(entry.value),
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                              onChanged: (checked) {
                                setStateDialog(() {
                                  if (checked == true) {
                                    selectedIds.add(entry.key);
                                  } else {
                                    selectedIds.remove(entry.key);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Скасувати'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Застосувати'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _selectedInstructors
        ..clear()
        ..addEntries(
          availableOptions.entries.where(
            (entry) => selectedIds.contains(entry.key),
          ),
        );
    });
  }

  Map<String, String> _availableInstructorOptions() {
    final options = <String, String>{};

    for (final entry in _selectedInstructors.entries) {
      options[entry.key] = entry.value;
    }

    for (final member in _availableInstructors) {
      final assignmentId = _memberAssignmentId(member);
      final displayName = _memberDisplayName(member);
      final email = ((member['email'] as String?) ?? '').trim();
      options[assignmentId] = email.isNotEmpty && displayName != email
          ? '$displayName ($email)'
          : displayName;
    }

    return options;
  }

  Map<String, String> _pairInstructors(
    List<String> instructorIds,
    List<String> instructorNames, {
    String fallbackId = '',
    String fallbackName = '',
  }) {
    final paired = <String, String>{};

    for (var i = 0; i < instructorIds.length; i++) {
      final normalizedId = _normalizeInstructorAssignmentId(instructorIds[i]);
      if (normalizedId.isEmpty) continue;
      final name = i < instructorNames.length ? instructorNames[i].trim() : '';
      paired[normalizedId] = name.isNotEmpty ? name : normalizedId;
    }

    final normalizedFallbackId = _normalizeInstructorAssignmentId(fallbackId);
    if (normalizedFallbackId.isNotEmpty &&
        !paired.containsKey(normalizedFallbackId)) {
      paired[normalizedFallbackId] = fallbackName.trim().isNotEmpty
          ? fallbackName.trim()
          : normalizedFallbackId;
    }

    return paired;
  }
}
