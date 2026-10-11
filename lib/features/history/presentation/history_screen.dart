import 'package:flutter/material.dart';
import '../../../core/arabic_dates.dart';
import '../../../core/design.dart';
import '../../tasks/domain/task_controller.dart';
import '../../tasks/domain/task_dates.dart';
import '../../tasks/presentation/task_widgets.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, required this.controller});
  final TaskController controller;
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  DateTime? expanded;
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
                    const Text('السجل', style: AppType.title),
                  ],
                ),
                const SizedBox(height: 6),
                const Text('ما أنجزته، يوماً بعد يوم', style: AppType.caption),
                const SizedBox(height: 27),
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
                            Padding(
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
                                    child: Text(
                                      task.title,
                                      style: AppType.body,
                                    ),
                                  ),
                                  Text(
                                    timeLabel(task.completedAt!),
                                    style: AppType.caption,
                                  ),
                                ],
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
