import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/feedback_service.dart';
import '../theme/app_theme.dart';

class FeedbackDialog extends StatefulWidget {
  const FeedbackDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const FeedbackDialog(),
    );
  }

  @override
  State<FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<FeedbackDialog> {
  final _feedbackService = FeedbackService();
  final _descriptionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  FeedbackCategory _category = FeedbackCategory.bug;
  FeedbackPriority _priority = FeedbackPriority.medium;
  bool _isSending = false;
  bool _sent = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSending = true);

    try {
      final info = await PackageInfo.fromPlatform();
      await _feedbackService.submitFeedback(
        category: _category,
        priority: _category == FeedbackCategory.bug ? _priority : null,
        description: _descriptionController.text,
        appVersion: '${info.version}+${info.buildNumber}',
      );
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Помилка надсилання: $e'),
            backgroundColor: AppTheme.dangerRed,
          ),
        );
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: _sent ? _buildSuccessView() : _buildFormView(),
      ),
    );
  }

  Widget _buildSuccessView() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, size: 56, color: AppTheme.secondaryGreen),
          const SizedBox(height: 16),
          const Text(
            'Дякуємо!',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Ваш відгук отримано. Розробник розгляне його найближчим часом.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Закрити'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormView() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок
            Row(
              children: [
                const Icon(Icons.headset_mic_outlined),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Зв\'язок з підтримкою',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  onPressed: _isSending ? null : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Тип відгуку
            const Text(
              'Тип звернення',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 8),
            _CategorySelector(
              selected: _category,
              onChanged: (c) => setState(() => _category = c),
            ),
            const SizedBox(height: 16),

            // Критичність (тільки для багів)
            if (_category == FeedbackCategory.bug) ...[
              const Text(
                'Критичність',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 8),
              _PrioritySelector(
                selected: _priority,
                onChanged: (p) => setState(() => _priority = p),
              ),
              const SizedBox(height: 16),
            ],

            // Опис
            Text(
              _descriptionHint,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descriptionController,
              minLines: 4,
              maxLines: 7,
              maxLength: 1000,
              enabled: !_isSending,
              decoration: InputDecoration(
                hintText: _descriptionPlaceholder,
                alignLabelWithHint: true,
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Будь ласка, опишіть проблему або пропозицію';
                if (v.trim().length < 10) return 'Опис занадто короткий';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Кнопки
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isSending ? null : () => Navigator.of(context).pop(),
                  child: const Text('Скасувати'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _isSending ? null : _submit,
                  icon: _isSending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send_outlined, size: 18),
                  label: const Text('Надіслати'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String get _descriptionHint {
    switch (_category) {
      case FeedbackCategory.bug:
        return 'Опис помилки';
      case FeedbackCategory.feature:
        return 'Опис пропозиції';
      case FeedbackCategory.other:
        return 'Ваше повідомлення';
    }
  }

  String get _descriptionPlaceholder {
    switch (_category) {
      case FeedbackCategory.bug:
        return 'Що сталось? Як відтворити? Що очікувалось?';
      case FeedbackCategory.feature:
        return 'Яку функцію хочете додати? Як це мало б працювати?';
      case FeedbackCategory.other:
        return 'Ваше повідомлення...';
    }
  }
}

// ─── Вибір категорії ──────────────────────────────────────────────────────────

class _CategorySelector extends StatelessWidget {
  final FeedbackCategory selected;
  final ValueChanged<FeedbackCategory> onChanged;

  const _CategorySelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _chip(context, FeedbackCategory.bug, Icons.bug_report_outlined, 'Баг'),
        const SizedBox(width: 8),
        _chip(context, FeedbackCategory.feature, Icons.lightbulb_outline, 'Пропозиція'),
        const SizedBox(width: 8),
        _chip(context, FeedbackCategory.other, Icons.chat_bubble_outline, 'Інше'),
      ],
    );
  }

  Widget _chip(BuildContext context, FeedbackCategory cat, IconData icon, String label) {
    final isSelected = selected == cat;
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(cat),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? colorScheme.primary.withOpacity(0.15) : colorScheme.surface,
            border: Border.all(
              color: isSelected ? colorScheme.primary : colorScheme.outline.withOpacity(0.4),
              width: isSelected ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.6),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Вибір критичності ────────────────────────────────────────────────────────

class _PrioritySelector extends StatelessWidget {
  final FeedbackPriority selected;
  final ValueChanged<FeedbackPriority> onChanged;

  const _PrioritySelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _pill(context, FeedbackPriority.low, 'Низька', AppTheme.secondaryGreen),
        const SizedBox(width: 8),
        _pill(context, FeedbackPriority.medium, 'Середня', AppTheme.warningOrange),
        const SizedBox(width: 8),
        _pill(context, FeedbackPriority.high, 'Критична', AppTheme.dangerRed),
      ],
    );
  }

  Widget _pill(BuildContext context, FeedbackPriority p, String label, Color color) {
    final isSelected = selected == p;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(p),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.2) : Colors.transparent,
            border: Border.all(
              color: isSelected ? color : color.withOpacity(0.3),
              width: isSelected ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected ? color : color.withOpacity(0.6),
            ),
          ),
        ),
      ),
    );
  }
}
