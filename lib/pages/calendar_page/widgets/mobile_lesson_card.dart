// lib/pages/calendar_page/widgets/mobile_lesson_card.dart

import 'package:flutter/material.dart';
import '../../../models/lesson_model.dart';
import '../calendar_utils.dart';
import '../../../services/calendar_service.dart';

class MobileLessonCard extends StatelessWidget {
  final LessonModel lesson;
  final VoidCallback? onTap;

  const MobileLessonCard({
    super.key,
    required this.lesson,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final start = TimeOfDay.fromDateTime(lesson.startTime);
    final end = TimeOfDay.fromDateTime(lesson.endTime);
    final calendarService = CalendarService();
    final isRegistered = calendarService.isUserRegisteredForLesson(lesson);
    final color = CalendarUtils.getGroupColor(lesson.groupName);
    
    // Отримуємо статуси та прогрес
    final progressStatus = LessonStatusUtils.getProgressStatus(lesson);
    final readinessStatus = LessonStatusUtils.getReadinessStatus(lesson);
    final criticalFieldsProgress = LessonStatusUtils.getCriticalFieldsProgress(lesson);
    final missingFields = LessonStatusUtils.getMissingCriticalFields(lesson);
    
    // Для відображення використовуємо readinessStatus
    final statusColor = readinessStatus.color;
    final statusLabel = readinessStatus.label;
    final statusIcon = readinessStatus.icon;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        CalendarUtils.getLessonTypeIcon(
                          lesson.tags.isNotEmpty ? lesson.tags.first : ''
                        ),
                        size: 20,
                        color: Colors.grey.shade700,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          lesson.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color.fromARGB(255, 26, 25, 25),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Icon(
                      statusIcon,
                      size: 16,
                      color: statusColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${CalendarUtils.formatTime(start)} - ${CalendarUtils.formatTime(end)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Прогрес-бар заповнення критичних полів
            if (missingFields.isNotEmpty) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: criticalFieldsProgress,
                            backgroundColor: Colors.grey.shade300,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              criticalFieldsProgress == 1.0 
                                ? Colors.green 
                                : criticalFieldsProgress >= 0.6 
                                  ? Colors.orange 
                                  : Colors.red,
                            ),
                            minHeight: 6,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${(criticalFieldsProgress * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Не заповнено: ${missingFields.join(', ')}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            
            // Інформація про групу
            Row(
              children: [
                Icon(
                  Icons.group,
                  size: 16,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  lesson.groupName,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            
            // Інструктор
            Row(
              children: [
                Icon(
                  Icons.person,
                  size: 16,
                  color: lesson.instructorId.isEmpty ? Colors.red.shade600 : Colors.grey.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  lesson.instructorId.isEmpty ? 'Викладач не призначений' : lesson.instructorName,
                  style: TextStyle(
                    fontSize: 14,
                    color: lesson.instructorId.isEmpty 
                      ? Colors.red.shade700 
                      : Colors.grey.shade700,
                    fontWeight: lesson.instructorId.isEmpty 
                      ? FontWeight.w600 
                      : FontWeight.normal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            
            // Локація
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  size: 16,
                  color: lesson.location.isEmpty ? Colors.red.shade600 : Colors.grey.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  lesson.location.isEmpty ? 'Місце не вказано' : lesson.location,
                  style: TextStyle(
                    fontSize: 14,
                    color: lesson.location.isEmpty 
                      ? Colors.red.shade700 
                      : Colors.grey.shade700,
                    fontWeight: lesson.location.isEmpty 
                      ? FontWeight.w600 
                      : FontWeight.normal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            
            // Підрозділ
            if (lesson.unit.isEmpty) ...[
              Row(
                children: [
                  Icon(
                    Icons.military_tech,
                    size: 16,
                    color: Colors.red.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Підрозділ не вказано',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ] else ...[
              Row(
                children: [
                  Icon(
                    Icons.military_tech,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      lesson.unit,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],
            
            // Період навчання
            if (lesson.trainingPeriod.isEmpty) ...[
              Row(
                children: [
                  Icon(
                    Icons.date_range,
                    size: 16,
                    color: Colors.red.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Період навчання не вказано',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ] else ...[
              Row(
                children: [
                  Icon(
                    Icons.date_range,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Період навчання: ${LessonStatusUtils.formatTrainingPeriod(lesson.trainingPeriod)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],
            
            // Кількість учнів
            Row(
              children: [
                Icon(
                  Icons.groups,
                  size: 16,
                  color: lesson.maxParticipants <= 0 ? Colors.red.shade600 : Colors.grey.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  lesson.maxParticipants <= 0 
                    ? 'Кількість учнів не вказана' 
                    : '${lesson.maxParticipants} учнів',
                  style: TextStyle(
                    fontSize: 14,
                    color: lesson.maxParticipants <= 0 
                      ? Colors.red.shade700 
                      : Colors.grey.shade700,
                    fontWeight: lesson.maxParticipants <= 0 
                      ? FontWeight.w600 
                      : FontWeight.normal,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Статус заняття
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Прогрес заняття
                if (progressStatus != LessonProgressStatus.scheduled) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: progressStatus == LessonProgressStatus.inProgress
                        ? Colors.blue.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          progressStatus.icon,
                          size: 12,
                          color: progressStatus == LessonProgressStatus.inProgress
                            ? Colors.blue
                            : Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          progressStatus.label,
                          style: TextStyle(
                            fontSize: 10,
                            color: progressStatus == LessonProgressStatus.inProgress
                              ? Colors.blue
                              : Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                // Статус готовності
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 10,
                      color: statusColor.withOpacity(0.8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            
            // Теги
            if (lesson.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: lesson.tags.take(3).map((tag) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}