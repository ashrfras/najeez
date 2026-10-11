import 'package:flutter/material.dart';
import '../../../core/design.dart';
import '../../../core/arabic_dates.dart';
import '../domain/task.dart';

class TaskRow extends StatelessWidget {
  const TaskRow({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onActions,
    this.dense = false,
  });
  final Task task;
  final VoidCallback onToggle;
  final VoidCallback onActions;
  final bool dense;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onActions,
    onLongPress: onActions,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 230;
          return Row(
            children: [
              GestureDetector(
                onTap: onToggle,
                child: Container(
                  width: dense ? 18 : 23,
                  height: dense ? 18 : 23,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: task.isCompleted
                        ? AppColors.green
                        : Colors.transparent,
                    border: Border.all(
                      color: task.isCompleted
                          ? AppColors.green
                          : AppColors.muted,
                      width: dense ? 1.4 : 1.6,
                    ),
                  ),
                  child: task.isCompleted
                      ? Icon(
                          Icons.check,
                          size: dense ? 13 : 17,
                          color: Colors.white,
                        )
                      : null,
                ),
              ),
              SizedBox(width: dense ? 7 : 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      maxLines: dense ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.body.copyWith(
                        color: task.isCompleted
                            ? AppColors.muted
                            : AppColors.text,
                      ),
                    ),
                    if (compact && task.tag != null) ...[
                      const SizedBox(height: 5),
                      _TagBadge(label: task.tag!),
                    ],
                  ],
                ),
              ),
              if (!compact && task.tag != null) ...[
                const SizedBox(width: 7),
                _TagBadge(label: task.tag!),
              ],
              if (task.completedAt != null) ...[
                Text(timeLabel(task.completedAt!), style: AppType.caption),
                const SizedBox(width: 9),
              ],
              Icon(
                Icons.more_horiz,
                size: 20,
                color: AppColors.muted.withValues(alpha: .8),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class _TagBadge extends StatelessWidget {
  const _TagBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxWidth: 82),
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: AppColors.blue.withValues(alpha: .15),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppType.caption.copyWith(color: AppColors.blue, fontSize: 10),
    ),
  );
}

class TaskSection extends StatelessWidget {
  const TaskSection({
    super.key,
    required this.title,
    required this.tasks,
    required this.accent,
    required this.icon,
    required this.onToggle,
    required this.onActions,
    this.onAdd,
    this.previewLimit,
    this.onOpenAll,
    this.denseRows = false,
  });
  final String title;
  final List<Task> tasks;
  final Color accent;
  final IconData icon;
  final void Function(Task) onToggle;
  final void Function(Task) onActions;
  final VoidCallback? onAdd;
  final int? previewLimit;
  final VoidCallback? onOpenAll;
  final bool denseRows;

  @override
  Widget build(BuildContext context) {
    final visibleCount = previewLimit == null
        ? tasks.length
        : tasks.length.clamp(0, previewLimit!);
    final remainingCount = tasks.length - visibleCount;
    return Container(
      decoration: panel(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: onOpenAll,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(13, 11, 13, 9),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: .15),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(icon, size: 18, color: accent),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.section,
                    ),
                  ),
                  const SizedBox(width: 8),
                  CountBadge(count: tasks.length, color: accent),
                  if (onAdd != null)
                    GestureDetector(
                      onTap: onAdd,
                      child: Icon(Icons.add, size: 20, color: accent),
                    ),
                ],
              ),
            ),
          ),
          if (tasks.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 2, 12, 17),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'لا توجد مهام هنا',
                  style: AppType.caption.copyWith(
                    color: AppColors.muted.withValues(alpha: .7),
                  ),
                ),
              ),
            ),
          for (var i = 0; i < visibleCount; i++) ...[
            if (i > 0 || tasks.isNotEmpty)
              const Divider(
                height: 1,
                indent: 13,
                endIndent: 13,
                color: AppColors.border,
              ),
            TaskRow(
              task: tasks[i],
              dense: denseRows,
              onToggle: () => onToggle(tasks[i]),
              onActions: () => onActions(tasks[i]),
            ),
          ],
          if (remainingCount > 0 && onOpenAll != null) ...[
            const Divider(
              height: 1,
              indent: 13,
              endIndent: 13,
              color: AppColors.border,
            ),
            InkWell(
              onTap: onOpenAll,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 12,
                ),
                child: Center(
                  child: Text(
                    'عرض $remainingCount مهام أخرى',
                    style: AppType.body.copyWith(color: accent),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class CountBadge extends StatelessWidget {
  const CountBadge({super.key, required this.count, required this.color});
  final int count;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .16),
      borderRadius: BorderRadius.circular(9),
    ),
    child: Text(
      '$count',
      style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13),
    ),
  );
}
