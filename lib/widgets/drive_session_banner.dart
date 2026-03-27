import 'package:flutter/material.dart';
import '../globals.dart';

class DriveSessionBanner extends StatefulWidget {
  const DriveSessionBanner({super.key, required this.onReconnected});

  final VoidCallback onReconnected;

  @override
  State<DriveSessionBanner> createState() => _DriveSessionBannerState();
}

class _DriveSessionBannerState extends State<DriveSessionBanner> {
  bool _visible = false;
  bool _reconnecting = false;

  @override
  void initState() {
    super.initState();
    _visible = !Globals.authService.isDriveSessionAvailable;
  }

  Future<void> _reconnect() async {
    setState(() => _reconnecting = true);
    final success = await Globals.authService.reconnectDrive();
    if (!mounted) return;

    if (success) {
      setState(() {
        _visible = false;
        _reconnecting = false;
      });
      widget.onReconnected();
    } else {
      setState(() => _reconnecting = false);
      Globals.errorNotificationManager.showError(
        'Не вдалося підключитися до Google Drive. Перевірте підключення та спробуйте знову.',
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
      child: Row(
        children: [
          const Icon(Icons.cloud_off, size: 18, color: Colors.amber),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Google Drive сесія не відновлена — файли можуть бути недоступні',
              style: TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          _reconnecting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : TextButton(
                  onPressed: _reconnect,
                  child: const Text('Поновити зв\'язок'),
                ),
        ],
      ),
    );
  }
}
