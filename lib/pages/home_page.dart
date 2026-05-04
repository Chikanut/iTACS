import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../globals.dart';
import '../services/dashboard_service.dart';
import '../models/lesson_model.dart';
import '../pages/calendar_page/calendar_utils.dart';
import '../pages/calendar_page/widgets/lesson_details_dialog.dart';
import '../models/report_template_model.dart';
import '../services/report_templates_service.dart';
import '../services/reports/quick_report_dialog.dart';
import '../models/instructor_absence.dart';
import '../models/group_notification.dart';
import '../widgets/absence_request_dialog.dart';
import '../theme/app_theme.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final DashboardService _dashboardService = DashboardService();
  DashboardFeed _feed = DashboardFeed.empty;
  bool _isLoading = true;
  String? _error;
  List<InstructorAbsence> _userAbsences = [];
  List<GroupNotification> _notifications = [];

  @override
  void initState() {
    super.initState();
    _hydrateCachedHomeState();
    unawaited(_loadFeed());
  }

  Future<void> _loadFeed() async {
    try {
      final shouldShowBlockingLoader = !_hasVisibleContent;
      setState(() {
        _isLoading = shouldShowBlockingLoader;
        _error = null;
      });

      final feed = await _dashboardService.getDashboardFeed();

      // Додаємо завантаження відсутностей
      List<InstructorAbsence> absences = [];
      List<GroupNotification> notifications = [];
      try {
        absences = await Globals.absencesService.getCurrentUserAbsences();
      } catch (e) {
        // Ігноруємо помилки відсутностей, щоб не блокувати основний функціонал
        print('Помилка завантаження відсутностей: $e');
      }
      try {
        notifications = await Globals.groupNotificationsService
            .getNotificationsForCurrentUser();
      } catch (e) {
        print('Помилка завантаження сповіщень: $e');
      }

      if (mounted) {
        setState(() {
          _feed = feed;
          _userAbsences = absences;
          _notifications = notifications;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        if (_hasVisibleContent) {
          Globals.errorNotificationManager.showError(
            'Не вдалося оновити дані. Показано останній збережений стан.',
          );
          setState(() {
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = e.toString();
            _isLoading = false;
          });
        }
      }
    }
  }

  Future<void> _refreshFeed() async {
    try {
      final feed = await _dashboardService.getDashboardFeed(forceRefresh: true);

      List<InstructorAbsence> absences = [];
      List<GroupNotification> notifications = [];
      try {
        absences = await Globals.absencesService.getCurrentUserAbsences();
      } catch (e) {
        print('Помилка оновлення відсутностей: $e');
      }
      try {
        notifications = await Globals.groupNotificationsService
            .getNotificationsForCurrentUser();
      } catch (e) {
        print('Помилка оновлення сповіщень: $e');
      }

      if (mounted) {
        setState(() {
          _feed = feed;
          _userAbsences = absences;
          _notifications = notifications;
        });
      }
    } catch (e) {
      if (mounted) {
        if (!_hasVisibleContent) {
          setState(() {
            _error = e.toString();
          });
        }
        Globals.errorNotificationManager.showError(
          'Помилка оновлення: ${e.toString()}',
        );
      }
    }
  }

  void _hydrateCachedHomeState() {
    final cachedFeed = _dashboardService.getCachedDashboardFeed();
    final cachedAbsences = Globals.absencesService
        .getCachedCurrentUserAbsences();
    final cachedNotifications = Globals.groupNotificationsService
        .getCachedNotificationsForCurrentUser();

    if (cachedFeed == null &&
        cachedAbsences.isEmpty &&
        cachedNotifications.isEmpty) {
      return;
    }

    setState(() {
      if (cachedFeed != null) {
        _feed = cachedFeed;
      }
      _userAbsences = cachedAbsences;
      _notifications = cachedNotifications;
      _isLoading = false;
    });
  }

  bool get _hasVisibleContent =>
      _feed.lastUpdated.year != 1970 ||
      _userAbsences.isNotEmpty ||
      _notifications.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refreshFeed,
        child: CustomScrollView(
          slivers: [
            // Заголовок з привітанням
            _buildSliverAppBar(user),

            // Контент ленти
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _buildErrorSliver()
            else
              _buildFeedContent(),
          ],
        ),
      ),
    );
  }

  /// Заголовок сторінки з привітанням
  Widget _buildSliverAppBar(User? user) {
    final now = DateTime.now();
    final hour = now.hour;
    String greeting;

    if (hour < 12) {
      greeting = 'Доброго ранку';
    } else if (hour < 18) {
      greeting = 'Доброго дня';
    } else {
      greeting = 'Доброго вечора';
    }

    final userName =
        Globals.profileManager.currentUserName ??
        user?.displayName ??
        user?.email?.split('@').first ??
        'Користувач';

    return SliverAppBar(
      expandedHeight: 80, // Збільшуємо висоту
      floating: false,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              greeting,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            Text(
              userName,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
      ),
    );
  }

  /// Контент ленти
  Widget _buildFeedContent() {
    final nextLesson = _feed.nextLesson;
    final tomorrowLessons = _feed.tomorrowLessons;
    final shownLessonIds = {
      if (tomorrowLessons.isNotEmpty)
        ...tomorrowLessons.map((lesson) => lesson.id),
      if (tomorrowLessons.isEmpty && nextLesson != null) nextLesson.id,
    };
    final acknowledgementLessons =
        _feed.lessonsRequiringAcknowledgement
            .where((lesson) => !shownLessonIds.contains(lesson.id))
            .toList()
          ..sort((a, b) => a.startTime.compareTo(b.startTime));

    return SliverList(
      delegate: SliverChildListDelegate([
        const SizedBox(height: 16),
        if (_notifications.isNotEmpty) _buildNotificationsCard(),
        _buildAbsencesCard(),
        if (tomorrowLessons.isNotEmpty)
          _UpcomingLessonsCard(
            title: 'Заняття на завтра',
            icon: Icons.event_note,
            lessons: tomorrowLessons,
            showAcknowledgementBadge: true,
            onLessonUpdated: _refreshFeed,
          )
        else if (nextLesson != null)
          _UpcomingLessonsCard(
            title: 'Наступне заняття',
            icon: Icons.schedule,
            lessons: [nextLesson],
            showAcknowledgementBadge: true,
            onLessonUpdated: _refreshFeed,
          ),

        if (acknowledgementLessons.isNotEmpty)
          _UpcomingLessonsCard(
            title: 'Потрібно ознайомитись',
            icon: Icons.visibility_outlined,
            lessons: acknowledgementLessons,
            showAcknowledgementBadge: true,
            onLessonUpdated: _refreshFeed,
          ),

        // Заняття без викладача завтра
        if (_feed.tomorrowWithoutInstructor.isNotEmpty)
          _TomorrowWithoutInstructorCard(
            lessons: _feed.tomorrowWithoutInstructor,
            onLessonUpdated: _refreshFeed,
          ),

        // Персональна статистика
        _PersonalStatsCard(stats: _feed.userStats),

        // Генерація звітів
        const _ReportsCard(),

        // Остання оновка та відступ
        _LastUpdatedCard(lastUpdated: _feed.lastUpdated),

        const SizedBox(height: 100), // Відступ для навігації
      ]),
    );
  }

  Widget _buildAbsencesCard() {
    final isReadOnlyOffline = Globals.appRuntimeState.isReadOnlyOffline;
    final warningColors = AppTheme.statusColors(AppStatusTone.warning);
    final infoColors = AppTheme.statusColors(AppStatusTone.info);
    final successColors = AppTheme.statusColors(AppStatusTone.success);

    final pendingRequests = _userAbsences
        .where((a) => a.status == AbsenceStatus.pending)
        .toList();
    final activeAbsences = _userAbsences
        .where((a) => a.status == AbsenceStatus.active)
        .toList();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.event_busy, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                const Text(
                  'Мої запити',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: isReadOnlyOffline
                      ? null
                      : _showAbsenceRequestDialog,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Запросити'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Запити що очікують підтвердження
            if (pendingRequests.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: AppTheme.statusDecoration(
                  AppStatusTone.warning,
                  radius: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          color: warningColors.border,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '🙋‍♂️ Мої запити:',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: warningColors.foreground,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...pendingRequests.map(
                      (absence) => _buildAbsenceItem(absence, isPending: true),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Активні відсутності (включаючи призначення адміном)
            if (activeAbsences.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: AppTheme.statusDecoration(
                  AppStatusTone.info,
                  radius: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: infoColors.border, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '👮‍♂️ Активні відсутності:',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: infoColors.foreground,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...activeAbsences.map(
                      (absence) => _buildAbsenceItem(absence),
                    ),
                  ],
                ),
              ),
            ] else if (pendingRequests.isEmpty) ...[
              // Якщо немає жодних відсутностей
              Container(
                padding: const EdgeInsets.all(16),
                decoration: AppTheme.statusDecoration(
                  AppStatusTone.success,
                  radius: 12,
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: successColors.border),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Наразі відсутності не зареєстровано',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: successColors.foreground,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationsCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.notifications_active,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Активні сповіщення',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._notifications.map(_buildNotificationItem),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationItem(GroupNotification notification) {
    final notificationColor = _notificationColor(notification.type);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: notificationColor.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: notificationColor.border.withOpacity(0.75)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _notificationIcon(notification.type),
            color: notificationColor.border,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: notificationColor.foreground,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  notification.message,
                  style: TextStyle(color: notificationColor.foreground),
                ),
                const SizedBox(height: 6),
                Text(
                  'Активне до ${DateFormat('dd.MM.yyyy HH:mm').format(notification.expiresAt)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: notificationColor.badge,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAbsenceItem(
    InstructorAbsence absence, {
    bool isPending = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(absence.type.emoji),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${absence.type.displayName} ${DateFormat('dd.MM').format(absence.startDate)}-${DateFormat('dd.MM').format(absence.endDate)} - ${isPending ? '⏳ Очікує підтвердження' : '📋 Активно'}',
              style: const TextStyle(fontSize: 14),
            ),
          ),
          if (absence.isAdminAssignment)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: AppTheme.statusDecoration(
                AppStatusTone.info,
                radius: 6,
              ),
              child: Text(
                'Адмін',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.infoStatus.foreground,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showAbsenceRequestDialog() {
    showDialog(
      context: context,
      builder: (context) => const AbsenceRequestDialog(),
    ).then((_) {
      // Оновлюємо дані після закриття діалогу
      _refreshFeed();
    });
  }

  IconData _notificationIcon(GroupNotificationType type) {
    switch (type) {
      case GroupNotificationType.announcement:
        return Icons.campaign;
      case GroupNotificationType.absenceApproved:
        return Icons.check_circle_outline;
      case GroupNotificationType.absenceRejected:
        return Icons.highlight_off;
      case GroupNotificationType.absenceCancelled:
        return Icons.person_off_outlined;
      case GroupNotificationType.absenceAssigned:
        return Icons.assignment_ind_outlined;
      case GroupNotificationType.absenceUpdated:
        return Icons.edit_calendar_outlined;
    }
  }

  AppStatusColors _notificationColor(GroupNotificationType type) {
    switch (type) {
      case GroupNotificationType.announcement:
        return AppTheme.statusColors(AppStatusTone.info);
      case GroupNotificationType.absenceApproved:
        return AppTheme.statusColors(AppStatusTone.success);
      case GroupNotificationType.absenceRejected:
        return AppTheme.statusColors(AppStatusTone.danger);
      case GroupNotificationType.absenceCancelled:
        return AppTheme.statusColors(AppStatusTone.warning);
      case GroupNotificationType.absenceAssigned:
        return AppTheme.statusColors(AppStatusTone.info);
      case GroupNotificationType.absenceUpdated:
        return AppTheme.statusColors(AppStatusTone.info);
    }
  }

  /// Відображення помилки
  Widget _buildErrorSliver() {
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Помилка завантаження даних',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Невідома помилка',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadFeed,
              child: const Text('Спробувати знову'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Картка найближчих занять викладача
class _UpcomingLessonsCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<LessonModel> lessons;
  final bool showAcknowledgementBadge;
  final VoidCallback? onLessonUpdated;
  const _UpcomingLessonsCard({
    required this.title,
    required this.icon,
    required this.lessons,
    this.showAcknowledgementBadge = false,
    this.onLessonUpdated,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...lessons.map(
              (lesson) => _EnhancedLessonListTile(
                lesson: lesson,
                showAcknowledgementBadge: showAcknowledgementBadge,
                onLessonUpdated: onLessonUpdated,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Картка занять без викладача завтра
class _TomorrowWithoutInstructorCard extends StatelessWidget {
  final List<LessonModel> lessons;
  final VoidCallback? onLessonUpdated;

  const _TomorrowWithoutInstructorCard({
    required this.lessons,
    this.onLessonUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final tomorrowFormatted = DateFormat('dd.MM', 'uk').format(tomorrow);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppTheme.warningStatus.background,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber, color: AppTheme.warningStatus.border),
                const SizedBox(width: 8),
                Text(
                  'Завтра без викладача ($tomorrowFormatted)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.warningStatus.foreground,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...lessons.map(
              (lesson) => _EnhancedLessonListTile(
                lesson: lesson,
                showWarning: true,
                titleColor: AppTheme.warningStatus.foreground,
                onLessonUpdated:
                    onLessonUpdated, // Передаємо колбек для оновлення
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Картка персональної статистики
class _PersonalStatsCard extends StatelessWidget {
  final UserStats stats;

  const _PersonalStatsCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    // Безпечне отримання значень
    final conductedLessons = stats.conductedLessons ?? 0;
    final totalLessons = stats.totalLessons ?? 0;
    final thisWeekLessons = stats.thisWeekLessons ?? 0;
    final thisMonthLessons = stats.thisMonthLessons ?? 0;
    final completionRate = stats.completionRate ?? 0.0;
    final incompleteCount = stats.incompleteCount ?? 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок
            Row(
              children: [
                Icon(Icons.analytics, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Ваша статистика',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Статистика з безпечними значеннями
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Wrap(
                spacing: 24,
                runSpacing: 24,
                children: [
                  _StatItem(
                    label: 'Проведено',
                    value: '$conductedLessons',
                    icon: Icons.check_circle,
                    color: Colors.green,
                  ),
                  _StatItem(
                    label: 'Всього',
                    value: '$totalLessons',
                    icon: Icons.event,
                    color: Colors.blue,
                  ),
                  _StatItem(
                    label: 'Завершення',
                    value: '${completionRate.toStringAsFixed(0)}%',
                    icon: Icons.trending_up,
                    color: Colors.purple,
                  ),
                  _StatItem(
                    label: 'Цей тиждень',
                    value: '$thisWeekLessons',
                    icon: Icons.calendar_view_week,
                    color: Colors.orange,
                  ),
                  _StatItem(
                    label: 'Цей місяць',
                    value: '$thisMonthLessons',
                    icon: Icons.calendar_month,
                    color: Colors.teal,
                  ),
                  _StatItem(
                    label: 'Незаповнені',
                    value: '$incompleteCount',
                    icon: Icons.warning_outlined,
                    color: Colors.red,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Віджет статистичного елементу
class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(height: 12),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Картка генерації звітів
class _ReportsCard extends StatefulWidget {
  const _ReportsCard();

  @override
  State<_ReportsCard> createState() => _ReportsCardState();
}

class _ReportsCardState extends State<_ReportsCard> {
  final ReportTemplatesService _reportTemplatesService =
      Globals.reportTemplatesService;
  List<ReportTemplate> _templates = [];
  bool _isLoadingTemplates = true;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    if (Globals.appRuntimeState.isReadOnlyOffline) {
      if (!mounted) return;
      setState(() {
        _templates = [];
        _isLoadingTemplates = false;
      });
      return;
    }

    try {
      final templates = await _reportTemplatesService
          .getAccessibleActiveTemplates();
      if (!mounted) return;
      setState(() {
        _templates = templates;
        _isLoadingTemplates = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _templates = [];
        _isLoadingTemplates = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isReadOnlyOffline = Globals.appRuntimeState.isReadOnlyOffline;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.file_download,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'Генерація звітів',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_isLoadingTemplates)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    tooltip: 'Оновити шаблони',
                    onPressed: isReadOnlyOffline ? null : _loadTemplates,
                    icon: const Icon(Icons.refresh),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (isReadOnlyOffline) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: AppTheme.statusDecoration(
                  AppStatusTone.warning,
                  radius: 12,
                ),
                child: Text(
                  'Генерація звітів потребує інтернету й тимчасово недоступна в read-only offline режимі.',
                  style: TextStyle(
                    color: AppTheme.warningStatus.foreground,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (_templates.isNotEmpty) ...[
              Text(
                'Активні шаблони',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _templates
                    .map(
                      (template) => _ReportButton(
                        label: template.name,
                        icon: Icons.auto_awesome_motion,
                        onPressed: isReadOnlyOffline
                            ? null
                            : () => _generateTemplateReport(context, template),
                      ),
                    )
                    .toList(),
              ),
            ] else if (!_isLoadingTemplates && !isReadOnlyOffline) ...[
              Text(
                'Активних шаблонів звітів поки немає.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _generateTemplateReport(
    BuildContext context,
    ReportTemplate template,
  ) async {
    await showQuickReportDialog(
      context: context,
      reportTitle: template.name,
      onGenerate: (startDate, endDate) async {
        try {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const Dialog(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Генерація звіту по шаблону...'),
                  ],
                ),
              ),
            ),
          );

          final report = await _reportTemplatesService.generateTemplateReport(
            templateId: template.id,
            useDraft: false,
            startDate: startDate,
            endDate: endDate,
          );

          if (context.mounted) {
            Navigator.of(context).pop();
          }

          await Globals.fileManager.shareFileByData(
            report.fileName,
            report.bytes,
          );

          if (context.mounted) {
            Globals.errorNotificationManager.showSuccess(
              'Звіт "${template.name}" згенеровано!\nПеріод: ${DateFormat('dd.MM.yyyy').format(startDate)} - ${DateFormat('dd.MM.yyyy').format(endDate)}',
            );
          }
        } catch (e) {
          if (context.mounted) {
            Navigator.of(context).pop();
            Globals.errorNotificationManager.showError(
              'Помилка генерації шаблонного звіту: ${e.toString()}',
            );
          }
        }
      },
    );
  }
}

/// Кнопка для звітів
class _ReportButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  const _ReportButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }
}

/// Картка з часом останнього оновлення
class _LastUpdatedCard extends StatelessWidget {
  final DateTime? lastUpdated;
  static final Uri _githubUri = Uri.parse('https://github.com/Chikanut');
  static final Future<String> _appVersionFuture = PackageInfo.fromPlatform()
      .then((info) => info.version)
      .catchError((_) => AppTheme.appVersion);

  const _LastUpdatedCard({this.lastUpdated});

  @override
  Widget build(BuildContext context) {
    if (lastUpdated == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Text(
            'Оновлено: ${DateFormat('dd.MM.yyyy HH:mm').format(lastUpdated!)}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
          ),
          const SizedBox(height: 4),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              FutureBuilder<String>(
                future: _appVersionFuture,
                builder: (context, snapshot) {
                  final version = snapshot.data ?? AppTheme.appVersion;
                  return Text(
                    'Версія $version',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
                  );
                },
              ),
              Text(
                'Розробник: Войтович Євген',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
              ),
              InkWell(
                onTap: () => launchUrl(_githubUri),
                child: Text(
                  'GitHub',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Покращений елемент списку занять
class _EnhancedLessonListTile extends StatelessWidget {
  final LessonModel lesson;
  final bool showWarning;
  final bool showAcknowledgementBadge;
  final Color? titleColor;
  final VoidCallback? onLessonUpdated;

  const _EnhancedLessonListTile({
    required this.lesson,
    this.showWarning = false,
    this.showAcknowledgementBadge = false,
    this.titleColor,
    required this.onLessonUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final statusEvaluation = LessonStatusUtils.evaluateLessonStatus(lesson);
    final backgroundColor = statusEvaluation.color;
    const textColor = Colors.white;

    final now = DateTime.now();
    final isToday =
        DateFormat('dd.MM.yyyy').format(lesson.startTime) ==
        DateFormat('dd.MM.yyyy').format(now);
    final isTomorrow =
        DateFormat('dd.MM.yyyy').format(lesson.startTime) ==
        DateFormat('dd.MM.yyyy').format(now.add(const Duration(days: 1)));
    final currentAssignmentId = Globals.calendarService
        .getCurrentUserAssignmentIdForLesson(lesson);
    final acknowledgementStatus = currentAssignmentId != null
        ? LessonStatusUtils.getAcknowledgementStatusForInstructor(
            lesson,
            instructorAssignmentId: currentAssignmentId,
            instructorIdentityCandidates: Globals.calendarService
                .getCurrentUserAssignmentCandidates(),
          )
        : LessonAcknowledgementStatus.notRequired;
    final shouldShowAcknowledgementBadge =
        showAcknowledgementBadge &&
        (acknowledgementStatus == LessonAcknowledgementStatus.pending ||
            acknowledgementStatus == LessonAcknowledgementStatus.urgent);

    String datePrefix = '';
    if (isToday) {
      datePrefix = 'Сьогодні ';
    } else if (isTomorrow) {
      datePrefix = 'Завтра ';
    } else {
      datePrefix = '${DateFormat('dd.MM', 'uk').format(lesson.startTime)} ';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        // 👈 Додаємо це
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => LessonDetailsDialog(
              lesson: lesson,
              onUpdated: () {
                onLessonUpdated?.call();
              },
            ),
          );
        },
        child: Row(
          children: [
            // Час з датою - робимо ширшою
            Container(
              width: 100, // Збільшуємо ширину
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                children: [
                  Text(
                    datePrefix,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    lesson.timeString,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // Інформація
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lesson.title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: titleColor, // Використовуємо переданий колір
                    ),
                  ),
                  if (lesson.location.isNotEmpty)
                    Text(
                      lesson.location,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  // Додаємо статус заняття
                  Text(
                    statusEvaluation.label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: statusEvaluation.color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (shouldShowAcknowledgementBadge)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: acknowledgementStatus.color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: acknowledgementStatus.color.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          'Потрібне підтвердження',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: acknowledgementStatus.color,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Попередження або іконка статусу
            if (showWarning)
              Icon(
                Icons.warning,
                color: AppTheme.warningStatus.border,
                size: 20,
              )
            else
              Icon(
                statusEvaluation.icon,
                color: statusEvaluation.color,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
