import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../globals.dart';
import '../services/auth_service.dart';
import '../services/web_push_environment.dart';

class DriveSessionBanner extends StatefulWidget {
  const DriveSessionBanner({super.key, required this.onReconnected});

  final VoidCallback onReconnected;

  @override
  State<DriveSessionBanner> createState() => _DriveSessionBannerState();
}

class _DriveSessionBannerState extends State<DriveSessionBanner> {
  bool _reconnecting = false;
  bool _signingIn = false;

  bool get _isIosStandalonePwa =>
      WebPushEnvironment.isIosBrowser &&
      WebPushEnvironment.isStandaloneDisplayMode;

  // Derived from the notifier — updates whenever Drive session drops or recovers.
  bool get _visible => !AuthService.driveSessionAvailable.value;

  @override
  void initState() {
    super.initState();
    AuthService.driveSessionAvailable.addListener(_onSessionChanged);
  }

  @override
  void dispose() {
    AuthService.driveSessionAvailable.removeListener(_onSessionChanged);
    super.dispose();
  }

  void _onSessionChanged() => setState(() {});

  Future<void> _reconnect() async {
    setState(() => _reconnecting = true);
    final result = await Globals.authService.reconnectDriveWithDetails();
    if (!mounted) return;

    setState(() => _reconnecting = false);
    if (result.success) {
      widget.onReconnected();
    } else {
      Globals.errorNotificationManager.showError(
        result.message ??
            'Не вдалося підключитися до Google Drive. Перевірте підключення та спробуйте знову.',
      );
    }
  }

  Future<void> _signInToDrive() async {
    setState(() => _signingIn = true);
    final result = await Globals.authService.reconnectDriveWithDetails(
      interactiveOnly: true,
    );
    if (!mounted) return;

    setState(() => _signingIn = false);
    if (result.success) {
      widget.onReconnected();
    } else {
      Globals.errorNotificationManager.showError(
        result.message ?? 'Не вдалося увійти в Google Drive. Спробуйте ще раз.',
      );
    }
  }

  Future<void> _openInSafari() async {
    final reconnectUri = Uri.base.replace(
      queryParameters: <String, String>{
        ...Uri.base.queryParameters,
        'driveReconnect': '1',
      },
    );

    final launched = await launchUrl(
      reconnectUri,
      mode: LaunchMode.externalApplication,
    );

    if (!launched && mounted) {
      Globals.errorNotificationManager.showError(
        'Не вдалося відкрити Safari. Скопіюйте адресу сторінки та відкрийте її у браузері вручну.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.amber.shade100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cloud_off, size: 18, color: Colors.amber),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _isIosStandalonePwa
                      ? 'Google Drive сесія не відновлена. У режимі додатка з домашнього екрана iPhone повторний вхід може не спрацювати.'
                      : 'Google Drive сесія не відновлена — файли можуть бути недоступні',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (_reconnecting || _signingIn)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (_isIosStandalonePwa) ...[
                // On iOS PWA, OAuth popups are blocked — only show Safari option.
                ElevatedButton.icon(
                  onPressed: _openInSafari,
                  icon: const Icon(Icons.open_in_browser, size: 16),
                  label: const Text('Відкрити в Safari'),
                ),
              ] else ...[
                TextButton(
                  onPressed: _reconnect,
                  child: const Text('Поновити зв\'язок'),
                ),
                OutlinedButton(
                  onPressed: _signInToDrive,
                  child: const Text('Увійти в Google Drive'),
                ),
              ],
            ],
          ),
          if (_isIosStandalonePwa) ...[
            const SizedBox(height: 4),
            const Text(
              'Відкрийте у Safari, підключіть Google Drive, а потім поверніться до додатка.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}
