import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../globals.dart';
import '../../../models/group_notification.dart';

class NotificationsTab extends StatefulWidget {
  const NotificationsTab({super.key});

  @override
  State<NotificationsTab> createState() => _NotificationsTabState();
}

class _NotificationsTabState extends State<NotificationsTab> {
  List<GroupNotification> _notifications = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    final notifications = await Globals.groupNotificationsService
        .getAllNotificationsForCurrentGroup();

    if (!mounted) return;
    setState(() {
      _notifications = notifications;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _notifications.where((item) => item.isActive).length;
    final isCompactLayout = MediaQuery.of(context).size.width < 600;

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, isCompactLayout ? 12 : 16, 16, 8),
          child: isCompactLayout
              ? Row(
                  children: [
                    Expanded(
                      child: _NotificationStatCard(
                        icon: Icons.notifications_active_outlined,
                        title: 'Активні',
                        value: '$activeCount',
                        subtitle: 'Видимі на головній',
                        compact: true,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _isSaving
                            ? null
                            : _showCreateNotificationDialog,
                        icon: const Icon(Icons.add_alert, size: 18),
                        label: const Text('Нове'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          minimumSize: const Size(0, 48),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Оновити',
                      visualDensity: VisualDensity.compact,
                      onPressed: _isLoading ? null : _loadNotifications,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                )
              : Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _NotificationStatCard(
                      icon: Icons.notifications_active_outlined,
                      title: 'Активні',
                      value: '$activeCount',
                      subtitle: 'Видимі на головній',
                    ),
                    FilledButton.icon(
                      onPressed: _isSaving
                          ? null
                          : _showCreateNotificationDialog,
                      icon: const Icon(Icons.add_alert),
                      label: const Text('Нове сповіщення'),
                    ),
                    IconButton(
                      tooltip: 'Оновити',
                      onPressed: _isLoading ? null : _loadNotifications,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _notifications.isEmpty
              ? const _EmptyNotificationsState()
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: _notifications.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final notification = _notifications[index];
                      return _buildNotificationCard(notification);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildNotificationCard(GroupNotification notification) {
    final expiresAt = DateFormat(
      'dd.MM.yyyy HH:mm',
    ).format(notification.expiresAt);
    final createdAt = DateFormat(
      'dd.MM.yyyy HH:mm',
    ).format(notification.createdAt);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _iconForType(notification.type),
                  color: _colorForType(notification.type),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    notification.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Chip(
                  label: Text(notification.isActive ? 'Активне' : 'Завершене'),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(notification.message),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  label: Text(notification.type.displayName),
                  visualDensity: VisualDensity.compact,
                ),
                Chip(
                  label: Text('Створено: $createdAt'),
                  visualDensity: VisualDensity.compact,
                ),
                Chip(
                  label: Text('Активне до: $expiresAt'),
                  visualDensity: VisualDensity.compact,
                ),
                if (notification.targetUserId != null)
                  const Chip(
                    label: Text('Персональне'),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: _isSaving
                    ? null
                    : () => _deleteNotification(notification),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Видалити'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateNotificationDialog() async {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    final durationController = TextEditingController(text: '24');
    String selectedUnit = 'hours';

    final shouldSubmit = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) => AlertDialog(
            title: const Text('Нове сповіщення для групи'),
            content: SizedBox(
              width: 500,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Заголовок',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Вкажіть заголовок';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: messageController,
                      decoration: const InputDecoration(
                        labelText: 'Текст сповіщення',
                        border: OutlineInputBorder(),
                      ),
                      minLines: 3,
                      maxLines: 5,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Вкажіть текст';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: durationController,
                            decoration: const InputDecoration(
                              labelText: 'Тривалість',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              final number = int.tryParse(value?.trim() ?? '');
                              if (number == null || number <= 0) {
                                return 'Вкажіть число';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedUnit,
                            decoration: const InputDecoration(
                              labelText: 'Одиниця',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'hours',
                                child: Text('Години'),
                              ),
                              DropdownMenuItem(
                                value: 'days',
                                child: Text('Дні'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setStateDialog(() => selectedUnit = value);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Скасувати'),
              ),
              FilledButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    Navigator.of(context).pop(true);
                  }
                },
                child: const Text('Відправити'),
              ),
            ],
          ),
        );
      },
    );

    if (shouldSubmit != true || !mounted) {
      titleController.dispose();
      messageController.dispose();
      durationController.dispose();
      return;
    }

    final amount = int.parse(durationController.text.trim());
    final duration = selectedUnit == 'days'
        ? Duration(days: amount)
        : Duration(hours: amount);

    setState(() => _isSaving = true);
    try {
      await Globals.groupNotificationsService.createGroupAnnouncement(
        title: titleController.text.trim(),
        message: messageController.text.trim(),
        duration: duration,
      );
      await _loadNotifications();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Сповіщення відправлено'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Не вдалося відправити сповіщення: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      titleController.dispose();
      messageController.dispose();
      durationController.dispose();
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _deleteNotification(GroupNotification notification) async {
    setState(() => _isSaving = true);
    try {
      final success = await Globals.groupNotificationsService
          .deleteNotification(notification.id);
      if (success) {
        await _loadNotifications();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'Сповіщення видалено' : 'Не вдалося видалити сповіщення',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  IconData _iconForType(GroupNotificationType type) {
    switch (type) {
      case GroupNotificationType.announcement:
        return Icons.campaign;
      case GroupNotificationType.absenceApproved:
        return Icons.check_circle_outline;
      case GroupNotificationType.absenceRejected:
        return Icons.cancel_outlined;
      case GroupNotificationType.absenceCancelled:
        return Icons.person_off_outlined;
      case GroupNotificationType.absenceAssigned:
        return Icons.assignment_ind_outlined;
      case GroupNotificationType.absenceUpdated:
        return Icons.edit_calendar_outlined;
    }
  }

  Color _colorForType(GroupNotificationType type) {
    switch (type) {
      case GroupNotificationType.announcement:
        return Colors.blue;
      case GroupNotificationType.absenceApproved:
        return Colors.green;
      case GroupNotificationType.absenceRejected:
        return Colors.red;
      case GroupNotificationType.absenceCancelled:
        return Colors.orange;
      case GroupNotificationType.absenceAssigned:
        return Colors.blueAccent;
      case GroupNotificationType.absenceUpdated:
        return Colors.deepPurple;
    }
  }
}

class _NotificationStatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final bool compact;

  const _NotificationStatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 16,
        vertical: compact ? 10 : 16,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: compact
          ? Row(
              children: [
                Icon(icon, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 2),
                      Text(
                        '$value • $subtitle',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 12)),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(subtitle, style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ],
            ),
    );
  }
}

class _EmptyNotificationsState extends StatelessWidget {
  const _EmptyNotificationsState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_none,
              size: 64,
              color: Colors.grey.shade500,
            ),
            const SizedBox(height: 16),
            const Text(
              'Сповіщень поки немає',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Створіть перше групове оголошення для головної сторінки.',
              style: TextStyle(color: Colors.grey.shade700),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
