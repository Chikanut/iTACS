import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/checklist_tool/checklist_tool_models.dart';

class ToolFieldWidget extends StatefulWidget {
  const ToolFieldWidget({
    super.key,
    required this.field,
    required this.value,
    required this.onChanged,
  });

  final TemplateField field;
  final String? value;
  final ValueChanged<String> onChanged;

  @override
  State<ToolFieldWidget> createState() => _ToolFieldWidgetState();
}

class _ToolFieldWidgetState extends State<ToolFieldWidget> {
  late final TextEditingController _controller;
  static final DateFormat _dateFormat = DateFormat('dd.MM.yyyy', 'uk');

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value ?? '');
  }

  @override
  void didUpdateWidget(covariant ToolFieldWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newValue = widget.value ?? '';
    if (_controller.text != newValue) {
      _controller.value = TextEditingValue(
        text: newValue,
        selection: TextSelection.collapsed(offset: newValue.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.field.fieldType) {
      case FieldType.date:
        return _buildDateField(context);
      case FieldType.textarea:
        return _buildTextField(maxLines: null, minLines: 3);
      case FieldType.number:
        return _buildTextField(
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        );
      case FieldType.text:
        return _buildTextField();
    }
  }

  Widget _buildTextField({
    int? minLines,
    int? maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextField(
      controller: _controller,
      minLines: minLines,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: widget.field.label,
        hintText: widget.field.placeholder,
        border: const OutlineInputBorder(),
      ),
      onChanged: widget.onChanged,
    );
  }

  Widget _buildDateField(BuildContext context) {
    return InkWell(
      onTap: () => _pickDate(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: widget.field.label,
          hintText: widget.field.placeholder ?? 'Оберіть дату',
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.calendar_today),
        ),
        child: Text(
          _controller.text.isEmpty ? 'Оберіть дату' : _controller.text,
          style: _controller.text.isEmpty
              ? Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).hintColor,
                )
              : null,
        ),
      ),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    DateTime initialDate = DateTime.now();
    if ((widget.value ?? '').trim().isNotEmpty) {
      try {
        initialDate = _dateFormat.parse(widget.value!);
      } catch (_) {}
    }

    final selectedDate = await showDatePicker(
      context: context,
      locale: const Locale('uk', 'UA'),
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (selectedDate == null) {
      return;
    }

    final formatted = _dateFormat.format(selectedDate);
    _controller.text = formatted;
    widget.onChanged(formatted);
  }
}
