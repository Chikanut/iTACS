import 'package:flutter/material.dart';
import '../../../models/instructor_absence.dart';

class AbsenceGridCell extends StatelessWidget {
  final DateTime date;
  final String instructorId;
  final String instructorName;
  final InstructorAbsence? absence;
  final bool hasLessons;
  final VoidCallback onTap;

  const AbsenceGridCell({
    super.key,
    required this.date,
    required this.instructorId,
    required this.instructorName,
    required this.absence,
    required this.hasLessons,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.grey.shade300,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(4),
          color: _getBackgroundColor(),
        ),
        child: Stack(
          children: [
            // Основний контент
            Center(
              child: Text(
                _getDisplayText(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: absence?.isAdminAssignment == true 
                      ? FontWeight.bold 
                      : FontWeight.normal,
                  color: _getTextColor(),
                ),
                textAlign: TextAlign.center,
              ),
            ),
            
            // Індикатор статусу для запитів
            if (absence != null && absence!.status == AbsenceStatus.pending)
              Positioned(
                top: 2,
                right: 2,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Colors.orange,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getDisplayText() {
    // Якщо є відсутність, показуємо її символ
    if (absence != null) {
      return absence!.shortSymbol;
    }
    
    // Якщо є заняття, показуємо "З"
    if (hasLessons) {
      return 'З';
    }
    
    // Інакше порожня клітинка
    return '';
  }

  Color _getBackgroundColor() {
    // Якщо є відсутність, використовуємо її колір
    if (absence != null) {
      return absence!.displayColor.withOpacity(0.2);
    }
    
    // Якщо є заняття, легкий синій фон
    if (hasLessons) {
      return Colors.blue.shade50;
    }
    
    // Вихідні дні - легкий сірий фон
    if (_isWeekend()) {
      return Colors.grey.shade100;
    }
    
    // Звичайний день - білий фон
    return Colors.white;
  }

  Color _getTextColor() {
    // Якщо є відсутність, використовуємо її колір
    if (absence != null) {
      return absence!.displayColor;
    }
    
    // Якщо є заняття, синій текст
    if (hasLessons) {
      return Colors.blue.shade700;
    }
    
    // Вихідні дні - сірий текст
    if (_isWeekend()) {
      return Colors.grey.shade600;
    }
    
    // Звичайний день - чорний текст
    return Colors.black87;
  }

  bool _isWeekend() {
    return date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
  }
}