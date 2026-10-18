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
    duration: const Duration(milliseconds: 1400),
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
      final strike = const Interval(
        0.1,
        0.7,
        curve: Curves.easeInOut,
      ).transform(progress);
      final exit = const Interval(
        0.76,
        1,
        curve: Curves.easeInOut,
      ).transform(progress);
      final checked = widget.task.isCompleted || progress > .12;
      final fill = widget.task.isCompleted
          ? AppColors.green
          : Color.lerp(
              Colors.transparent,
              AppColors.green,
              (progress * 3).clamp(0.0, 1.0),
            )!;
      return IgnorePointer(
        ignoring: _completing,
        child: ClipRect(
          child: Align(
            heightFactor: 1 - exit,
            child: Opacity(
              opacity: 1 - exit,
              child: Material(
                color: widget.task.isPinned
                    ? AppColors.blue.withValues(alpha: .06)
                    : Colors.transparent,
                child: InkWell(
                  onTap: widget.onActions,
                  onLongPress: widget.onActions,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
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
                                                    ((progress - .12) / .7)
                                                        .clamp(0.0, 1.0),
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
                          child: CustomPaint(
                            foregroundPainter: _TaskStrikePainter(
                              text: widget.task.title,
                              style: DefaultTextStyle.of(
                                context,
                              ).style.merge(AppType.body),
                              direction: Directionality.of(context),
                              textScaler: MediaQuery.textScalerOf(context),
                              maxLines: widget.dense ? 1 : 2,
                              progress: strike,
                            ),
                            child: Text(
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
                              ),
                            ),
                          ),
                        ),
                        if (widget.task.isPinned) ...[
                          const SizedBox(width: 7),
                          Transform.rotate(
                            angle: math.pi / 8,
                            child: const Icon(
                              Icons.push_pin,
                              size: 15,
                              color: AppColors.blue,
                              semanticLabel: 'مهمة مثبتة',
                            ),
                          ),
                        ],
                        if (widget.showTime &&
                            widget.task.totalMinutes > 0) ...[
                          const SizedBox(width: 7),
                          Text(
                            '◷ ${durationLabel(widget.task.totalMinutes)}',
                            maxLines: 1,
                            style: AppType.caption.copyWith(
                              color: AppColors.blue,
                              fontSize: 11,
                            ),
                          ),
                        ],
                        if (widget.task.tag != null) ...[
                          const SizedBox(width: 7),
                          _TagBadge(label: widget.task.tag!),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _TaskStrikePainter extends CustomPainter {
  const _TaskStrikePainter({
    required this.text,
    required this.style,
    required this.direction,
    required this.textScaler,
    required this.maxLines,
    required this.progress,
  });

  final String text;
  final TextStyle style;
  final TextDirection direction;
  final TextScaler textScaler;
  final int maxLines;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 0) return;
    final layout = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: direction,
      textScaler: textScaler,
      maxLines: maxLines,
      ellipsis: '…',
    )..layout(minWidth: size.width, maxWidth: size.width);
    final lines = layout.computeLineMetrics();
    final paint = Paint()
      ..color = AppColors.muted
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;
    for (var index = 0; index < lines.length; index++) {
      final line = lines[index];
      final fraction = (progress * lines.length - index).clamp(0.0, 1.0);
      if (fraction == 0) continue;
      final start = direction == TextDirection.rtl
          ? line.left + line.width
          : line.left;
      final length = line.width * fraction;
      final y = line.baseline - line.ascent * .35;
      canvas.drawLine(
        Offset(start, y),
        Offset(start + (direction == TextDirection.rtl ? -length : length), y),
        paint,
      );
    }
    layout.dispose();
  }

  @override
  bool shouldRepaint(_TaskStrikePainter oldDelegate) =>
      progress != oldDelegate.progress ||
      text != oldDelegate.text ||
      style != oldDelegate.style ||
      direction != oldDelegate.direction ||
      textScaler != oldDelegate.textScaler ||
      maxLines != oldDelegate.maxLines;
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
