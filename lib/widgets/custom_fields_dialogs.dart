import 'package:flutter/material.dart';

import '../models/custom_field_model.dart';

Future<LessonCustomFieldDefinition?> showCustomFieldDefinitionDialog(
  BuildContext context, {
  LessonCustomFieldDefinition? initialDefinition,
  List<LessonCustomFieldDefinition> existingDefinitions = const [],
}) {
  return showDialog<LessonCustomFieldDefinition>(
    context: context,
    builder: (context) => _CustomFieldDefinitionDialog(
      initialDefinition: initialDefinition,
      existingDefinitions: existingDefinitions,
    ),
  );
}

Future<Map<String, LessonCustomFieldValue>?> showCustomFieldValuesDialog(
  BuildContext context, {
  required List<LessonCustomFieldDefinition> definitions,
  required Map<String, LessonCustomFieldValue> initialValues,
  String title = 'Кастомні параметри',
}) {
  return showDialog<Map<String, LessonCustomFieldValue>>(
    context: context,
    builder: (context) => _CustomFieldValuesDialog(
      title: title,
      definitions: definitions,
      initialValues: initialValues,
    ),
  );
}

class CustomFieldReadOnlyList extends StatelessWidget {
  final List<LessonCustomFieldDefinition> definitions;
  final Map<String, LessonCustomFieldValue> values;
  final String emptyText;
  final bool showFieldType;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? labelColor;
  final Color? valueColor;
  final Color? emptyValueColor;

  const CustomFieldReadOnlyList({
    super.key,
    required this.definitions,
    required this.values,
    this.emptyText = 'Кастомних параметрів немає',
    this.showFieldType = true,
    this.backgroundColor,
    this.borderColor,
    this.labelColor,
    this.valueColor,
    this.emptyValueColor,
  });

  @override
  Widget build(BuildContext context) {
    if (definitions.isEmpty) {
      return Text(
        emptyText,
        style: TextStyle(color: labelColor ?? Colors.grey.shade700),
      );
    }

    return Column(
      children: definitions.map((definition) {
        final value = values[definition.code];
        final hasValue = value != null && !value.isEmpty;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: backgroundColor,
            border: Border.all(color: borderColor ?? Colors.grey.shade300),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      definition.label,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: labelColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value?.formatDisplayValue() ?? 'Не вказано',
                      style: TextStyle(
                        color: hasValue
                            ? (valueColor ?? Colors.grey.shade800)
                            : (emptyValueColor ??
                                  valueColor ??
                                  Colors.grey.shade600),
                      ),
                    ),
                  ],
                ),
              ),
              if (showFieldType) ...[
                const SizedBox(width: 12),
                Chip(
                  label: Text(definition.type.displayName),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _CustomFieldDefinitionDialog extends StatefulWidget {
  final LessonCustomFieldDefinition? initialDefinition;
  final List<LessonCustomFieldDefinition> existingDefinitions;

  const _CustomFieldDefinitionDialog({
    required this.initialDefinition,
    required this.existingDefinitions,
  });

  @override
  State<_CustomFieldDefinitionDialog> createState() =>
      _CustomFieldDefinitionDialogState();
}

class _CustomFieldDefinitionDialogState
    extends State<_CustomFieldDefinitionDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _labelController;
  late final TextEditingController _codeController;
  late CustomFieldType _selectedType;
  String? _validationError;
  bool _codeTouchedManually = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialDefinition;
    _labelController = TextEditingController(text: initial?.label ?? '');
    _codeController = TextEditingController(
      text:
          initial?.code ??
          LessonCustomFieldDefinition.generateCode(initial?.label ?? ''),
    );
    _selectedType = initial?.type ?? CustomFieldType.string;
  }

  @override
  void dispose() {
    _labelController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.initialDefinition == null
            ? 'Новий параметр'
            : 'Редагувати параметр',
      ),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _labelController,
                decoration: const InputDecoration(
                  labelText: 'Назва *',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  if (_codeTouchedManually) return;
                  final suggestedCode =
                      LessonCustomFieldDefinition.generateCode(value);
                  _codeController.value = TextEditingValue(
                    text: suggestedCode,
                    selection: TextSelection.collapsed(
                      offset: suggestedCode.length,
                    ),
                  );
                },
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Вкажіть назву параметра';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _codeController,
                decoration: const InputDecoration(
                  labelText: 'Code *',
                  helperText: 'Стабільний ключ для звітності та API',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) {
                  _codeTouchedManually = true;
                },
                validator: (value) {
                  final normalized = LessonCustomFieldDefinition.normalizeCode(
                    value ?? '',
                  );
                  if (normalized.isEmpty) {
                    return 'Вкажіть code параметра';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<CustomFieldType>(
                value: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'Тип *',
                  border: OutlineInputBorder(),
                ),
                items: CustomFieldType.values
                    .map(
                      (type) => DropdownMenuItem<CustomFieldType>(
                        value: type,
                        child: Text(type.displayName),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedType = value);
                  }
                },
              ),
              if (_validationError != null) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _validationError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Скасувати'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Зберегти')),
      ],
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final definition = LessonCustomFieldDefinition(
      code: LessonCustomFieldDefinition.normalizeCode(_codeController.text),
      label: _labelController.text.trim(),
      type: _selectedType,
    );
    final siblingDefinitions = widget.existingDefinitions.where((existing) {
      final initial = widget.initialDefinition;
      if (initial == null) return true;
      return existing.code != initial.code;
    }).toList();
    final validationError = LessonCustomFieldDefinition.validateDefinitions([
      ...siblingDefinitions,
      definition,
    ]);

    if (validationError != null) {
      setState(() => _validationError = validationError);
      return;
    }

    Navigator.of(context).pop(definition);
  }
}

class _CustomFieldValuesDialog extends StatefulWidget {
  final String title;
  final List<LessonCustomFieldDefinition> definitions;
  final Map<String, LessonCustomFieldValue> initialValues;

  const _CustomFieldValuesDialog({
    required this.title,
    required this.definitions,
    required this.initialValues,
  });

  @override
  State<_CustomFieldValuesDialog> createState() =>
      _CustomFieldValuesDialogState();
}

class _CustomFieldValuesDialogState extends State<_CustomFieldValuesDialog> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _stringControllers;
  late Map<String, DateTime?> _dateValues;
  late Map<String, DateTimeRange?> _dateRangeValues;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _stringControllers = {
      for (final definition in widget.definitions)
        if (definition.type == CustomFieldType.string)
          definition.code: TextEditingController(
            text: widget.initialValues[definition.code]?.stringValue ?? '',
          ),
    };
    _dateValues = {
      for (final definition in widget.definitions)
        if (definition.type == CustomFieldType.date)
          definition.code: widget.initialValues[definition.code]?.dateValue,
    };
    _dateRangeValues = {
      for (final definition in widget.definitions)
        if (definition.type == CustomFieldType.dateRange)
          definition.code: _toDateRange(widget.initialValues[definition.code]),
    };
  }

  @override
  void dispose() {
    for (final controller in _stringControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 500,
        child: widget.definitions.isEmpty
            ? const Text('Для цього заняття ще не задано кастомних параметрів.')
            : Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ...widget.definitions.map(_buildValueField),
                      if (_validationError != null) ...[
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _validationError!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Скасувати'),
        ),
        FilledButton(
          onPressed: widget.definitions.isEmpty ? null : _submit,
          child: const Text('Зберегти'),
        ),
      ],
    );
  }

  Widget _buildValueField(LessonCustomFieldDefinition definition) {
    switch (definition.type) {
      case CustomFieldType.date:
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _DatePickerField(
            label: definition.label,
            value: _dateValues[definition.code],
            onPick: () => _pickDate(definition.code),
            onClear: () {
              setState(() => _dateValues[definition.code] = null);
            },
          ),
        );
      case CustomFieldType.dateRange:
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _DateRangePickerField(
            label: definition.label,
            value: _dateRangeValues[definition.code],
            onPick: () => _pickDateRange(definition.code),
            onClear: () {
              setState(() => _dateRangeValues[definition.code] = null);
            },
          ),
        );
      case CustomFieldType.string:
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: TextFormField(
            controller: _stringControllers[definition.code],
            decoration: InputDecoration(
              labelText: definition.label,
              border: const OutlineInputBorder(),
            ),
          ),
        );
    }
  }

  Future<void> _pickDate(String code) async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _dateValues[code] ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (selected == null) return;
    setState(() => _dateValues[code] = selected);
  }

  Future<void> _pickDateRange(String code) async {
    final now = DateTime.now();
    final selected = await showDateRangePicker(
      context: context,
      initialDateRange: _dateRangeValues[code],
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      currentDate: now,
    );

    if (selected == null) return;
    setState(() => _dateRangeValues[code] = selected);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final values = <String, LessonCustomFieldValue>{};
    for (final definition in widget.definitions) {
      switch (definition.type) {
        case CustomFieldType.date:
          final date = _dateValues[definition.code];
          if (date != null) {
            values[definition.code] = LessonCustomFieldValue.date(date);
          }
          break;
        case CustomFieldType.dateRange:
          final dateRange = _dateRangeValues[definition.code];
          if (dateRange != null) {
            values[definition.code] = LessonCustomFieldValue.dateRange(
              start: dateRange.start,
              end: dateRange.end,
            );
          }
          break;
        case CustomFieldType.string:
          final text = _stringControllers[definition.code]?.text.trim() ?? '';
          if (text.isNotEmpty) {
            values[definition.code] = LessonCustomFieldValue.string(text);
          }
          break;
      }
    }

    final sanitizedValues = LessonCustomFieldValue.sanitizeValues(
      definitions: widget.definitions,
      values: values,
    );

    if (_hasIncompleteDateRange()) {
      setState(
        () =>
            _validationError = 'Період має містити дату початку та завершення',
      );
      return;
    }

    Navigator.of(context).pop(sanitizedValues);
  }

  bool _hasIncompleteDateRange() {
    for (final value in _dateRangeValues.values) {
      if (value == null) continue;
      if (value.start == value.end) {
        continue;
      }
    }
    return false;
  }

  static DateTimeRange? _toDateRange(LessonCustomFieldValue? value) {
    if (value == null ||
        value.type != CustomFieldType.dateRange ||
        value.rangeStart == null ||
        value.rangeEnd == null) {
      return null;
    }

    return DateTimeRange(start: value.rangeStart!, end: value.rangeEnd!);
  }
}

class _DatePickerField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onPick;
  final VoidCallback onClear;

  const _DatePickerField({
    required this.label,
    required this.value,
    required this.onPick,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final text = value != null
        ? LessonCustomFieldValue.date(value!).formatDisplayValue()
        : 'Не вказано';

    return InkWell(
      onTap: onPick,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (value != null)
                IconButton(onPressed: onClear, icon: const Icon(Icons.clear)),
              const Icon(Icons.calendar_today),
              const SizedBox(width: 8),
            ],
          ),
        ),
        child: Text(text),
      ),
    );
  }
}

class _DateRangePickerField extends StatelessWidget {
  final String label;
  final DateTimeRange? value;
  final VoidCallback onPick;
  final VoidCallback onClear;

  const _DateRangePickerField({
    required this.label,
    required this.value,
    required this.onPick,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final text = value != null
        ? LessonCustomFieldValue.dateRange(
            start: value!.start,
            end: value!.end,
          ).formatDisplayValue()
        : 'Не вказано';

    return InkWell(
      onTap: onPick,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (value != null)
                IconButton(onPressed: onClear, icon: const Icon(Icons.clear)),
              const Icon(Icons.date_range),
              const SizedBox(width: 8),
            ],
          ),
        ),
        child: Text(text),
      ),
    );
  }
}
