// lib/pages/calendar_page/widgets/lesson_form_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../models/lesson_model.dart';
import '../../../services/calendar_service.dart';
import '../calendar_utils.dart';
import '../../../globals.dart';
import '../../../services/templates_service.dart';
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
  late final TextEditingController _trainingPeriodController;

  // Дані форми
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 15);
  TimeOfDay _endTime = const TimeOfDay(hour: 11, minute: 45);
  List<String> _selectedTags = [];
  bool _isLoading = false;

  // Повторювані заняття
  bool _isRecurring = false;
  String _recurrenceType = 'weekly';
  int _recurrenceInterval = 1;
  DateTime? _recurrenceEndDate;

  // Валідація часу
  String? _timeValidationError;
  bool _isLoadingInstructors = false;
  String _selectedInstructorId = '';
  String _selectedInstructorName = '';

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
    _trainingPeriodController = TextEditingController();
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
      _selectedTags = List.from(lesson.tags);
      _tagsController.text = _selectedTags.join(', ');
      _trainingPeriodController.text = lesson.trainingPeriod;
      _selectedInstructorId = lesson.instructorId;
      _selectedInstructorName = lesson.instructorName;

      if (lesson.recurrence != null) {
        _isRecurring = true;
        _recurrenceType = lesson.recurrence!.type;
        _recurrenceInterval = lesson.recurrence!.interval;
        _recurrenceEndDate = lesson.recurrence!.endDate;
      }
    } else {
      // Створення нового заняття
      if (widget.initialDate != null) {
        _selectedDate = widget.initialDate!;
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
        _selectedTags = List<String>.from(template['tags'] ?? []);
        _tagsController.text = _selectedTags.join(', ');
        _selectedInstructorId = template['instructorId'] ?? '';
        _selectedInstructorName = template['instructorName'] ?? '';

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

      if (_selectedInstructorId.isNotEmpty) {
        final selectedMember = instructors
            .cast<Map<String, dynamic>?>()
            .firstWhere(
              (member) =>
                  member != null &&
                  _memberAssignmentId(member) == _selectedInstructorId,
              orElse: () => null,
            );
        if (selectedMember != null) {
          _selectedInstructorName = _memberDisplayName(selectedMember);
        }
      }
    });
  }

  void _loadUserDefaults() {
    final currentGroup = Globals.profileManager.currentGroupName;
    if (currentGroup != null) {
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
    _trainingPeriodController.dispose();
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
                      _buildDetailsSection(),
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
    _selectedTags = List.from(template.tags);
    _tagsController.text = _selectedTags.join(', ');

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

        // Період навчання
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: _trainingPeriodController,
                decoration: const InputDecoration(
                  labelText: 'Період навчання',
                  hintText: '25.06.2025 - 16.07.2025',
                  prefixIcon: Icon(Icons.date_range),
                  border: OutlineInputBorder(),
                  helperText: 'Формат: дд.мм.рррр - дд.мм.рррр',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return null;
                  }

                  if (!LessonStatusUtils.isValidTrainingPeriod(value.trim())) {
                    return 'Некоректний формат. Використовуйте: дд.мм.рррр - дд.мм.рррр';
                  }
                  return null;
                },
                onChanged: (value) {
                  // Автоматичне форматування при введенні
                  if (value.length == 10 && !value.contains(' - ')) {
                    _trainingPeriodController.text = '$value - ';
                    _trainingPeriodController.selection =
                        TextSelection.fromPosition(
                          TextPosition(
                            offset: _trainingPeriodController.text.length,
                          ),
                        );
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _selectTrainingPeriod,
                icon: const Icon(Icons.calendar_today, size: 16),
                label: const Text('Обрати', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

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

  Widget _buildInstructorSection() {
    final hasSelectedInstructor =
        _selectedInstructorId.isNotEmpty &&
        _availableInstructors.any(
          (member) => _memberAssignmentId(member) == _selectedInstructorId,
        );

    return DropdownButtonFormField<String>(
      value: _selectedInstructorId.isNotEmpty
          ? (hasSelectedInstructor ? _selectedInstructorId : '__current__')
          : '',
      decoration: const InputDecoration(
        labelText: 'Викладач',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.person),
        helperText: 'Адмін може призначити будь-кого з поточної групи',
      ),
      items: [
        const DropdownMenuItem<String>(
          value: '',
          child: Text('Не призначати зараз'),
        ),
        if (_selectedInstructorId.isNotEmpty && !hasSelectedInstructor)
          DropdownMenuItem<String>(
            value: '__current__',
            child: Text(
              _selectedInstructorName.isNotEmpty
                  ? '$_selectedInstructorName (поточне призначення)'
                  : 'Поточне призначення',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ..._availableInstructors.map((member) {
          final assignmentId = _memberAssignmentId(member);
          final displayName = _memberDisplayName(member);
          final email = ((member['email'] as String?) ?? '').trim();
          return DropdownMenuItem<String>(
            value: assignmentId,
            child: Text(
              email.isNotEmpty && displayName != email
                  ? '$displayName ($email)'
                  : displayName,
              overflow: TextOverflow.ellipsis,
            ),
          );
        }),
      ],
      onChanged: _isLoadingInstructors
          ? null
          : (value) {
              if (value == '__current__') {
                return;
              }
              final assignmentId = value ?? '';
              final selectedMember = _availableInstructors
                  .cast<Map<String, dynamic>?>()
                  .firstWhere(
                    (member) =>
                        member != null &&
                        _memberAssignmentId(member) == assignmentId,
                    orElse: () => null,
                  );
              setState(() {
                _selectedInstructorId = assignmentId;
                _selectedInstructorName = selectedMember != null
                    ? _memberDisplayName(selectedMember)
                    : '';
              });
            },
    );
  }

  Future<void> _selectTrainingPeriod() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _parseCurrentPeriod(),
      locale: const Locale('uk', 'UA'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: Theme.of(context).primaryColor),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final formattedPeriod = LessonStatusUtils.createTrainingPeriod(
        picked.start,
        picked.end,
      );
      _trainingPeriodController.text = formattedPeriod;
    }
  }

  DateTimeRange? _parseCurrentPeriod() {
    final text = _trainingPeriodController.text;
    final (startDate, endDate) = LessonStatusUtils.parseTrainingPeriod(text);

    if (startDate != null && endDate != null) {
      return DateTimeRange(start: startDate, end: endDate);
    }

    return null;
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
        unit: _unitController.text.trim(),
        instructorId: _resolvedInstructorId(),
        instructorName: _resolvedInstructorName(),
        location: _locationController.text.trim(),
        maxParticipants: int.parse(_maxParticipantsController.text),
        participants: widget.lesson?.participants ?? [],
        status: widget.lesson?.status ?? 'scheduled',
        tags: _selectedTags,
        createdBy: widget.lesson?.createdBy ?? currentUser?.uid ?? '',
        createdAt: widget.lesson?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        recurrence: recurrence,
        trainingPeriod: _trainingPeriodController.text.trim(),
      );

      bool success;
      if (widget.lesson != null) {
        // Оновлення існуючого заняття
        success = await _calendarService.updateLesson(lesson.id, {
          'title': lesson.title,
          'description': lesson.description,
          'startTime': lesson.startTime,
          'endTime': lesson.endTime,
          'location': lesson.location,
          'unit': lesson.unit,
          'instructorId': lesson.instructorId,
          'instructorName': lesson.instructorName,
          'maxParticipants': lesson.maxParticipants,
          'tags': lesson.tags,
          'trainingPeriod': lesson.trainingPeriod,
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
    return Globals.profileManager.currentRole == 'admin';
  }

  String _resolvedInstructorId() {
    if (_canAssignInstructor()) {
      return _normalizeInstructorAssignmentId(_selectedInstructorId);
    }
    return _normalizeInstructorAssignmentId(widget.lesson?.instructorId ?? '');
  }

  String _resolvedInstructorName() {
    if (_canAssignInstructor()) {
      return _selectedInstructorName;
    }
    return widget.lesson?.instructorName ?? '';
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
}
