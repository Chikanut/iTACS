import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../globals.dart';
import '../services/web_push_environment.dart';

class DriveSessionBanner extends StatefulWidget {
  const DriveSessionBanner({super.key, required this.onReconnected});

  final VoidCallback onReconnected;

  @override
  State<DriveSessionBanner> createState() => _DriveSessionBannerState();
}

class _DriveSessionBannerState extends State<DriveSessionBanner> {
  bool _visible = false;
  bool _reconnecting = false;
  bool _showBrowserFallback = false;

  bool get _isIosStandalonePwa =>
      WebPushEnvironment.isIosBrowser &&
      WebPushEnvironment.isStandaloneDisplayMode;

  @override
  void initState() {
    super.initState();
    _visible = !Globals.authService.isDriveSessionAvailable;
    _showBrowserFallback =
        _visible &&
        Globals.authService.requiresBrowserFallbackForDriveReconnect;
  }

  Future<void> _reconnect() async {
    setState(() => _reconnecting = true);
    final result = await Globals.authService.reconnectDriveWithDetails();
    if (!mounted) return;

    if (result.success) {
      setState(() {
        _visible = false;
        _reconnecting = false;
        _showBrowserFallback = false;
      });
      widget.onReconnected();
    } else {
      setState(() {
        _reconnecting = false;
        _showBrowserFallback = result.requiresBrowserFallback;
      });
      Globals.errorNotificationManager.showError(
        result.message ??
            'Не вдалося підключитися до Google Drive. Перевірте підключення та спробуйте знову.',
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
                  _showBrowserFallback && _isIosStandalonePwa
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
              if (_reconnecting)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                TextButton(
                  onPressed: _reconnect,
                  child: Text(
                    _showBrowserFallback && _isIosStandalonePwa
                        ? 'Спробувати ще раз'
                        : 'Поновити зв\'язок',
                  ),
                ),
              if (_showBrowserFallback && _isIosStandalonePwa)
                OutlinedButton(
                  onPressed: _openInSafari,
                  child: const Text('Відкрити в Safari'),
                ),
            ],
          ),
          if (_showBrowserFallback && _isIosStandalonePwa) ...[
            const SizedBox(height: 4),
            const Text(
              'Після відкриття в Safari повторно увійдіть у Google Drive, а потім поверніться до додатка.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}
