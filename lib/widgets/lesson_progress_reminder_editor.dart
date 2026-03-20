import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/lesson_progress_reminder.dart';

class LessonProgressReminderEditor extends StatelessWidget {
  final List<LessonProgressReminder> reminders;
  final ValueChanged<List<LessonProgressReminder>> onChanged;
  final DateTime? previewStartTime;
  final DateTime? previewEndTime;
  final int? durationMinutes;
  final String emptyText;

  const LessonProgressReminderEditor({
    super.key,
    required this.reminders,
    required this.onChanged,
    required this.emptyText,
    this.previewStartTime,
    this.previewEndTime,
    this.durationMinutes,
  });

  @override
  Widget build(BuildContext context) {
    final sortedReminders = List<LessonProgressReminder>.from(reminders)
      ..sort(
        (left, right) => left.progressPercent.compareTo(right.progressPercent),
      );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Нагадування під час заняття',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            TextButton.icon(
              onPressed: () => _createReminder(context),
              icon: const Icon(Icons.add_alert_outlined),
              label: const Text('Додати'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Timeline у відсотках від ходу заняття. Для конкретного заняття нижче показується фактичний час спрацювання.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        _ReminderTimeline(reminders: sortedReminders),
        const SizedBox(height: 12),
        if (sortedReminders.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              emptyText,
              style: TextStyle(color: Colors.grey.shade700),
            ),
          )
        else
          Column(
            children: sortedReminders
                .map((reminder) => _buildReminderCard(context, reminder))
                .toList(),
          ),
      ],
    );
  }

  Widget _buildReminderCard(
    BuildContext context,
    LessonProgressReminder reminder,
  ) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  reminder.title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '${reminder.progressPercent.toStringAsFixed(reminder.progressPercent.truncateToDouble() == reminder.progressPercent ? 0 : 1)}%',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(reminder.message),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(
                avatar: const Icon(Icons.timeline, size: 16),
                label: Text(_scheduleLabel(reminder)),
              ),
              if (_dueAtLabel(reminder) case final dueAtLabel?)
                Chip(
                  avatar: const Icon(Icons.schedule, size: 16),
                  label: Text(dueAtLabel),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton.icon(
                onPressed: () => _editReminder(context, reminder),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Редагувати'),
              ),
              TextButton.icon(
                onPressed: () => _deleteReminder(reminder.id),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Видалити'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _scheduleLabel(LessonProgressReminder reminder) {
    if (durationMinutes == null) {
      return '${reminder.progressPercent.toStringAsFixed(0)}% від ходу заняття';
    }

    final offsetMinutes = (durationMinutes! * (reminder.progressPercent / 100))
        .round();
    return '${reminder.progressPercent.toStringAsFixed(0)}% • через $offsetMinutes хв від початку';
  }

  String? _dueAtLabel(LessonProgressReminder reminder) {
    final startTime = previewStartTime;
    final endTime = previewEndTime;
    if (startTime == null || endTime == null) {
      return null;
    }

    final dueAt = reminder.calculateDueAt(
      startTime: startTime,
      endTime: endTime,
    );
    final isSameDay =
        dueAt.year == startTime.year &&
        dueAt.month == startTime.month &&
        dueAt.day == startTime.day;
    final formatter = DateFormat(isSameDay ? 'HH:mm' : 'dd.MM HH:mm');
    return formatter.format(dueAt);
  }

  Future<void> _createReminder(BuildContext context) async {
    final reminder = await showDialog<LessonProgressReminder>(
      context: context,
      builder: (context) => const _ReminderDialog(),
    );

    if (reminder == null) {
      return;
    }

    onChanged([...reminders, reminder]);
  }

  Future<void> _editReminder(
    BuildContext context,
    LessonProgressReminder reminder,
  ) async {
    final updatedReminder = await showDialog<LessonProgressReminder>(
      context: context,
      builder: (context) => _ReminderDialog(initialReminder: reminder),
    );

    if (updatedReminder == null) {
      return;
    }

    onChanged(
      reminders
          .map((item) => item.id == reminder.id ? updatedReminder : item)
          .toList(),
    );
  }

  void _deleteReminder(String reminderId) {
    onChanged(
      reminders.where((reminder) => reminder.id != reminderId).toList(),
    );
  }
}

class _ReminderTimeline extends StatelessWidget {
  final List<LessonProgressReminder> reminders;

  const _ReminderTimeline({required this.reminders});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              return SizedBox(
                height: 48,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      top: 20,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    ...reminders.map((reminder) {
                      final left =
                          (constraints.maxWidth - 20) *
                          (reminder.progressPercent / 100);
                      return Positioned(
                        top: 0,
                        left: left,
                        child: Tooltip(
                          message:
                              '${reminder.title} (${reminder.progressPercent.toStringAsFixed(0)}%)',
                          child: Column(
                            children: [
                              Icon(
                                Icons.notifications_active,
                                size: 18,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 4),
          const Row(children: [Text('0%'), Spacer(), Text('100%')]),
        ],
      ),
    );
  }
}

class _ReminderDialog extends StatefulWidget {
  final LessonProgressReminder? initialReminder;

  const _ReminderDialog({this.initialReminder});

  @override
  State<_ReminderDialog> createState() => _ReminderDialogState();
}

class _ReminderDialogState extends State<_ReminderDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _messageController;
  late final TextEditingController _percentController;
  late double _progressPercent;

  @override
  void initState() {
    super.initState();
    final initialReminder = widget.initialReminder;
    _progressPercent = initialReminder?.progressPercent ?? 50;
    _titleController = TextEditingController(
      text: initialReminder?.title ?? '',
    );
    _messageController = TextEditingController(
      text: initialReminder?.message ?? '',
    );
    _percentController = TextEditingController(
      text: _progressPercent.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    _percentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialReminder != null;

    return AlertDialog(
      title: Text(isEditing ? 'Редагувати нагадування' : 'Нове нагадування'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Заголовок *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Вкажіть заголовок';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _messageController,
                  decoration: const InputDecoration(
                    labelText: 'Текст нагадування *',
                    border: OutlineInputBorder(),
                  ),
                  minLines: 3,
                  maxLines: 5,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Вкажіть текст нагадування';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _percentController,
                  decoration: const InputDecoration(
                    labelText: 'Позиція на timeline, % *',
                    border: OutlineInputBorder(),
                    suffixText: '%',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) {
                    final percent = double.tryParse((value ?? '').trim());
                    if (percent == null) {
                      return 'Вкажіть число від 0 до 100';
                    }
                    if (percent < 0 || percent > 100) {
                      return 'Межі: від 0 до 100';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    final nextValue = double.tryParse(value);
                    if (nextValue == null) {
                      return;
                    }
                    setState(() {
                      _progressPercent = nextValue.clamp(0, 100);
                    });
                  },
                ),
                const SizedBox(height: 16),
                Slider(
                  value: _progressPercent,
                  min: 0,
                  max: 100,
                  divisions: 100,
                  label: _progressPercent.toStringAsFixed(0),
                  onChanged: (value) {
                    setState(() {
                      _progressPercent = value;
                      _percentController.text = value.toStringAsFixed(0);
                    });
                  },
                ),
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
          onPressed: _submit,
          child: Text(isEditing ? 'Зберегти' : 'Додати'),
        ),
      ],
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final reminder = LessonProgressReminder(
      id: widget.initialReminder?.id ?? LessonProgressReminder.createId(),
      title: _titleController.text.trim(),
      message: _messageController.text.trim(),
      progressPercent: double.parse(
        _percentController.text.trim(),
      ).clamp(0, 100),
    );

    Navigator.of(context).pop(reminder);
  }
}
