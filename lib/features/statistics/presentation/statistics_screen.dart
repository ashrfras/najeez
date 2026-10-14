import 'package:flutter/material.dart';
import '../../../core/arabic_dates.dart';
import '../../../core/design.dart';
import '../../tasks/domain/task.dart';
import '../../tasks/domain/task_controller.dart';
import '../../tasks/domain/task_dates.dart';
import '../../tasks/presentation/task_widgets.dart';

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
  DateTime? expanded;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final days = completedByDay(widget.controller.tasks).entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                    ),
                    const SizedBox(width: 5),
                    const Flexible(
                      child: Text(
                        'الإحصاءات',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.title,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                if (days.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(25),
                    decoration: panel(),
                    child: const Center(
                      child: Text(
                        'ستظهر مهامك المكتملة هنا',
                        style: AppType.caption,
                      ),
                    ),
                  ),
                for (final day in days) ...[
                  Container(
                    decoration: panel(),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        InkWell(
                          onTap: () => setState(
                            () =>
                                expanded = expanded == day.key ? null : day.key,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(15),
                            child: Row(
                              children: [
                                Text(
                                  arabicDate(day.key),
                                  style: AppType.section,
                                ),
                                const Spacer(),
                                CountBadge(
                                  count: day.value.length,
                                  color: AppColors.blue,
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  expanded == day.key
                                      ? Icons.keyboard_arrow_up
                                      : Icons.keyboard_arrow_down,
                                  color: AppColors.muted,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (expanded == day.key) ...[
                          const Divider(height: 1, color: AppColors.border),
                          for (final task in day.value)
                            InkWell(
                              onTap: () => widget.onActions(task),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 11,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.check_circle,
                                      size: 19,
                                      color: AppColors.green,
                                    ),
                                    const SizedBox(width: 11),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(task.title, style: AppType.body),
                                          if (task.totalMinutes > 0) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              '◷ ${durationLabel(task.totalMinutes)}',
                                              style: AppType.caption.copyWith(
                                                color: AppColors.blue,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    Text(
                                      timeLabel(task.completedAt!),
                                      style: AppType.caption,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 11),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
