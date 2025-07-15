import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../globals.dart';
import '../services/dashboard_service.dart';
import '../pages/calendar_page/models/lesson_model.dart';
import '../pages/calendar_page/calendar_utils.dart';
import '../services/reports_service.dart';
import '../pages/calendar_page/widgets/lesson_details_dialog.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final DashboardService _dashboardService = DashboardService();
  final ReportsService _reportsService = ReportsService();
  DashboardFeed _feed = DashboardFeed.empty;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFeed();
  }

  Future<void> _loadFeed() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final feed = await _dashboardService.getDashboardFeed();
      
      if (mounted) {
        setState(() {
          _feed = feed;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshFeed() async {
    try {
      final feed = await _dashboardService.getDashboardFeed(forceRefresh: true);
      
      if (mounted) {
        setState(() {
          _feed = feed;
        });
      }
    } catch (e) {
      if (mounted) {
        Globals.errorNotificationManager.showError(
          'Помилка оновлення: ${e.toString()}',
        );
      }
    }
  }

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

    final userName = Globals.profileManager.currentUserName ?? 
                     user?.displayName ?? 
                     user?.email?.split('@').first ?? 
                     'Користувач';

    final groupName = Globals.profileManager.currentGroupName;

    return SliverAppBar(
      expandedHeight: 140, // Збільшуємо висоту
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
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).primaryColor,
                Theme.of(context).primaryColor.withOpacity(0.8),
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (groupName != null) ...[
                    const SizedBox(height: 24), // Більший відступ
                    Row(
                      children: [
                        const Icon(Icons.group, size: 16, color: Colors.white70),
                        const SizedBox(width: 4),
                        Text(
                          groupName,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Контент ленти
  Widget _buildFeedContent() {
    // Поточні та завтрашні заняття разом
    final upcomingLessons = [..._feed.currentLessons];
    
    // Додаємо завтрашні заняття користувача
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final currentUser = Globals.profileManager.profile.email;
    
    // Тут потрібно буде додати метод для отримання завтрашніх занять користувача
    // Поки що використовуємо існуючі дані
    
    // Сортуємо по даті та часу
    upcomingLessons.sort((a, b) {
      final dateCompare = a.startTime.compareTo(b.startTime);
      return dateCompare;
    });

    return SliverList(
      delegate: SliverChildListDelegate([
        const SizedBox(height: 16),
        
        // Поточні та завтрашні заняття
        if (upcomingLessons.isNotEmpty)
          _UpcomingLessonsCard(lessons: upcomingLessons, onLessonUpdated: _refreshFeed),
        
        // Заняття без викладача завтра
        if (_feed.tomorrowWithoutInstructor.isNotEmpty)
          _TomorrowWithoutInstructorCard(lessons: _feed.tomorrowWithoutInstructor, onLessonUpdated: _refreshFeed),

        // Персональна статистика
        _PersonalStatsCard(stats: _feed.userStats),
        
        // Генерація звітів
        _ReportsCard(reportsService: _reportsService),
        
        // Остання оновка та відступ
        _LastUpdatedCard(lastUpdated: _feed.lastUpdated),
        
        const SizedBox(height: 100), // Відступ для навігації
      ]),
    );
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

/// Картка майбутніх занять (поточні + завтрашні)
class _UpcomingLessonsCard extends StatelessWidget {
  final List<LessonModel> lessons;
  final VoidCallback? onLessonUpdated;
  const _UpcomingLessonsCard({required this.lessons, this.onLessonUpdated});

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
                Icon(Icons.schedule, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Ваші найближчі заняття',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...lessons.map((lesson) => _EnhancedLessonListTile(lesson: lesson, onLessonUpdated: onLessonUpdated)),
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

  const _TomorrowWithoutInstructorCard({required this.lessons, this.onLessonUpdated});

  @override
  Widget build(BuildContext context) {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final tomorrowFormatted = DateFormat('dd.MM', 'uk').format(tomorrow);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                Text(
                  'Завтра без викладача ($tomorrowFormatted)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...lessons.map((lesson) => _EnhancedLessonListTile(
              lesson: lesson,
              showWarning: true,
              titleColor: Colors.black, // Чорний колір для назви
              onLessonUpdated: onLessonUpdated, // Передаємо колбек для оновлення

            )),
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
    // Розраховуємо статистику незаповнених занять
    // Тут потрібно буде додати відповідні поля в UserStats
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            
            // Основні метрики - обмежуємо ширину
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
                child: Wrap(
                spacing: 16, // Відстань між елементами по горизонталі
                runSpacing: 16, // Відстань між рядками
                children: [
                  Expanded(
                    child: _StatItem(
                      label: 'Проведено',
                      value: '${stats.conductedLessons}',
                      icon: Icons.check_circle,
                      color: Colors.green,
                    ),
                  ),
                  Expanded(
                    child: _StatItem(
                      label: 'Всього',
                      value: '${stats.totalLessons}',
                      icon: Icons.event,
                      color: Colors.blue,
                    ),
                  ),
                  Expanded(
                    child: _StatItem(
                      label: 'Завершення',
                      value: '${stats.completionRate.toStringAsFixed(0)}%',
                      icon: Icons.trending_up,
                      color: Colors.purple,
                    ),
                  ),
                  Expanded(
                    child: _StatItem(
                      label: 'Цей тиждень',
                      value: '${stats.thisWeekLessons}',
                      icon: Icons.calendar_view_week,
                      color: Colors.orange,
                    ),
                  ),
                  Expanded(
                    child: _StatItem(
                      label: 'Цей місяць',
                      value: '${stats.thisMonthLessons}',
                      icon: Icons.calendar_month,
                      color: Colors.teal,
                    ),
                  ),
                  Expanded(
                    child: _StatItem(
                      label: 'Незаповнені',
                      value: '${stats.incompleteCount}',
                      icon: Icons.warning_outlined,
                      color: Colors.red,
                    ),
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
class _ReportsCard extends StatelessWidget {
  final ReportsService reportsService;

  const _ReportsCard({required this.reportsService});

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
                Icon(Icons.file_download, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Генерація звітів',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Кнопки генерації
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ReportButton(
                  label: 'Календар тижня',
                  icon: Icons.calendar_view_week,
                  onPressed: () => _generateCalendar(context, CalendarPeriod.week),
                ),
                _ReportButton(
                  label: 'Календар місяця',
                  icon: Icons.calendar_month,
                  onPressed: () => _generateCalendar(context, CalendarPeriod.month),
                ),
                _ReportButton(
                  label: 'Звіт інструкторів',
                  icon: Icons.people,
                  onPressed: () => _generateInstructorReport(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateCalendar(BuildContext context, CalendarPeriod period) async {
    try {
      // Показуємо індикатор завантаження
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final now = DateTime.now();
      final data = await reportsService.generateCalendarExcel(
        startDate: period == CalendarPeriod.week 
            ? CalendarUtils.getStartOfWeek(now)
            : CalendarUtils.getStartOfMonth(now),
        period: period,
      );

      // Закриваємо індикатор
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Зберігаємо файл
      final periodName = period == CalendarPeriod.week ? 'тиждень' : 'місяць';
      final fileName = 'календар_${periodName}_${DateFormat('dd_MM_yyyy').format(now)}.xlsx';
      
      await Globals.fileManager.shareFileByData(fileName, data);
      
      if (context.mounted) {
        Globals.errorNotificationManager.showSuccess('Календар згенеровано!');
      }
    } catch (e) {
      // Закриваємо індикатор якщо відкритий
      if (context.mounted) {
        Navigator.of(context).pop();
        Globals.errorNotificationManager.showError('Помилка генерації: ${e.toString()}');
      }
    }
  }

  Future<void> _generateInstructorReport(BuildContext context) async {
    try {
      // Показуємо індикатор завантаження
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final now = DateTime.now();
      final startOfMonth = CalendarUtils.getStartOfMonth(now);
      
      final data = await reportsService.generateInstructorReport(
        startDate: startOfMonth,
        endDate: now,
      );

      // Закриваємо індикатор
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Зберігаємо файл
      final fileName = 'звіт_інструкторів_${DateFormat('dd_MM_yyyy').format(now)}.xlsx';
      
      await Globals.fileManager.shareFileByData(fileName, data);
      
      if (context.mounted) {
        Globals.errorNotificationManager.showSuccess('Звіт згенеровано!');
      }
    } catch (e) {
      // Закриваємо індикатор якщо відкритий
      if (context.mounted) {
        Navigator.of(context).pop();
        Globals.errorNotificationManager.showError('Помилка генерації: ${e.toString()}');
      }
    }
  }
}

/// Кнопка для звітів
class _ReportButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

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

  const _LastUpdatedCard({this.lastUpdated});

  @override
  Widget build(BuildContext context) {
    if (lastUpdated == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Center(
        child: Text(
          'Оновлено: ${DateFormat('dd.MM.yyyy HH:mm').format(lastUpdated!)}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey,
          ),
        ),
      ),
    );
  }
}

/// Покращений елемент списку занять
class _EnhancedLessonListTile extends StatelessWidget {
  final LessonModel lesson;
  final bool showWarning;
  final Color? titleColor;
  final VoidCallback? onLessonUpdated;

  const _EnhancedLessonListTile({
    required this.lesson,
    this.showWarning = false,
    this.titleColor,
    required  this.onLessonUpdated,
  });

  @override
  Widget build(BuildContext context) {
    // Отримуємо статус заняття
    final progressStatus = LessonStatusUtils.getProgressStatus(lesson);
    final readinessStatus = LessonStatusUtils.getReadinessStatus(lesson);
    
    // Визначаємо колір фону на основі статусу
    Color backgroundColor;
    Color textColor = Colors.white;
    
    switch (readinessStatus) {
      case LessonReadinessStatus.completedReady:
      case LessonReadinessStatus.inProgressReady:
      case LessonReadinessStatus.ready:
        backgroundColor = Colors.green;
        break;
      case LessonReadinessStatus.needsInstructor:
      case LessonReadinessStatus.notReady:
        backgroundColor = Colors.orange;
        break;
      case LessonReadinessStatus.completedNotReady:
      case LessonReadinessStatus.inProgressNotReady:
        backgroundColor = Colors.red;
        break;
    }
    
    final now = DateTime.now();
    final isToday = DateFormat('dd.MM.yyyy').format(lesson.startTime) == 
                   DateFormat('dd.MM.yyyy').format(now);
    final isTomorrow = DateFormat('dd.MM.yyyy').format(lesson.startTime) == 
                      DateFormat('dd.MM.yyyy').format(now.add(const Duration(days: 1)));
    
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
      child: GestureDetector( // 👈 Додаємо це
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
                        color: Colors.grey[600],
                      ),
                    ),
                  // Додаємо статус заняття
                  Text(
                    readinessStatus.label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: readinessStatus.color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            
            // Попередження або іконка статусу
            if (showWarning)
              Icon(Icons.warning, color: Colors.orange[700], size: 20)
            else
              Icon(
                readinessStatus.icon,
                color: readinessStatus.color,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}