import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/instructor_absence.dart';
import '../globals.dart';

class AbsenceRequestDialog extends StatefulWidget {
  const AbsenceRequestDialog({super.key});

  @override
  State<AbsenceRequestDialog> createState() => _AbsenceRequestDialogState();
}

class _AbsenceRequestDialogState extends State<AbsenceRequestDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final _documentController = TextEditingController();

  AbsenceType _selectedType = AbsenceType.vacation;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = false;

  @override
  void dispose() {
    _reasonController.dispose();
    _documentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.event_busy, color: Theme.of(context).primaryColor),
          const SizedBox(width: 8),
          const Text('Запит на відсутність'),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Тип відсутності
              Text(
                'Тип відсутності',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<AbsenceType>(
                value: _selectedType,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: [AbsenceType.vacation, AbsenceType.sickLeave]
                    .map((type) => DropdownMenuItem(
                          value: type,
                          child: Row(
                            children: [
                              Text(type.emoji),
                              const SizedBox(width: 8),
                              Text(type.displayName),
                            ],
                          ),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedType = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),

              // Період
              Text(
                'Період відсутності',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _DatePickerField(
                      label: 'Початок',
                      selectedDate: _startDate,
                      onDateSelected: (date) {
                        setState(() {
                          _startDate = date;
                          // Якщо кінцева дата раніше початкової, скидаємо її
                          if (_endDate != null && _endDate!.isBefore(date)) {
                            _endDate = null;
                          }
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DatePickerField(
                      label: 'Кінець',
                      selectedDate: _endDate,
                      onDateSelected: (date) {
                        setState(() {
                          _endDate = date;
                        });
                      },
                      minDate: _startDate,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Причина
              Text(
                'Причина відсутності',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _reasonController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Вкажіть причину відсутності...',
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Причина є обов\'язковою';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Номер документа (для лікарняного)
              if (_selectedType == AbsenceType.sickLeave) ...[
                Text(
                  'Номер лікарняного листа',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _documentController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Номер документа (опціонально)',
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Інформаційне повідомлення
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue.shade600, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Запит буде відправлено адміністратору для розгляду. '
                        'Ви отримаете повідомлення про результат.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Скасувати'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submitRequest,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Відправити запит'),
        ),
      ],
    );
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null || _endDate == null) {
      _showError('Оберіть початок та кінець періоду');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final success = await Globals.absencesService.createAbsenceRequest(
        type: _selectedType,
        startDate: _startDate!,
        endDate: _endDate!,
        reason: _reasonController.text.trim(),
        documentNumber: _documentController.text.trim().isNotEmpty
            ? _documentController.text.trim()
            : null,
      );

      if (success && mounted) {
        Navigator.of(context).pop();
        _showSuccess('Запит на відсутність відправлено успішно!');
      }
    } catch (e) {
      if (mounted) {
        _showError('Помилка відправки запиту: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _DatePickerField extends StatelessWidget {
  final String label;
  final DateTime? selectedDate;
  final Function(DateTime) onDateSelected;
  final DateTime? minDate;

  const _DatePickerField({
    required this.label,
    required this.selectedDate,
    required this.onDateSelected,
    this.minDate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: () => _selectDate(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    selectedDate != null
                        ? DateFormat('dd.MM.yyyy').format(selectedDate!)
                        : 'Оберіть дату',
                    style: TextStyle(
                      color: selectedDate != null
                          ? Colors.black87
                          : Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final now = DateTime.now();
    final firstDate = minDate ?? now;
    final lastDate = DateTime(now.year + 1);

    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? firstDate,
      firstDate: firstDate,
      lastDate: lastDate,
      locale: const Locale('uk', 'UA'),
    );

    if (picked != null) {
      onDateSelected(picked);
    }
  }
}