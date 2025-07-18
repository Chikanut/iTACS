import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/instructor_absence.dart';
import '../../../globals.dart';

class AbsenceAssignmentDialog extends StatefulWidget {
  final String instructorId;
  final String instructorName;
  final DateTime initialDate;
  final VoidCallback onAssigned;

  const AbsenceAssignmentDialog({
    super.key,
    required this.instructorId,
    required this.instructorName,
    required this.initialDate,
    required this.onAssigned,
  });

  @override
  State<AbsenceAssignmentDialog> createState() => _AbsenceAssignmentDialogState();
}

class _AbsenceAssignmentDialogState extends State<AbsenceAssignmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final _orderNumberController = TextEditingController();
  final _destinationController = TextEditingController();
  final _dutyController = TextEditingController();
  final _instructionsController = TextEditingController();

  AbsenceType _selectedType = AbsenceType.businessTrip;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _startDate = widget.initialDate;
    _endDate = widget.initialDate;
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _orderNumberController.dispose();
    _destinationController.dispose();
    _dutyController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.assignment, color: Theme.of(context).primaryColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Призначити відсутність - ${widget.instructorName}'),
          ),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
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
                  items: [AbsenceType.businessTrip, AbsenceType.duty]
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
                  'Період',
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
                            if (_endDate != null && _endDate!.isBefore(date)) {
                              _endDate = date;
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

                // Основна причина
                Text(
                  'Причина',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _reasonController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Коротка причина призначення...',
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  maxLines: 2,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Причина є обов\'язковою';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Деталі призначення
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Деталі призначення',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 12),
                      
                      if (_selectedType == AbsenceType.businessTrip) ...[
                        // Номер наказу
                        TextFormField(
                          controller: _orderNumberController,
                          decoration: const InputDecoration(
                            labelText: 'Номер наказу',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        // Місце призначення
                        TextFormField(
                          controller: _destinationController,
                          decoration: const InputDecoration(
                            labelText: 'Місце призначення',
                            border: OutlineInputBorder(),
                            hintText: 'Місто, адреса...',
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          validator: (value) {
                            if (_selectedType == AbsenceType.businessTrip && 
                                (value == null || value.trim().isEmpty)) {
                              return 'Місце призначення обов\'язкове для відрядження';
                            }
                            return null;
                          },
                        ),
                      ] else if (_selectedType == AbsenceType.duty) ...[
                        // Тип чергування
                        TextFormField(
                          controller: _dutyController,
                          decoration: const InputDecoration(
                            labelText: 'Тип чергування',
                            border: OutlineInputBorder(),
                            hintText: 'Добовий наряд, чергування...',
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          validator: (value) {
                            if (_selectedType == AbsenceType.duty && 
                                (value == null || value.trim().isEmpty)) {
                              return 'Тип чергування обов\'язковий';
                            }
                            return null;
                          },
                        ),
                      ],
                      
                      const SizedBox(height: 12),
                      
                      // Додаткові інструкції
                      TextFormField(
                        controller: _instructionsController,
                        decoration: const InputDecoration(
                          labelText: 'Додаткові інструкції',
                          border: OutlineInputBorder(),
                          hintText: 'Особливі вказівки, контакти...',
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Попередження
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.orange.shade600, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Призначення адміном буде активне одразу. '
                          'Перевірте конфлікти з розкладом занять.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade700,
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
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Скасувати'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _assignAbsence,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Призначити'),
        ),
      ],
    );
  }

  Future<void> _assignAbsence() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null || _endDate == null) {
      _showError('Оберіть початок та кінець періоду');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Отримуємо email інструктора
      final currentGroupId = Globals.profileManager.currentGroupId;
      if (currentGroupId == null) throw Exception('Група не обрана');

      final groupData = await Globals.firestoreManager.getDocumentsForGroup(
        groupId: currentGroupId,
        collection: 'allowed_users',
      );

      String? instructorEmail;
      if (groupData.isNotEmpty) {
        final data = groupData.first.data() as Map<String, dynamic>;
        final members = Map<String, dynamic>.from(data['members'] ?? {});
        
        for (final entry in members.entries) {
          final memberData = Map<String, dynamic>.from(entry.value);
          if (memberData['uid'] == widget.instructorId) {
            instructorEmail = entry.key;
            break;
          }
        }
      }

      if (instructorEmail == null) {
        throw Exception('Не вдалося знайти email інструктора');
      }

      final assignmentDetails = AssignmentDetails(
        orderNumber: _orderNumberController.text.trim().isNotEmpty 
            ? _orderNumberController.text.trim() 
            : null,
        destination: _destinationController.text.trim().isNotEmpty 
            ? _destinationController.text.trim() 
            : null,
        duty: _dutyController.text.trim().isNotEmpty 
            ? _dutyController.text.trim() 
            : null,
        instructions: _instructionsController.text.trim().isNotEmpty 
            ? _instructionsController.text.trim() 
            : null,
      );

      final success = await Globals.absencesService.assignAbsence(
        instructorId: widget.instructorId,
        instructorName: widget.instructorName,
        instructorEmail: instructorEmail,
        type: _selectedType,
        startDate: _startDate!,
        endDate: _endDate!,
        reason: _reasonController.text.trim(),
        assignmentDetails: assignmentDetails,
      );

      if (success && mounted) {
        Navigator.of(context).pop();
        widget.onAssigned();
        _showSuccess('Відсутність призначено успішно!');
      }
    } catch (e) {
      if (mounted) {
        _showError('Помилка призначення: ${e.toString()}');
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