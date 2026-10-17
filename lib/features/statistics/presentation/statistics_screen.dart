import 'package:flutter/material.dart';
import '../../../core/arabic_dates.dart';
import '../../../core/design.dart';
import '../../tasks/domain/task.dart';
import '../../tasks/domain/task_controller.dart';
import '../../tasks/presentation/task_widgets.dart';
import '../domain/statistics.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({
    super.key,
    required this.controller,
    required this.onActions,
  });
  final TaskController controller;
  final void Function(Task) onActions;

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  late StatisticsIndex _statistics;
  late DateTime _today;
  late DayStatistics _summary;
  final Set<DateTime> _expanded = {};
  final Set<DateTime> _showAllTasks = {};
  int _visibleDays = 7;
  late int _availableDays;

  @override
  void initState() {
    super.initState();
    _today = widget.controller.logicalDay.dayOf(widget.controller.now);
    _expanded.add(_today);
    _readStatistics();
    widget.controller.addListener(_refresh);
  }

  void _readStatistics() {
    _statistics = StatisticsIndex(
      widget.controller.tasks,
      widget.controller.logicalDay,
    );
    final today = widget.controller.logicalDay.dayOf(widget.controller.now);
    if (today != _today) {
      _expanded.remove(_today);
      _today = today;
      _expanded.add(today);
    }
    _summary = _statistics.lastSevenDays(_today);
    _availableDays = _statistics.availableDayCount(_today);
    _visibleDays = _visibleDays.clamp(7, _availableDays);
  }

  void _refresh() {
    if (mounted) setState(_readStatistics);
  }

  @override
  void didUpdateWidget(covariant StatisticsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_refresh);
      widget.controller.addListener(_refresh);
      _readStatistics();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
            itemCount:
                _visibleDays + 1 + (_visibleDays < _availableDays ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == 0) return _header();
              if (index == _visibleDays + 1) {
                return Container(
                  decoration: panel(),
                  child: TextButton.icon(
                    onPressed: () => setState(() {
                      _visibleDays = (_visibleDays + 7).clamp(
                        7,
                        _availableDays,
                      );
                    }),
                    icon: const Icon(Icons.keyboard_arrow_down),
                    label: const Text('عرض أيام سابقة'),
                  ),
                );
              }
              final date = DateTime(
                _today.year,
                _today.month,
                _today.day - index + 1,
              );
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _dayCard(_statistics.day(date)),
              );
            },
          ),
        ),
      ),
    ),
  );

  Widget _header() {
    final summary = _summary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_ios_new, size: 18),
            ),
            const SizedBox(width: 5),
            const Flexible(child: Text('الإحصاءات', style: AppType.title)),
          ],
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: panel(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('آخر 7 أيام', style: AppType.section),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _metric(
                      Icons.schedule,
                      durationLabel(summary.totalMinutes),
                      'الوقت المسجل',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _metric(
                      Icons.check_circle,
                      '${summary.completedTasks.length}',
                      'مهمة مكتملة',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _TimeDistribution(statistics: summary),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text('سجل الأيام', style: AppType.section),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _metric(IconData icon, String value, String label) => LayoutBuilder(
    builder: (context, constraints) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (constraints.maxWidth >= 130) ...[
              Icon(icon, color: AppColors.muted, size: 21),
              const SizedBox(width: 7),
            ],
            Expanded(
              child: Text(
                value,
                style: AppType.section.copyWith(
                  fontSize: constraints.maxWidth < 130 ? 21 : 23,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(label, style: AppType.caption),
      ],
    ),
  );

  Widget _dayCard(DayStatistics stats) {
    final date = stats.day;
    final tasks = stats.completedTasks;
    final isEmpty = tasks.isEmpty && stats.totalMinutes == 0;
    final isExpanded = !isEmpty && _expanded.contains(date);
    final showAll = _showAllTasks.contains(date);
    final label =
        arabicDate(date) + (date.year == _today.year ? '' : ' ${date.year}');
    return Container(
      key: ValueKey(date),
      decoration: panel(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: !isEmpty,
            expanded: isEmpty ? null : isExpanded,
            child: InkWell(
              onTap: isEmpty
                  ? null
                  : () => setState(() {
                      if (!_expanded.add(date)) _expanded.remove(date);
                    }),
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label, style: AppType.section),
                          const SizedBox(height: 5),
                          Text(
                            isEmpty
                                ? 'لا توجد مهام مكتملة أو وقت مسجل'
                                : '${tasks.length} مهام مكتملة · ${durationLabel(stats.totalMinutes)}',
                            style: AppType.caption,
                          ),
                        ],
                      ),
                    ),
                    if (!isEmpty) ...[
                      const SizedBox(width: 8),
                      CountBadge(count: tasks.length, color: AppColors.blue),
                      const SizedBox(width: 6),
                      Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: AppColors.muted,
                        size: 20,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  const Text('توزيع الوقت', style: AppType.body),
                  const SizedBox(height: 12),
                  _TimeDistribution(statistics: stats),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Divider(height: 1, color: AppColors.border),
                  ),
                  if (tasks.isEmpty)
                    const Text('لا توجد مهام مكتملة', style: AppType.caption)
                  else ...[
                    const Text('المهام المكتملة', style: AppType.body),
                    const SizedBox(height: 6),
                    for (final task in tasks.take(showAll ? tasks.length : 2))
                      _completedTask(task),
                    if (tasks.length > 2)
                      TextButton.icon(
                        onPressed: () => setState(() {
                          if (!_showAllTasks.add(date)) {
                            _showAllTasks.remove(date);
                          }
                        }),
                        icon: Icon(
                          showAll
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                        ),
                        label: Text(
                          showAll
                              ? 'طي لائحة المهام'
                              : 'عرض ${tasks.length - 2} مهام أخرى',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _completedTask(Task task) => InkWell(
    onTap: () => widget.onActions(task),
    borderRadius: BorderRadius.circular(8),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.check_circle, size: 21, color: AppColors.green),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(task.title, style: AppType.body),
                if (task.totalMinutes > 0)
                  Text(
                    '◷ ${durationLabel(task.totalMinutes)}',
                    style: AppType.caption.copyWith(color: AppColors.blue),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(timeLabel(task.completedAt!.toLocal()), style: AppType.caption),
        ],
      ),
    ),
  );
}

class _TimeDistribution extends StatelessWidget {
  const _TimeDistribution({required this.statistics});
  final DayStatistics statistics;

  Color _color(String? tag) {
    if (tag == null) return AppColors.muted;
    const palette = [
      AppColors.blue,
      AppColors.purple,
      AppColors.green,
      AppColors.orange,
      AppColors.red,
    ];
    final hash = tag.runes.fold(
      0,
      (value, rune) => (value * 31 + rune) & 0x7fffffff,
    );
    return palette[hash % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final total = statistics.totalMinutes;
    if (total == 0) {
      return const Text(
        'لا يوجد وقت مسجل خلال هذه الفترة',
        style: AppType.caption,
      );
    }
    final categories = statistics.minutesByTag.entries.toList()
      ..sort((a, b) {
        final order = b.value.compareTo(a.value);
        return order == 0 ? (a.key ?? '').compareTo(b.key ?? '') : order;
      });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label: 'توزيع الوقت حسب التصنيفات',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  for (final category in categories)
                    Expanded(
                      flex: category.value,
                      child: Container(color: _color(category.key)),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = (constraints.maxWidth / 80).floor().clamp(2, 5);
            final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final category in categories)
                  SizedBox(
                    width: width,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 5),
                              child: Icon(
                                Icons.circle,
                                color: _color(category.key),
                                size: 9,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Tooltip(
                                message: category.key ?? 'أخرى',
                                child: Text(
                                  category.key ?? 'أخرى',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppType.body,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${(category.value * 100 / total).toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '')}%',
                          style: AppType.caption,
                        ),
                        Text(
                          durationLabel(category.value),
                          style: AppType.caption,
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
