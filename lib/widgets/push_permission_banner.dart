import "package:flutter/foundation.dart";
import "package:flutter/material.dart";

import "../globals.dart";
import "../theme/app_theme.dart";

/// Shown on iOS PWA (standalone) when the user has not yet granted
/// notification permission. iOS requires the permission request to originate
/// directly from a user gesture, so we cannot call requestPermission()
/// automatically at startup.
class PushPermissionBanner extends StatefulWidget {
  const PushPermissionBanner({super.key});

  @override
  State<PushPermissionBanner> createState() => _PushPermissionBannerState();
}

class _PushPermissionBannerState extends State<PushPermissionBanner> {
  bool _requesting = false;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    Globals.pushNotificationsService.addListener(_onServiceChanged);
  }

  @override
  void dispose() {
    Globals.pushNotificationsService.removeListener(_onServiceChanged);
    super.dispose();
  }

  void _onServiceChanged() => setState(() {});

  Future<void> _enableNotifications() async {
    setState(() => _requesting = true);
    // Must be called directly from a button tap — iOS checks for user gesture.
    await Globals.pushNotificationsService.requestPermissionInteractively();
    if (mounted) {
      setState(() => _requesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb ||
        _dismissed ||
        !Globals.pushNotificationsService.needsIosPermissionPrompt) {
      return const SizedBox.shrink();
    }

    final colors = AppTheme.statusColors(AppStatusTone.warning);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border.withOpacity(0.75)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.notifications_off_outlined, color: colors.border),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Сповіщення вимкнені",
                  style: TextStyle(
                    color: colors.foreground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Натисніть, щоб дозволити сповіщення від iTACS.",
                  style: TextStyle(color: colors.foreground, fontSize: 13),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: _requesting ? null : _enableNotifications,
                  icon: _requesting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.notifications_active_outlined,
                          size: 16,
                        ),
                  label: Text(
                    _requesting ? "Очікування…" : "Увімкнути сповіщення",
                  ),
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
    );
  }
}
