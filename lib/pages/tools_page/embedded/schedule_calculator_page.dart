import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ScheduleCalculatorPage extends StatefulWidget {
  const ScheduleCalculatorPage({super.key});

  @override
  State<ScheduleCalculatorPage> createState() =>
      _ScheduleCalculatorPageState();
}

class _ScheduleCalculatorPageState extends State<ScheduleCalculatorPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [Text('📚 '), Text('Калькулятор розкладу')],
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.timer_outlined), text: 'Тривалість'),
            Tab(icon: Icon(Icons.schedule), text: 'Кінець дня'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _DurationCalculator(),
          _EndTimeCalculator(),
        ],
      ),
    );
  }
}

// ─── Shared helpers ───────────────────────────────────────────────────────────

int _toMinutes(TimeOfDay t) => t.hour * 60 + t.minute;

String _fmt(int totalMinutes) {
  final h = totalMinutes ~/ 60;
  final m = totalMinutes % 60;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

String _duration(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h > 0 && m > 0) return '$h год $m хв';
  if (h > 0) return '$h год';
  return '$m хв';
}

// ─── Shared widgets ───────────────────────────────────────────────────────────

class _TimePicker extends StatelessWidget {
  final String label;
  final TimeOfDay value;
  final ValueChanged<TimeOfDay> onChanged;

  const _TimePicker({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 6),
        InkWell(
          onTap: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: value,
              builder: (ctx, child) => MediaQuery(
                data: MediaQuery.of(ctx)
                    .copyWith(alwaysUse24HourFormat: true),
                child: child!,
              ),
            );
            if (picked != null) onChanged(picked);
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400, width: 1.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.access_time, size: 18, color: Colors.indigo),
                const SizedBox(width: 8),
                Text(
                  '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _NumberField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String suffix;
  final int min;
  final int max;

  const _NumberField({
    required this.label,
    required this.controller,
    required this.suffix,
    this.min = 1,
    this.max = 999,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            suffixText: suffix,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }
}

Widget _scheduleList(List<_LessonSlot> slots) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Розклад занять:',
          style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.indigo)),
      const SizedBox(height: 8),
      ...slots.map(
        (s) => Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(s.ctx).cardColor,
            borderRadius: BorderRadius.circular(6),
            border: Border(
              left: BorderSide(color: Colors.purple.shade300, width: 4),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Заняття ${s.number}',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.purple.shade700),
              ),
              Text(
                '${s.start} — ${s.end}',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

class _LessonSlot {
  final BuildContext ctx;
  final int number;
  final String start;
  final String end;
  const _LessonSlot(this.ctx, this.number, this.start, this.end);
}

Widget _highlightBox(String text) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
      ),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      text,
      style: const TextStyle(
          color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
      textAlign: TextAlign.center,
    ),
  );
}

// ─── Calculator 1: Duration ────────────────────────────────────────────────

class _DurationCalculator extends StatefulWidget {
  const _DurationCalculator();

  @override
  State<_DurationCalculator> createState() => _DurationCalculatorState();
}

class _DurationCalculatorState extends State<_DurationCalculator> {
  TimeOfDay _start = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 15, minute: 0);
  final _lessonsCtrl = TextEditingController(text: '5');
  final _breakCtrl = TextEditingController(text: '10');

  _DurationResult? _result;
  String? _error;

  @override
  void dispose() {
    _lessonsCtrl.dispose();
    _breakCtrl.dispose();
    super.dispose();
  }

  void _calculate() {
    final lessons = int.tryParse(_lessonsCtrl.text.trim()) ?? 0;
    final breakMin = int.tryParse(_breakCtrl.text.trim()) ?? 0;

    if (lessons < 1) {
      setState(() => _error = 'Кількість занять має бути ≥ 1');
      return;
    }

    final startMin = _toMinutes(_start);
    final endMin = _toMinutes(_end);
    final total = endMin - startMin;

    if (total <= 0) {
      setState(() => _error = 'Кінець дня має бути пізніше початку');
      return;
    }

    final totalBreak = breakMin * (lessons - 1);
    final available = total - totalBreak;

    if (available <= 0) {
      setState(() => _error = 'Занадто мало часу для такої кількості перерв');
      return;
    }

    final lessonDur = available ~/ lessons;
    final slots = <_LessonSlot>[];
    var cur = startMin;

    for (int i = 1; i <= lessons; i++) {
      final s = _fmt(cur);
      cur += lessonDur;
      final e = _fmt(cur);
      slots.add(_LessonSlot(context, i, s, e));
      if (i < lessons) cur += breakMin;
    }

    setState(() {
      _error = null;
      _result = _DurationResult(lessonDur, slots);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Вкажіть початок і кінець дня, кількість занять і перерву — дізнайтеся тривалість кожного заняття',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _TimePicker(
                  label: 'Початок дня',
                  value: _start,
                  onChanged: (t) => setState(() {
                    _start = t;
                    _result = null;
                  }),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TimePicker(
                  label: 'Кінець дня',
                  value: _end,
                  onChanged: (t) => setState(() {
                    _end = t;
                    _result = null;
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _NumberField(
                  label: 'Кількість занять',
                  controller: _lessonsCtrl,
                  suffix: 'шт',
                  max: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _NumberField(
                  label: 'Перерва',
                  controller: _breakCtrl,
                  suffix: 'хв',
                  min: 0,
                  max: 120,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _calculate,
              icon: const Icon(Icons.calculate),
              label: const Text('Розрахувати тривалість'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: const Color(0xFF667EEA),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(_error!,
                          style: const TextStyle(color: Colors.red))),
                ],
              ),
            ),
          ],
          if (_result != null) ...[
            const SizedBox(height: 20),
            _highlightBox(
                'Тривалість одного заняття: ${_duration(_result!.lessonDuration)}'),
            const SizedBox(height: 16),
            _scheduleList(_result!.slots),
          ],
        ],
      ),
    );
  }
}

class _DurationResult {
  final int lessonDuration;
  final List<_LessonSlot> slots;
  const _DurationResult(this.lessonDuration, this.slots);
}

// ─── Calculator 2: End time ───────────────────────────────────────────────

class _EndTimeCalculator extends StatefulWidget {
  const _EndTimeCalculator();

  @override
  State<_EndTimeCalculator> createState() => _EndTimeCalculatorState();
}

class _EndTimeCalculatorState extends State<_EndTimeCalculator> {
  TimeOfDay _start = const TimeOfDay(hour: 8, minute: 0);
  final _durationCtrl = TextEditingController(text: '45');
  final _lessonsCtrl = TextEditingController(text: '5');
  final _breakCtrl = TextEditingController(text: '10');

  _EndTimeResult? _result;
  String? _error;

  @override
  void dispose() {
    _durationCtrl.dispose();
    _lessonsCtrl.dispose();
    _breakCtrl.dispose();
    super.dispose();
  }

  void _calculate() {
    final lessonDur = int.tryParse(_durationCtrl.text.trim()) ?? 0;
    final lessons = int.tryParse(_lessonsCtrl.text.trim()) ?? 0;
    final breakMin = int.tryParse(_breakCtrl.text.trim()) ?? 0;

    if (lessonDur < 1) {
      setState(() => _error = 'Тривалість заняття має бути ≥ 1 хв');
      return;
    }
    if (lessons < 1) {
      setState(() => _error = 'Кількість занять має бути ≥ 1');
      return;
    }

    final startMin = _toMinutes(_start);
    final totalLesson = lessonDur * lessons;
    final totalBreak = breakMin * (lessons - 1);
    final totalTime = totalLesson + totalBreak;
    final endMin = startMin + totalTime;

    final slots = <_LessonSlot>[];
    var cur = startMin;
    for (int i = 1; i <= lessons; i++) {
      final s = _fmt(cur);
      cur += lessonDur;
      final e = _fmt(cur);
      slots.add(_LessonSlot(context, i, s, e));
      if (i < lessons) cur += breakMin;
    }

    setState(() {
      _error = null;
      _result = _EndTimeResult(_fmt(endMin), totalTime, slots);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Вкажіть початок дня, тривалість заняття та кількість — дізнайтеся коли закінчиться день',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _TimePicker(
                  label: 'Початок дня',
                  value: _start,
                  onChanged: (t) => setState(() {
                    _start = t;
                    _result = null;
                  }),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _NumberField(
                  label: 'Тривалість заняття',
                  controller: _durationCtrl,
                  suffix: 'хв',
                  max: 300,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _NumberField(
                  label: 'Кількість занять',
                  controller: _lessonsCtrl,
                  suffix: 'шт',
                  max: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _NumberField(
                  label: 'Перерва',
                  controller: _breakCtrl,
                  suffix: 'хв',
                  min: 0,
                  max: 120,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _calculate,
              icon: const Icon(Icons.schedule),
              label: const Text('Розрахувати кінець дня'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: const Color(0xFF764BA2),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(_error!,
                          style: const TextStyle(color: Colors.red))),
                ],
              ),
            ),
          ],
          if (_result != null) ...[
            const SizedBox(height: 20),
            _highlightBox('Кінець навчального дня: ${_result!.endTime}'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border(
                  left: BorderSide(color: Colors.indigo.shade300, width: 4),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 16, color: Colors.indigo.shade600),
                  const SizedBox(width: 8),
                  Text(
                    'Загальна тривалість: ${_duration(_result!.totalMinutes)}',
                    style: TextStyle(
                        color: Colors.indigo.shade700,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _scheduleList(_result!.slots),
          ],
        ],
      ),
    );
  }
}

class _EndTimeResult {
  final String endTime;
  final int totalMinutes;
  final List<_LessonSlot> slots;
  const _EndTimeResult(this.endTime, this.totalMinutes, this.slots);
}
