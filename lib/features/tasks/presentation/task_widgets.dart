import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/design.dart';
import '../domain/task.dart';

class TaskRow extends StatefulWidget {
  const TaskRow({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onActions,
    this.dense = false,
    this.showTime = true,
  });
  final Task task;
  final VoidCallback onToggle;
  final VoidCallback onActions;
  final bool dense;
  final bool showTime;

  @override
  State<TaskRow> createState() => _TaskRowState();
}

class _TaskRowState extends State<TaskRow> with SingleTickerProviderStateMixin {
  late final AnimationController _completion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  bool _completing = false;

  Future<void> _toggle() async {
    if (_completing) return;
    if (widget.task.isCompleted) {
      HapticFeedback.selectionClick();
      widget.onToggle();
      return;
    }
    _completing = true;
    HapticFeedback.mediumImpact();
    await _completion.forward(from: 0);
    if (!mounted) return;
    _completing = false;
    _completion.reset();
    widget.onToggle();
  }

  @override
  void dispose() {
    _completion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _completion,
    builder: (context, _) {
      final progress = _completion.value;
      final checked = widget.task.isCompleted || progress > .12;
      final fill = widget.task.isCompleted
          ? AppColors.green
          : Color.lerp(
              Colors.transparent,
              AppColors.green,
              (progress * 3).clamp(0.0, 1.0),
            )!;
      return InkWell(
        onTap: widget.onActions,
        onLongPress: widget.onActions,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 230;
              return Row(
                children: [
                  GestureDetector(
                    onTap: _toggle,
                    child: SizedBox(
                      width: widget.dense ? 18 : 23,
                      height: widget.dense ? 18 : 23,
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          if (progress > 0 && progress < 1)
                            Transform.scale(
                              scale: 1 + progress * .85,
                              child: Container(
                                width: widget.dense ? 18 : 23,
                                height: widget.dense ? 18 : 23,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.green.withValues(
                                      alpha: (1 - progress) * .7,
                                    ),
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          Transform.scale(
                            scale: 1 + .16 * math.sin(progress * math.pi),
                            child: Container(
                              width: widget.dense ? 18 : 23,
                              height: widget.dense ? 18 : 23,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: fill,
                                border: Border.all(
                                  color: checked
                                      ? AppColors.green
                                      : AppColors.muted,
                                  width: widget.dense ? 1.4 : 1.6,
                                ),
                              ),
                              child: checked
                                  ? Transform.scale(
                                      scale: widget.task.isCompleted
                                          ? 1
                                          : Curves.elasticOut.transform(
                                              ((progress - .12) / .7).clamp(
                                                0.0,
                                                1.0,
                                              ),
                                            ),
                                      child: Icon(
                                        Icons.check,
                                        size: widget.dense ? 13 : 17,
                                        color: Colors.white,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: widget.dense ? 7 : 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.task.title,
                          maxLines: widget.dense ? 1 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.body.copyWith(
                            color: Color.lerp(
                              widget.task.isCompleted
                                  ? AppColors.muted
                                  : AppColors.text,
                              AppColors.muted,
                              progress,
                            ),
                            decoration: progress > .6
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        if ((widget.showTime && widget.task.totalMinutes > 0) ||
                            (compact && widget.task.tag != null)) ...[
                          const SizedBox(height: 5),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              if (widget.showTime &&
                                  widget.task.totalMinutes > 0)
                                Text(
                                  '◷ ${durationLabel(widget.task.totalMinutes)}',
                                  style: AppType.caption.copyWith(
                                    color: AppColors.blue,
                                    fontSize: 11,
                                  ),
                                ),
                              if (compact && widget.task.tag != null)
                                _TagBadge(label: widget.task.tag!),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (!compact && widget.task.tag != null) ...[
                    const SizedBox(width: 7),
                    _TagBadge(label: widget.task.tag!),
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
    },
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
    this.showTime = true,
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
  final bool showTime;

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
              key: ValueKey(tasks[i].id),
              task: tasks[i],
              dense: denseRows,
              showTime: showTime,
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
                    style: AppType.body.copyWith(color: accent, fontSize: 12),
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
