import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';

class QuickReportDialog extends StatefulWidget {
  final String reportTitle;
  final Function(DateTime startDate, DateTime endDate) onGenerate;

  const QuickReportDialog({
    super.key,
    required this.reportTitle,
    required this.onGenerate,
  });

  @override
  State<QuickReportDialog> createState() => _QuickReportDialogState();
}

class _QuickReportDialogState extends State<QuickReportDialog> {
  String selectedPeriod = 'month'; // week, month, quarter, custom
  DateTime? customStartDate;
  DateTime? customEndDate;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок
            Row(
              children: [
                Icon(Icons.schedule, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Період для "${widget.reportTitle}"',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Вибір періоду
            const Text(
              'Оберіть період:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),

            // Радіо кнопки для стандартних періодів
            _buildPeriodOption(
              value: 'week',
              title: 'Календарний тиждень',
              subtitle: _getDateRangeText('week'),
            ),
            _buildPeriodOption(
              value: 'month',
              title: 'Календарний місяць',
              subtitle: _getDateRangeText('month'),
            ),
            _buildPeriodOption(
              value: 'quarter',
              title: 'Календарний квартал',
              subtitle: _getDateRangeText('quarter'),
            ),
            _buildPeriodOption(
              value: 'custom',
              title: 'Довільний період',
              subtitle: customStartDate != null && customEndDate != null
                  ? '${DateFormat('dd.MM.yyyy').format(customStartDate!)} - ${DateFormat('dd.MM.yyyy').format(customEndDate!)}'
                  : 'Оберіть дати',
            ),

            // Кастомний період
            if (selectedPeriod == 'custom') ...[
              const SizedBox(height: 16),
              _buildCustomDatePickers(),
            ],

            const SizedBox(height: 24),

            // Кнопки
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Скасувати'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _canGenerate() ? _onGenerate : null,
                  icon: const Icon(Icons.file_download, size: 18),
                  label: const Text('Генерувати'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodOption({
    required String value,
    required String title,
    required String subtitle,
  }) {
    return RadioListTile<String>(
      value: value,
      groupValue: selectedPeriod,
      onChanged: (value) {
        setState(() {
          selectedPeriod = value!;
          if (value != 'custom') {
            customStartDate = null;
            customEndDate = null;
          }
        });
      },
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      ),
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }

  Widget _buildCustomDatePickers() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceOverlay,
        border: Border.all(color: AppTheme.borderSubtle),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Початкова дата:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    OutlinedButton.icon(
                      onPressed: _selectCustomStartDate,
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(
                        customStartDate != null
                            ? DateFormat('dd.MM.yyyy').format(customStartDate!)
                            : 'Оберіть',
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 32),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        foregroundColor: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Кінцева дата:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    OutlinedButton.icon(
                      onPressed: _selectCustomEndDate,
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(
                        customEndDate != null
                            ? DateFormat('dd.MM.yyyy').format(customEndDate!)
                            : 'Оберіть',
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 32),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        foregroundColor: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Швидкі кнопки для кастомного періоду
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            children: [
              _buildQuickCustomButton('Цей місяць', () {
                final now = DateTime.now();
                setState(() {
                  customStartDate = DateTime(now.year, now.month, 1);
                  customEndDate = now;
                });
              }),
              _buildQuickCustomButton('Минулий місяць', () {
                final now = DateTime.now();
                final lastMonth = DateTime(now.year, now.month - 1, 1);
                setState(() {
                  customStartDate = lastMonth;
                  customEndDate = DateTime(
                    now.year,
                    now.month,
                    0,
                  ); // Останній день минулого місяця
                });
              }),
              _buildQuickCustomButton('Цей рік', () {
                final now = DateTime.now();
                setState(() {
                  customStartDate = DateTime(now.year, 1, 1);
                  customEndDate = now;
                });
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickCustomButton(String label, VoidCallback onPressed) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        textStyle: const TextStyle(fontSize: 11),
        foregroundColor: AppTheme.textPrimary,
      ),
      child: Text(label),
    );
  }

  String _getDateRangeText(String period) {
    final formatter = DateFormat('dd.MM.yyyy');
    final range = _resolvePeriodRange(period);

    if (range == null) {
      return '';
    }

    return '${_getCalendarPeriodLabel(period, range.$1)}: ${formatter.format(range.$1)} - ${formatter.format(range.$2)}';
  }

  Future<void> _selectCustomStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate:
          customStartDate ?? DateTime.now().subtract(const Duration(days: 30)),
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 2)),
      lastDate: customEndDate ?? DateTime.now(),
      locale: const Locale('uk'),
    );

    if (date != null) {
      setState(() {
        customStartDate = date;
        // Якщо кінцева дата раніше початкової - скидаємо її
        if (customEndDate != null && customEndDate!.isBefore(date)) {
          customEndDate = null;
        }
      });
    }
  }

  Future<void> _selectCustomEndDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: customEndDate ?? DateTime.now(),
      firstDate:
          customStartDate ??
          DateTime.now().subtract(const Duration(days: 365 * 2)),
      lastDate: DateTime.now(),
      locale: const Locale('uk'),
    );

    if (date != null) {
      setState(() {
        customEndDate = date;
      });
    }
  }

  bool _canGenerate() {
    if (selectedPeriod == 'custom') {
      return customStartDate != null && customEndDate != null;
    }
    return true;
  }

  void _onGenerate() {
    final range = selectedPeriod == 'custom'
        ? (customStartDate!, customEndDate!)
        : _resolvePeriodRange(selectedPeriod);

    if (range == null) {
      return;
    }

    Navigator.pop(context);
    widget.onGenerate(range.$1, range.$2);
  }

  (DateTime, DateTime)? _resolvePeriodRange(String period) {
    final now = DateTime.now();

    switch (period) {
      case 'week':
        final startDate = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: now.weekday - 1));
        return (startDate, startDate.add(const Duration(days: 6)));
      case 'month':
        return (
          DateTime(now.year, now.month, 1),
          DateTime(now.year, now.month + 1, 0),
        );
      case 'quarter':
        final quarterStartMonth = ((now.month - 1) ~/ 3) * 3 + 1;
        return (
          DateTime(now.year, quarterStartMonth, 1),
          DateTime(now.year, quarterStartMonth + 3, 0),
        );
      default:
        return null;
    }
  }

  String _getCalendarPeriodLabel(String period, DateTime startDate) {
    switch (period) {
      case 'week':
        final weekNumber =
            ((startDate.difference(DateTime(startDate.year, 1, 1)).inDays) ~/
                7) +
            1;
        return 'Календарний тиждень №$weekNumber';
      case 'month':
        return 'Календарний місяць ${DateFormat('MMMM', 'uk').format(startDate)}';
      case 'quarter':
        final quarterNumber = ((startDate.month - 1) ~/ 3) + 1;
        return 'Календарний квартал Q$quarterNumber';
      default:
        return '';
    }
  }
}

// Функція для показу діалогу
Future<void> showQuickReportDialog({
  required BuildContext context,
  required String reportTitle,
  required Function(DateTime startDate, DateTime endDate) onGenerate,
}) {
  return showDialog(
    context: context,
    builder: (context) =>
        QuickReportDialog(reportTitle: reportTitle, onGenerate: onGenerate),
  );
}
