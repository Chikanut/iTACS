// lib/pages/calendar_page/widgets/lesson_details_dialog.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/lesson_model.dart';
import '../../../services/calendar_service.dart';
import '../calendar_utils.dart';
import '../../../globals.dart';
import 'lesson_form_dialog.dart';

class LessonDetailsDialog extends StatefulWidget {
  final LessonModel lesson;
  final VoidCallback? onUpdated;

  const LessonDetailsDialog({super.key, required this.lesson, this.onUpdated});

  @override
  State<LessonDetailsDialog> createState() => _LessonDetailsDialogState();
}

class _LessonDetailsDialogState extends State<LessonDetailsDialog> {
  final CalendarService _calendarService = CalendarService();
  bool _isLoading = false;
  bool _isRegistered = false;
  bool _isLoadingInstructors = false;
  List<Map<String, dynamic>> _availableInstructors = [];
  late LessonModel _lesson;

  @override
  void initState() {
    super.initState();
    _lesson = widget.lesson;
    _isRegistered = _calendarService.isUserRegisteredForLesson(_lesson);
    _loadAssignableInstructors();
  }

  @override
  Widget build(BuildContext context) {
    final lesson = _lesson;
    final status = LessonStatusUtils.getProgressStatus(lesson);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    CalendarUtils.getLessonTypeIcon(
                      lesson.tags.isNotEmpty ? lesson.tags.first : '',
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
                            color: Color.fromARGB(255, 29, 28, 28),
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
                      value:
                          '${DateFormat('dd.MM.yyyy HH:mm').format(lesson.startTime)} - ${DateFormat('HH:mm').format(lesson.endTime)}',
                    ),

                    const SizedBox(height: 16),

                    // Інструктор
                    _buildDetailRow(
                      icon: Icons.person,
                      label: 'Викладачі',
                      value: lesson.displayInstructorNames,
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

                    // Підрозділ
                    _buildDetailRow(
                      icon: Icons.military_tech,
                      label: 'Період навчання',
                      value: lesson.trainingPeriod.isNotEmpty
                          ? lesson.trainingPeriod
                          : 'Не вказано',
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
                    _buildParticipantsSection(lesson),

                    if (_shouldShowCurrentUserAcknowledgementSection(
                      lesson,
                    )) ...[
                      const SizedBox(height: 16),
                      _buildCurrentUserAcknowledgementSection(lesson),
                    ],

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
                        children: lesson.tags
                            .map(
                              (tag) => Chip(
                                label: Text(tag),
                                backgroundColor: Colors.blue.shade100,
                                labelStyle: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue.shade800,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Статус
                    _buildStatusSection(lesson, status),

                    if (_canAssignOthers() && lesson.hasInstructors) ...[
                      const SizedBox(height: 16),
                      _buildInstructorAcknowledgementsSection(lesson),
                    ],
                  ],
                ),
              ),
            ),

            // Кнопки дій
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
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
      crossAxisAlignment: isMultiline
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
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

  Widget _buildParticipantsSection(LessonModel lesson) {
    final needsInstructor = _calendarService.doesLessonNeedInstructor(lesson);
    final isUserInstructor = _calendarService.isUserInstructorForLesson(lesson);
    final status = CalendarUtils.getInstructorLessonStatus(
      lesson,
      isUserInstructor,
    );

    final readinessStatus = LessonStatusUtils.getReadinessStatus(lesson);
    final missingFields = LessonStatusUtils.getMissingCriticalFields(lesson);
    final hasProblems = missingFields.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Інформація про заняття',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        // Блок викладача з підсвіткою помилки
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: hasProblems
                ? Colors.red.withOpacity(0.05)
                : status.color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: hasProblems ? Colors.red : status.color.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Icon(
                hasProblems ? Icons.error_outline : status.icon,
                color: hasProblems ? Colors.red : status.color,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      needsInstructor
                          ? 'Викладач не призначений'
                          : 'Викладачі: ${lesson.displayInstructorNames}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasProblems
                          ? 'Проблеми з заповненням: ${missingFields.join(", ")}'
                          : status.label,
                      style: TextStyle(
                        fontSize: 12,
                        color: hasProblems ? Colors.red : status.color,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Інформація про учнів
        Row(
          children: [
            Icon(Icons.group, size: 20, color: Colors.grey.shade600),
            const SizedBox(width: 8),
            Text(
              'Очікується: ${lesson.maxParticipants} учнів',
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusSection(LessonModel lesson, LessonProgressStatus status) {
    String statusText;
    Color statusColor;

    switch (status) {
      case LessonProgressStatus.scheduled:
        statusText = 'Заплановано';
        statusColor = Colors.blue;
        break;
      case LessonProgressStatus.inProgress:
        statusText = 'Проводиться зараз';
        statusColor = Colors.blue;
        break;
      case LessonProgressStatus.completed:
        statusText = 'Завершено';
        statusColor = Colors.green;
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Статус заняття',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
              Icon(_getStatusIcon(lesson.status), size: 16, color: statusColor),
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

  Widget _buildCurrentUserAcknowledgementSection(LessonModel lesson) {
    final assignmentId = _calendarService.getCurrentUserAssignmentIdForLesson(
      lesson,
    );
    final status = assignmentId != null
        ? LessonStatusUtils.getAcknowledgementStatusForInstructor(
            lesson,
            instructorAssignmentId: assignmentId,
            instructorIdentityCandidates: _calendarService
                .getCurrentUserAssignmentCandidates(),
          )
        : LessonAcknowledgementStatus.notRequired;
    final progressStatus = LessonStatusUtils.getProgressStatus(lesson);
    final record = assignmentId != null
        ? LessonStatusUtils.getAcknowledgementRecordForInstructor(
            lesson,
            instructorAssignmentId: assignmentId,
            instructorIdentityCandidates: _calendarService
                .getCurrentUserAssignmentCandidates(),
          )
        : null;
    final subtitle = assignmentId != null
        ? LessonStatusUtils.getAcknowledgementStatusText(
            lesson,
            instructorAssignmentId: assignmentId,
            instructorIdentityCandidates: _calendarService
                .getCurrentUserAssignmentCandidates(),
            acknowledgedAtFormatter: DateFormat('dd.MM.yyyy HH:mm'),
          )
        : status.label;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: status.color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: status.color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(status.icon, color: status.color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Мій статус ознайомлення',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: status.color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructorAcknowledgementsSection(LessonModel lesson) {
    final dateFormatter = DateFormat('dd.MM.yyyy HH:mm');
    final assignments = lesson.instructorAssignmentsById.entries.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ознайомлення викладачів',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...assignments.map((entry) {
          final identityCandidates = _identityCandidatesForInstructor(
            entry.key,
          );
          final status =
              LessonStatusUtils.getAcknowledgementStatusForInstructor(
                lesson,
                instructorAssignmentId: entry.key,
                instructorIdentityCandidates: identityCandidates,
              );
          final record =
              LessonStatusUtils.getAcknowledgementRecordForInstructor(
                lesson,
                instructorAssignmentId: entry.key,
                instructorIdentityCandidates: identityCandidates,
              );
          final subtitle = LessonStatusUtils.getAcknowledgementStatusText(
            lesson,
            instructorAssignmentId: entry.key,
            instructorIdentityCandidates: identityCandidates,
            acknowledgedAtFormatter: dateFormatter,
          );

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: status.color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: status.color.withOpacity(0.25)),
            ),
            child: Row(
              children: [
                Icon(status.icon, color: status.color, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.value,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: status.color,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildActionButtons(LessonModel lesson) {
    final canEdit = _canEditLesson();
    final needsInstructor = _calendarService.doesLessonNeedInstructor(lesson);
    final isUserInstructor = _calendarService.isUserInstructorForLesson(lesson);
    final canTakeLesson = _canTakeLesson(); // Перевірка ролі editor/admin
    final canAssignOthers = _canAssignOthers();
    final currentAssignmentId = _calendarService
        .getCurrentUserAssignmentIdForLesson(lesson);
    final acknowledgementStatus = currentAssignmentId != null
        ? LessonStatusUtils.getAcknowledgementStatusForInstructor(
            lesson,
            instructorAssignmentId: currentAssignmentId,
            instructorIdentityCandidates: _calendarService
                .getCurrentUserAssignmentCandidates(),
          )
        : LessonAcknowledgementStatus.notRequired;

    return Column(
      children: [
        if (isUserInstructor &&
            LessonStatusUtils.getProgressStatus(lesson) !=
                LessonProgressStatus.completed &&
            (acknowledgementStatus == LessonAcknowledgementStatus.pending ||
                acknowledgementStatus ==
                    LessonAcknowledgementStatus.urgent)) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _acknowledgeLesson,
              icon: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.visibility, size: 16),
              label: const Text('Ознайомитись'),
              style: ElevatedButton.styleFrom(
                backgroundColor: acknowledgementStatus.color,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Кнопки для викладачів
        if (canTakeLesson) ...[
          if (!isUserInstructor)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : () => _takeLesson(),
                icon: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.school, size: 16),
                label: Text(
                  needsInstructor
                      ? 'Взяти заняття на себе'
                      : 'Додати себе до викладачів',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            )
          else if (isUserInstructor)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : () => _releaseLesson(),
                icon: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.person_remove, size: 16),
                label: const Text('Відмовитися від заняття'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange,
                  side: const BorderSide(color: Colors.orange),
                ),
              ),
            ),

          const SizedBox(height: 12),
        ],

        if (canAssignOthers) ...[
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isLoading || _isLoadingInstructors
                  ? null
                  : _showAssignInstructorDialog,
              icon: _isLoadingInstructors
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      needsInstructor
                          ? Icons.person_add_alt_1
                          : Icons.swap_horiz,
                      size: 16,
                    ),
              label: Text(
                needsInstructor
                    ? 'Призначити викладачів'
                    : 'Змінити викладачів',
              ),
            ),
          ),
          if (!needsInstructor) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : _unassignInstructor,
                icon: const Icon(Icons.person_off_outlined, size: 16),
                label: const Text('Зняти викладача'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.orange),
              ),
            ),
          ],
          const SizedBox(height: 12),
        ],

        // Кнопки редагування
        if (canEdit) ...[
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _editLesson(),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Редагувати'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _duplicateLesson(),
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Дублювати'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.blue),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _deleteLesson(),
              icon: const Icon(Icons.delete, size: 16),
              label: const Text('Видалити заняття'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
              ),
            ),
          ),
        ],
      ],
    );
  }

  bool _canTakeLesson() {
    final currentRole = Globals.profileManager.currentRole;
    return currentRole == 'admin' || currentRole == 'editor';
  }

  bool _canAssignOthers() {
    return Globals.profileManager.currentRole == 'admin';
  }

  Future<void> _loadAssignableInstructors() async {
    if (!_canAssignOthers()) return;

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
    });
  }

  Future<void> _takeLesson() async {
    setState(() => _isLoading = true);

    try {
      final success = await _calendarService.takeLesson(_lesson.id);
      if (success && mounted) {
        // 👈 Закриваємо діалог і оновлюємо календар
        Navigator.of(context).pop();
        widget.onUpdated?.call();

        // Показуємо повідомлення в контексті календаря
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Ви взяли заняття "${_lesson.title}" на себе'),
                backgroundColor: Colors.green,
              ),
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Помилка: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _releaseLesson() async {
    setState(() => _isLoading = true);

    try {
      final success = await _calendarService.releaseLesson(_lesson.id);
      if (success && mounted) {
        // 👈 Закриваємо діалог і оновлюємо календар
        Navigator.of(context).pop();
        widget.onUpdated?.call();

        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Ви відмовились від заняття "${_lesson.title}"'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Помилка: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showAssignInstructorDialog() async {
    if (_availableInstructors.isEmpty) {
      await _loadAssignableInstructors();
    }
    if (!mounted) return;

    final availableOptions = _availableInstructorOptions();
    final selectedInstructorIds = {..._lesson.instructorIds};

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Призначити викладачів'),
              content: SizedBox(
                width: 420,
                child: availableOptions.isEmpty
                    ? const Text('У групі поки немає доступних викладачів.')
                    : SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: availableOptions.entries.map((entry) {
                            return CheckboxListTile(
                              value: selectedInstructorIds.contains(entry.key),
                              title: Text(entry.value),
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              onChanged: (checked) {
                                setStateDialog(() {
                                  if (checked == true) {
                                    selectedInstructorIds.add(entry.key);
                                  } else {
                                    selectedInstructorIds.remove(entry.key);
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

    setState(() => _isLoading = true);
    try {
      final selectedNames = availableOptions.entries
          .where((entry) => selectedInstructorIds.contains(entry.key))
          .map((entry) => entry.value)
          .toList();

      final success = await _calendarService.assignLessonInstructors(
        _lesson.id,
        instructorIds: selectedInstructorIds.toList(),
        instructorNames: selectedNames,
      );

      if (success && mounted) {
        Navigator.of(context).pop();
        widget.onUpdated?.call();
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  selectedInstructorIds.isEmpty
                      ? 'Для заняття "${_lesson.title}" очищено список викладачів'
                      : 'Для заняття "${_lesson.title}" оновлено список викладачів',
                ),
                backgroundColor: Colors.green,
              ),
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Помилка призначення: $e'),
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

  Future<void> _unassignInstructor() async {
    setState(() => _isLoading = true);

    try {
      final success = await _calendarService.unassignLessonInstructor(
        _lesson.id,
      );

      if (success && mounted) {
        Navigator.of(context).pop();
        widget.onUpdated?.call();
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Викладача з заняття "${_lesson.title}" знято'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Помилка зняття викладача: $e'),
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
          _lesson.startTime.year,
          _lesson.startTime.month,
          _lesson.startTime.day,
        ),
        initialStartTime: TimeOfDay.fromDateTime(_lesson.startTime),
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
        _lesson.createdBy == currentUser?.uid;
  }

  Future<void> _registerForLesson() async {
    setState(() => _isLoading = true);

    try {
      final success = await _calendarService.registerForLesson(_lesson.id);
      if (success && mounted) {
        setState(() => _isRegistered = true);
        widget.onUpdated?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Успішно зареєстровано на заняття "${_lesson.title}"',
            ),
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
      final success = await _calendarService.unregisterFromLesson(_lesson.id);
      if (success && mounted) {
        setState(() => _isRegistered = false);
        widget.onUpdated?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Реєстрацію на заняття "${_lesson.title}" скасовано'),
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
    Navigator.of(context).pop(); // Закриваємо поточний діалог
    showDialog(
      context: context,
      builder: (context) => LessonFormDialog(
        lesson: _lesson, // 👈 передаємо заняття для редагування
        onSaved: () {
          widget.onUpdated?.call(); // 👈 оновлюємо календар
        },
      ),
    );
  }

  void _duplicateLesson() {
    Navigator.of(context).pop();
    showDialog(
      context: context,
      builder: (context) => LessonFormDialog(
        initialDate: DateTime(
          _lesson.startTime.year,
          _lesson.startTime.month,
          _lesson.startTime.day + 7,
        ),
        initialStartTime: TimeOfDay.fromDateTime(_lesson.startTime),
        templateData: {
          // 👈 ДОДАТИ дані для автозаповнення
          'title': _lesson.title,
          'description': _lesson.description,
          'location': _lesson.location,
          'unit': _lesson.unit,
          'instructorId': _lesson.instructorId,
          'instructorName': _lesson.instructorName,
          'instructorIds': _lesson.instructorIds,
          'instructorNames': _lesson.instructorNames,
          'tags': _lesson.tags,
          'durationMinutes': _lesson.endTime
              .difference(_lesson.startTime)
              .inMinutes,
        },
        onSaved: () {
          widget.onUpdated?.call();
        },
      ),
    );
  }

  void _deleteLesson() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Видалити заняття'),
        content: Text(
          'Ви впевнені, що хочете видалити заняття "${_lesson.title}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Скасувати'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop(); // Закриваємо діалог підтвердження
              Navigator.of(context).pop(); // Закриваємо діалог деталей

              // 👈 ДОДАТИ індикатор завантаження
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Text('Видалення заняття...'),
                    ],
                  ),
                  duration: Duration(seconds: 2),
                ),
              );

              final success = await _calendarService.deleteLesson(_lesson.id);

              if (success && mounted) {
                // 👈 Оновлюємо календар
                widget.onUpdated?.call();

                // Показуємо повідомлення про успіх
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Заняття "${_lesson.title}" видалено'),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 3),
                  ),
                );
              } else if (mounted) {
                // Показуємо помилку
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Помилка видалення заняття'),
                    backgroundColor: Colors.red,
                    duration: Duration(seconds: 3),
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

  Map<String, String> _availableInstructorOptions() {
    final options = <String, String>{};

    for (var i = 0; i < _lesson.instructorIds.length; i++) {
      final id = _lesson.instructorIds[i];
      if (id.isEmpty) continue;
      final name = i < _lesson.instructorNames.length
          ? _lesson.instructorNames[i]
          : _lesson.instructorName;
      options[id] = name.isNotEmpty ? name : id;
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

  Future<void> _acknowledgeLesson() async {
    setState(() => _isLoading = true);

    try {
      final success = await _calendarService.acknowledgeLesson(_lesson.id);
      if (!success) {
        throw Exception('Не вдалося зберегти підтвердження');
      }

      final refreshedLesson = await _calendarService.getLessonById(_lesson.id);
      if (mounted) {
        setState(() {
          if (refreshedLesson != null) {
            _lesson = refreshedLesson;
          }
        });
        widget.onUpdated?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ознайомлення з заняттям підтверджено'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Помилка підтвердження: $e'),
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

  List<String> _identityCandidatesForInstructor(String assignmentId) {
    final candidates = <String>[assignmentId];

    for (final member in _availableInstructors) {
      final memberAssignmentId = _memberAssignmentId(member);
      if (memberAssignmentId != assignmentId) continue;

      final email = ((member['email'] as String?) ?? '').trim();
      if (email.isNotEmpty) {
        candidates.add(email);
      }
    }

    return candidates;
  }

  bool _shouldShowCurrentUserAcknowledgementSection(LessonModel lesson) {
    final assignmentId = _calendarService.getCurrentUserAssignmentIdForLesson(
      lesson,
    );
    if (assignmentId == null) return false;

    final status = LessonStatusUtils.getAcknowledgementStatusForInstructor(
      lesson,
      instructorAssignmentId: assignmentId,
      instructorIdentityCandidates: _calendarService
          .getCurrentUserAssignmentCandidates(),
    );

    return status != LessonAcknowledgementStatus.notRequired;
  }
}
