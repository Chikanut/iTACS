import "package:flutter/foundation.dart";
import "package:flutter/material.dart";

import "../services/web_push_environment.dart";
import "../theme/app_theme.dart";

class WebPushInstallBanner extends StatefulWidget {
  const WebPushInstallBanner({super.key});

  @override
  State<WebPushInstallBanner> createState() => _WebPushInstallBannerState();
}

class _WebPushInstallBannerState extends State<WebPushInstallBanner> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb ||
        _dismissed ||
        !WebPushEnvironment.shouldShowIosInstallBanner) {
      return const SizedBox.shrink();
    }

    final colors = AppTheme.statusColors(AppStatusTone.info);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border.withOpacity(0.75)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.add_to_home_screen, color: colors.border),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Push на iPhone працюють після встановлення на головний екран",
                      style: TextStyle(
                        color: colors.foreground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Відкрийте меню Safari, натисніть «Поділитися» і виберіть «На початковий екран». Після цього відкрийте iTACS уже з іконки та дозвольте сповіщення.",
                      style: TextStyle(color: colors.foreground),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: "Приховати",
                onPressed: () => setState(() => _dismissed = true),
                icon: Icon(Icons.close, color: colors.badge),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _showHowToDialog,
                icon: const Icon(Icons.info_outline),
                label: const Text("Покроково"),
              ),
              FilledButton.icon(
                onPressed: () => setState(() => _dismissed = true),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text("Зрозуміло"),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showHowToDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Як увімкнути push на iPhone"),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("1. Відкрийте iTACS у Safari."),
            SizedBox(height: 8),
            Text("2. Натисніть «Поділитися»."),
            SizedBox(height: 8),
            Text("3. Оберіть «На початковий екран»."),
            SizedBox(height: 8),
            Text("4. Запустіть iTACS з нової іконки на екрані."),
            SizedBox(height: 8),
            Text(
              "5. Коли браузер або застосунок попросить дозвіл на сповіщення, натисніть «Дозволити».",
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Добре"),
          ),
        ],
      ),
    );
  }
}
