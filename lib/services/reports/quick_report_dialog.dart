import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
              title: 'Останній тиждень',
              subtitle: _getDateRangeText('week'),
            ),
            _buildPeriodOption(
              value: 'month',
              title: 'Останній місяць',
              subtitle: _getDateRangeText('month'),
            ),
            _buildPeriodOption(
              value: 'quarter',
              title: 'Останній квартал',
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
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade600,
        ),
      ),
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }

  Widget _buildCustomDatePickers() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border.all(color: Colors.grey.shade300),
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
                    const Text(
                      'Початкова дата:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
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
                    const Text(
                      'Кінцева дата:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
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
                  customEndDate = DateTime(now.year, now.month, 0); // Останній день минулого місяця
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
      ),
      child: Text(label),
    );
  }

  String _getDateRangeText(String period) {
    final now = DateTime.now();
    final formatter = DateFormat('dd.MM.yyyy');
    
    switch (period) {
      case 'week':
        final startDate = now.subtract(const Duration(days: 7));
        return '${formatter.format(startDate)} - ${formatter.format(now)}';
      case 'month':
        final startDate = DateTime(now.year, now.month - 1, now.day);
        return '${formatter.format(startDate)} - ${formatter.format(now)}';
      case 'quarter':
        final startDate = now.subtract(const Duration(days: 90));
        return '${formatter.format(startDate)} - ${formatter.format(now)}';
      default:
        return '';
    }
  }

  Future<void> _selectCustomStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: customStartDate ?? DateTime.now().subtract(const Duration(days: 30)),
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
      firstDate: customStartDate ?? DateTime.now().subtract(const Duration(days: 365 * 2)),
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
    final now = DateTime.now();
    DateTime startDate, endDate;

    switch (selectedPeriod) {
      case 'week':
        startDate = now.subtract(const Duration(days: 7));
        endDate = now;
        break;
      case 'month':
        startDate = DateTime(now.year, now.month - 1, now.day);
        endDate = now;
        break;
      case 'quarter':
        startDate = now.subtract(const Duration(days: 90));
        endDate = now;
        break;
      case 'custom':
        startDate = customStartDate!;
        endDate = customEndDate!;
        break;
      default:
        return;
    }

    Navigator.pop(context);
    widget.onGenerate(startDate, endDate);
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
    builder: (context) => QuickReportDialog(
      reportTitle: reportTitle,
      onGenerate: onGenerate,
    ),
  );
}