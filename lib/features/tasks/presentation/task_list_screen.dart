import 'package:flutter/material.dart';
import '../../../core/design.dart';
import '../domain/task.dart';
import '../domain/task_controller.dart';
import '../domain/task_dates.dart';
import 'task_widgets.dart';

enum TaskListKind { today, tomorrow, later, completedToday }

extension TaskListKindDetails on TaskListKind {
  String get title => switch (this) {
    TaskListKind.today => 'اليوم',
    TaskListKind.tomorrow => 'غداً',
    TaskListKind.later => 'لاحقاً',
    TaskListKind.completedToday => 'تم اليوم',
  };

  Color get accent => switch (this) {
    TaskListKind.today || TaskListKind.tomorrow => AppColors.blue,
    TaskListKind.later => AppColors.orange,
    TaskListKind.completedToday => AppColors.green,
  };

  IconData get icon => switch (this) {
    TaskListKind.today => Icons.adjust,
    TaskListKind.tomorrow => Icons.calendar_month_outlined,
    TaskListKind.later => Icons.all_inclusive,
    TaskListKind.completedToday => Icons.check,
  };

  List<Task> select(TaskController controller) {
    final now = controller.now;
    if (this == TaskListKind.completedToday) {
      return controller.tasks
          .where(
            (task) =>
                task.completedAt != null &&
                controller.logicalDay.same(task.completedAt!, now),
          )
          .toList()
        ..sort((a, b) => b.completedAt!.compareTo(a.completedAt!));
    }
    final bucket = switch (this) {
      TaskListKind.today => TaskBucket.today,
      TaskListKind.tomorrow => TaskBucket.tomorrow,
      TaskListKind.later => TaskBucket.later,
      TaskListKind.completedToday => throw StateError('Handled above'),
    };
    return controller.tasks
        .where(
          (task) =>
              !task.isCompleted &&
              visibleBucket(task, now, controller.logicalDay) == bucket,
        )
        .toList();
  }
}

class TaskListScreen extends StatelessWidget {
  const TaskListScreen({
    super.key,
    required this.controller,
    required this.kind,
    required this.onToggle,
    required this.onActions,
  });

  final TaskController controller;
  final TaskListKind kind;
  final void Function(Task) onToggle;
  final void Function(Task) onActions;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back),
                      color: AppColors.text,
                    ),
                    const SizedBox(width: 5),
                    Text(kind.title, style: AppType.section),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: AnimatedBuilder(
                    animation: controller,
                    builder: (context, _) {
                      final tasks = kind.select(controller);
                      return Container(
                        decoration: panel(),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(13, 11, 13, 9),
                              child: Row(
                                children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: kind.accent.withValues(alpha: .15),
                                      borderRadius: BorderRadius.circular(9),
                                    ),
                                    child: Icon(
                                      kind.icon,
                                      size: 18,
                                      color: kind.accent,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      kind.title,
                                      style: AppType.section,
                                    ),
                                  ),
                                  CountBadge(
                                    count: tasks.length,
                                    color: kind.accent,
                                  ),
                                ],
                              ),
                            ),
                            if (tasks.isEmpty)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  2,
                                  12,
                                  17,
                                ),
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    'لا توجد مهام هنا',
                                    style: AppType.caption.copyWith(
                                      color: AppColors.muted.withValues(
                                        alpha: .7,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            else
                              Expanded(
                                child: ListView.separated(
                                  itemCount: tasks.length,
                                  itemBuilder: (context, index) => TaskRow(
                                    key: ValueKey(tasks[index].id),
                                    task: tasks[index],
                                    onToggle: () => onToggle(tasks[index]),
                                    onActions: () => onActions(tasks[index]),
                                  ),
                                  separatorBuilder: (context, index) =>
                                      const Divider(
                                        height: 1,
                                        indent: 13,
                                        endIndent: 13,
                                        color: AppColors.border,
                                      ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
