// lib/pages/calendar_page/widgets/lesson_details_dialog.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/lesson_model.dart';
import '../../../services/calendar_service.dart';
import '../calendar_utils.dart';
import '../../../globals.dart';
import 'lesson_form_dialog.dart';

class LessonDetailsDialog extends StatefulWidget {
  final LessonModel lesson;
  final VoidCallback? onUpdated;

  const LessonDetailsDialog({
    super.key,
    required this.lesson,
    this.onUpdated,
  });

  @override
  State<LessonDetailsDialog> createState() => _LessonDetailsDialogState();
}

class _LessonDetailsDialogState extends State<LessonDetailsDialog> {
  final CalendarService _calendarService = CalendarService();
  bool _isLoading = false;
  bool _isRegistered = false;

  @override
  void initState() {
    super.initState();
    _isRegistered = _calendarService.isUserRegisteredForLesson(widget.lesson);
  }

  @override
  Widget build(BuildContext context) {
    final lesson = widget.lesson;
    final occupancyRate = CalendarUtils.getOccupancyRate(
      lesson.currentParticipants, 
      lesson.maxParticipants
    );
    final status = CalendarUtils.getLessonStatus(
      lesson.currentParticipants, 
      lesson.maxParticipants, 
      _isRegistered
    );

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Шапка
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: CalendarUtils.getGroupColor(lesson.groupName),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Icon(
                    CalendarUtils.getLessonTypeIcon(
                      lesson.tags.isNotEmpty ? lesson.tags.first : ''
                    ),
                    size: 24,
                    color: Colors.grey.shade700,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lesson.title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          lesson.groupName,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),

            // Контент
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Час
                    _buildDetailRow(
                      icon: Icons.schedule,
                      label: 'Час проведення',
                      value: '${DateFormat('dd.MM.yyyy HH:mm').format(lesson.startTime)} - ${DateFormat('HH:mm').format(lesson.endTime)}',
                    ),
                    
                    const SizedBox(height: 16),

                    // Інструктор
                    _buildDetailRow(
                      icon: Icons.person,
                      label: 'Інструктор',
                      value: lesson.instructor,
                    ),
                    
                    const SizedBox(height: 16),

                    // Локація
                    _buildDetailRow(
                      icon: Icons.location_on,
                      label: 'Місце проведення',
                      value: lesson.location,
                    ),
                    
                    const SizedBox(height: 16),

                    // Підрозділ
                    _buildDetailRow(
                      icon: Icons.military_tech,
                      label: 'Підрозділ',
                      value: lesson.unit,
                    ),
                    
                    const SizedBox(height: 16),

                    // Опис
                    if (lesson.description.isNotEmpty) ...[
                      _buildDetailRow(
                        icon: Icons.description,
                        label: 'Опис',
                        value: lesson.description,
                        isMultiline: true,
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Учасники
                    _buildParticipantsSection(lesson, occupancyRate, status),
                    
                    const SizedBox(height: 16),

                    // Теги
                    if (lesson.tags.isNotEmpty) ...[
                      const Text(
                        'Теги',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: lesson.tags.map((tag) => Chip(
                          label: Text(tag),
                          backgroundColor: Colors.blue.shade100,
                          labelStyle: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade800,
                          ),
                        )).toList(),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Статус
                    _buildStatusSection(lesson, status),
                  ],
                ),
              ),
            ),

            // Кнопки дій
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: _buildActionButtons(lesson),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    bool isMultiline = false,
  }) {
    return Row(
      crossAxisAlignment: isMultiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: 20,
          color: Colors.grey.shade600,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildParticipantsSection(LessonModel lesson, double occupancyRate, LessonStatus status) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Учасники',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${lesson.currentParticipants} з ${lesson.maxParticipants} зареєстровано',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: occupancyRate,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(status.color),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: status.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: status.color.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    status.icon,
                    size: 14,
                    color: status.color,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    status.label,
                    style: TextStyle(
                      fontSize: 12,
                      color: status.color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusSection(LessonModel lesson, LessonStatus status) {
    String statusText;
    Color statusColor;
    
    switch (lesson.status) {
      case 'scheduled':
        statusText = 'Заплановано';
        statusColor = Colors.blue;
        break;
      case 'ongoing':
        statusText = 'Проводиться зараз';
        statusColor = Colors.orange;
        break;
      case 'completed':
        statusText = 'Завершено';
        statusColor = Colors.green;
        break;
      case 'cancelled':
        statusText = 'Скасовано';
        statusColor = Colors.red;
        break;
      default:
        statusText = 'Невідомо';
        statusColor = Colors.grey;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Статус заняття',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: statusColor.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getStatusIcon(lesson.status),
                size: 16,
                color: statusColor,
              ),
              const SizedBox(width: 8),
              Text(
                statusText,
                style: TextStyle(
                  fontSize: 14,
                  color: statusColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(LessonModel lesson) {
    final canEdit = _canEditLesson();
    final isFull = CalendarUtils.isFull(lesson.currentParticipants, lesson.maxParticipants);
    
    return Column(
      children: [
        // Основні кнопки
        Row(
          children: [
            // Кнопка реєстрації/скасування
            if (!_isRegistered && !isFull)
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : () => _registerForLesson(),
                  icon: _isLoading 
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.person_add, size: 16),
                  label: const Text('Зареєструватися'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              )
            else if (_isRegistered)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : () => _unregisterFromLesson(),
                  icon: _isLoading 
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.person_remove, size: 16),
                  label: const Text('Скасувати реєстрацію'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                    side: const BorderSide(color: Colors.orange),
                  ),
                ),
              ),
            
            if ((!_isRegistered && !isFull) || _isRegistered) const SizedBox(width: 12),
            
            // Кнопка редагування (тільки для адмінів/інструкторів)
            if (canEdit)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _editLesson(),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Редагувати'),
                ),
              ),
          ],
        ),
        
        // Додаткові кнопки
        if (canEdit) ...[
          const SizedBox(height: 8),
          Row(
            children: [
                 Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _createLessonAtThisTime(),
                    icon: const Icon(Icons.add_circle_outline, size: 16),
                    label: const Text('Створити в цей час'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green,
                    ),
                  ),
                ),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _duplicateLesson(),
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Дублювати'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _deleteLesson(),
                  icon: const Icon(Icons.delete, size: 16),
                  label: const Text('Видалити'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'scheduled':
        return Icons.schedule;
      case 'ongoing':
        return Icons.play_circle;
      case 'completed':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  void _createLessonAtThisTime() {
    showDialog(
      context: context,
      builder: (context) => LessonFormDialog(
        initialDate: DateTime(
          widget.lesson.startTime.year,
          widget.lesson.startTime.month,
          widget.lesson.startTime.day,
        ),
        initialStartTime: TimeOfDay.fromDateTime(widget.lesson.startTime),
        onSaved: () {
          widget.onUpdated?.call();
        },
      ),
    );
  }

  bool _canEditLesson() {
    final currentRole = Globals.profileManager.currentRole;
    final currentUser = Globals.firebaseAuth.currentUser;
    
    return currentRole == 'admin' || 
           currentRole == 'editor' ||
           widget.lesson.createdBy == currentUser?.uid;
  }

  Future<void> _registerForLesson() async {
    setState(() => _isLoading = true);
    
    try {
      final success = await _calendarService.registerForLesson(widget.lesson.id);
      if (success && mounted) {
        setState(() => _isRegistered = true);
        widget.onUpdated?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Успішно зареєстровано на заняття "${widget.lesson.title}"'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Помилка реєстрації: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _unregisterFromLesson() async {
    setState(() => _isLoading = true);
    
    try {
      final success = await _calendarService.unregisterFromLesson(widget.lesson.id);
      if (success && mounted) {
        setState(() => _isRegistered = false);
        widget.onUpdated?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Реєстрацію на заняття "${widget.lesson.title}" скасовано'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Помилка скасування реєстрації: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _editLesson() {
    Navigator.of(context).pop();
    // TODO: Відкрити форму редагування заняття
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Функція редагування буде додана пізніше')),
    );
  }

  void _duplicateLesson() {
    Navigator.of(context).pop();
    // TODO: Відкрити форму з заповненими даними для дублювання
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Функція дублювання буде додана пізніше')),
    );
  }

  void _deleteLesson() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Видалити заняття'),
        content: Text('Ви впевнені, що хочете видалити заняття "${widget.lesson.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Скасувати'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
              
              final success = await _calendarService.deleteLesson(widget.lesson.id);
              if (success && mounted) {
                widget.onUpdated?.call();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Заняття "${widget.lesson.title}" видалено'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Видалити'),
          ),
        ],
      ),
    );
  }
}