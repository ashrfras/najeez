import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/arabic_dates.dart';
import '../../../core/design.dart';
import '../../../core/status_bar_fade.dart';
import '../../statistics/presentation/statistics_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../domain/task.dart';
import '../domain/task_controller.dart';
import '../domain/task_dates.dart';
import '../domain/work_time_stats.dart';
import '../domain/completion_stats.dart';
import 'task_composer_screen.dart';
import 'daily_repeat_confirmation.dart';
import 'task_list_screen.dart';
import 'task_widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.controller});
  final TaskController controller;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  Timer? _dayTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_refresh);
    _scheduleDayRefresh();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
      _scheduleDayRefresh();
    }
  }

  void _scheduleDayRefresh() {
    _dayTimer?.cancel();
    final now = widget.controller.now;
    final refreshAt = widget.controller.logicalDay.nextStart(now);
    _dayTimer = Timer(refreshAt.difference(now), () {
      unawaited(widget.controller.refreshDay());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(widget.controller.refreshDay());
      _scheduleDayRefresh();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_refresh);
    _dayTimer?.cancel();
    super.dispose();
  }

  void _openComposer([TaskBucket bucket = TaskBucket.today]) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => TaskComposerScreen(
            controller: widget.controller,
            initialBucket: bucket,
          ),
        ),
      );

  void _showError() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تعذّر حفظ المهمة. حاول مرة أخرى.')),
    );
  }

  void _showActions(Task task) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    final currentBucket = visibleBucket(
      task,
      widget.controller.now,
      widget.controller.logicalDay,
    );
    var showMore = false;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 17),
                  Text(
                    task.title,
                    textAlign: TextAlign.center,
                    style: AppType.section,
                  ),
                  if (widget.controller.timeTrackingEnabled) ...[
                    const SizedBox(height: 8),
                    Text(
                      'الوقت المقضي: ${durationLabel(task.totalMinutes)}',
                      style: AppType.caption,
                    ),
                  ],
                  if (task.completedAt != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      widget.controller.timeTrackingEnabled
                          ? 'اكتملت: ${arabicDate(task.completedAt!)}، ${timeLabel(task.completedAt!)}'
                          : 'اكتملت: ${arabicDate(task.completedAt!)}',
                      style: AppType.caption,
                    ),
                  ],
                  const SizedBox(height: 18),
                  if (widget.controller.timeTrackingEnabled)
                    _action(
                      Icons.add_alarm_outlined,
                      'إضافة وقت',
                      AppColors.blue,
                      () => _addTime(task),
                    ),
                  if (widget.controller.timeTrackingEnabled &&
                      task.timeEntries.isNotEmpty)
                    _action(
                      Icons.history,
                      'عرض إدخالات الوقت (${task.timeEntries.length})',
                      AppColors.blue,
                      () => _showTimeEntries(task),
                    ),
                  if (task.isCompleted)
                    _action(
                      Icons.undo,
                      'إعادة إلى المهام',
                      AppColors.green,
                      () => widget.controller.restore(task),
                    )
                  else ...[
                    if (widget.controller.canPin(task))
                      _action(
                        task.isPinned
                            ? Icons.push_pin
                            : Icons.push_pin_outlined,
                        task.isPinned ? 'إلغاء التثبيت' : 'تثبيت المهمة',
                        AppColors.blue,
                        () => widget.controller.setPinned(task, !task.isPinned),
                        iconRotation: math.pi / 8,
                      ),
                    if (!widget.controller.repeatsDaily(task) &&
                        currentBucket != TaskBucket.today)
                      _action(
                        Icons.adjust,
                        'نقل إلى اليوم',
                        AppColors.blue,
                        () => widget.controller.move(task, TaskBucket.today),
                      ),
                    if (!widget.controller.repeatsDaily(task) &&
                        currentBucket != TaskBucket.tomorrow)
                      _action(
                        Icons.calendar_month_outlined,
                        'نقل إلى غداً',
                        AppColors.blue,
                        () => widget.controller.move(task, TaskBucket.tomorrow),
                      ),
                    if (!widget.controller.repeatsDaily(task) &&
                        currentBucket != TaskBucket.later)
                      _action(
                        Icons.all_inclusive,
                        'نقل إلى لاحقاً',
                        AppColors.orange,
                        () => widget.controller.move(task, TaskBucket.later),
                      ),
                  ],
                  _action(
                    Icons.edit_outlined,
                    'تعديل المهمة',
                    AppColors.muted,
                    () => _edit(task),
                  ),
                  if (widget.controller.repeatsDaily(task) || showMore)
                    _action(
                      Icons.repeat,
                      widget.controller.repeatsDaily(task)
                          ? 'إيقاف التكرار اليومي'
                          : 'تكرار يومي',
                      AppColors.muted,
                      () async {
                        final enabled = !widget.controller.repeatsDaily(task);
                        final confirmed = await confirmDailyRepeat(
                          context,
                          enabled: enabled,
                        );
                        if (!confirmed || !mounted) return;
                        await widget.controller.setDailyRepeat(task, enabled);
                      },
                    ),
                  if (showMore)
                    _action(
                      Icons.delete_outline,
                      'حذف المهمة',
                      AppColors.red,
                      () => _confirmDelete(task),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Semantics(
                      expanded: showMore,
                      child: TextButton(
                        onPressed: () =>
                            setSheetState(() => showMore = !showMore),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.muted,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              showMore ? 'إخفاء' : 'المزيد',
                              style: AppType.caption,
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              showMore ? Icons.expand_less : Icons.expand_more,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
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

  Future<void> _confirmDelete(Task task) async {
    final repeating = widget.controller.repeatsDaily(task);
    final confirmed = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف المهمة؟'),
        content: Text(
          repeating
              ? 'يمكنك حذف هذه النسخة فقط، أو حذفها وإيقاف التكرار اليومي. تبقى النسخ السابقة وسجلاتها محفوظة.'
              : 'هل تريد حذف المهمة «${task.title}»؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, 'one'),
            child: Text(repeating ? 'حذف النسخة' : 'حذف'),
          ),
          if (repeating)
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, 'stop'),
              child: const Text('حذف التكرار'),
            ),
        ],
      ),
    );
    if (confirmed == null || !mounted) return;
    await widget.controller.delete(task, stopRepeating: confirmed == 'stop');
  }

  Future<void> _showTimeEntries(Task task) => showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (sheetContext) {
      final height = math.min(
        150.0 + task.timeEntries.length * 62.0,
        MediaQuery.sizeOf(sheetContext).height * .7,
      );
      return SafeArea(
        child: SizedBox(
          height: height,
          child: AnimatedBuilder(
            animation: widget.controller,
            builder: (context, _) {
              final current = widget.controller.tasks.firstWhere(
                (item) => item.id == task.id,
              );
              final entries = current.timeEntries.reversed.toList();
              return Column(
                children: [
                  const SizedBox(height: 14),
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('إدخالات الوقت', style: AppType.section),
                  const SizedBox(height: 5),
                  Text(
                    'المجموع: ${durationLabel(current.totalMinutes)}',
                    style: AppType.caption,
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: AppColors.border),
                  Expanded(
                    child: entries.isEmpty
                        ? const Center(
                            child: Text(
                              'لا توجد إدخالات وقت',
                              style: AppType.caption,
                            ),
                          )
                        : ListView.separated(
                            itemCount: entries.length,
                            itemBuilder: (context, index) {
                              final entry = entries[index];
                              return ListTile(
                                leading: const Icon(
                                  Icons.schedule_outlined,
                                  color: AppColors.blue,
                                ),
                                title: Text(
                                  durationLabel(entry.minutes),
                                  style: AppType.body,
                                ),
                                subtitle: Text(
                                  '${arabicDate(entry.createdAt)}، ${timeLabel(entry.createdAt)}',
                                  style: AppType.caption,
                                ),
                                trailing: IconButton(
                                  key: ValueKey(
                                    'delete-time-entry-${entry.id}',
                                  ),
                                  icon: const Icon(Icons.delete_outline),
                                  iconSize: 18,
                                  color: AppColors.muted,
                                  visualDensity: VisualDensity.compact,
                                  tooltip: 'حذف إدخال الوقت',
                                  onPressed: () =>
                                      _confirmRemoveTimeEntry(current, entry),
                                ),
                              );
                            },
                            separatorBuilder: (_, _) => const Divider(
                              height: 1,
                              color: AppColors.border,
                            ),
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      );
    },
  );

  Future<void> _confirmRemoveTimeEntry(Task task, TimeEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف إدخال الوقت؟'),
        content: Text(
          'هل تريد حذف إدخال ${durationLabel(entry.minutes)} من هذه المهمة؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.controller.removeTimeEntry(task, entry.id);
    } catch (_) {
      _showError();
    }
  }

  Future<void> _addTime(Task task) async {
    var hours = 0;
    var minutes = 0;
    final duration = await showDialog<(int, int)>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('إضافة وقت مقضي'),
            content: SizedBox(
              height: 190,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        const Text('الساعات'),
                        Expanded(
                          child: CupertinoPicker(
                            key: const ValueKey('time-hours'),
                            itemExtent: 38,
                            backgroundColor: Colors.transparent,
                            selectionOverlay:
                                CupertinoPickerDefaultSelectionOverlay(
                                  background: AppColors.blue.withValues(
                                    alpha: .12,
                                  ),
                                ),
                            onSelectedItemChanged: (value) =>
                                setDialogState(() => hours = value),
                            children: [
                              for (var hour = 0; hour < 100; hour++)
                                Center(
                                  child: Text(
                                    '$hour',
                                    style: AppType.body.copyWith(
                                      color: AppColors.text,
                                      fontSize: 20,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      children: [
                        const Text('الدقائق'),
                        Expanded(
                          child: CupertinoPicker(
                            key: const ValueKey('time-minutes'),
                            itemExtent: 38,
                            looping: true,
                            backgroundColor: Colors.transparent,
                            selectionOverlay:
                                CupertinoPickerDefaultSelectionOverlay(
                                  background: AppColors.blue.withValues(
                                    alpha: .12,
                                  ),
                                ),
                            onSelectedItemChanged: (value) =>
                                setDialogState(() => minutes = value),
                            children: [
                              for (var minute = 0; minute < 60; minute++)
                                Center(
                                  child: Text(
                                    '$minute',
                                    style: AppType.body.copyWith(
                                      color: AppColors.text,
                                      fontSize: 20,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: hours > 0 || minutes > 0
                    ? () => Navigator.pop(dialogContext, (hours, minutes))
                    : null,
                child: const Text('إضافة'),
              ),
            ],
          );
        },
      ),
    );
    if (duration == null) return;
    await widget.controller.addTimeEntry(
      task,
      hours: duration.$1,
      minutes: duration.$2,
    );
    if (mounted) {
      final current = widget.controller.tasks.firstWhere(
        (item) => item.id == task.id,
      );
      _showActions(current);
    }
  }

  Widget _action(
    IconData icon,
    String label,
    Color color,
    Future<void> Function() callback, {
    double iconRotation = 0,
  }) => InkWell(
    onTap: () async {
      Navigator.pop(context);
      try {
        await callback();
      } catch (_) {
        _showError();
      }
    },
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border, width: .6)),
      ),
      child: Row(
        children: [
          Transform.rotate(
            angle: iconRotation,
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 15),
          Text(label, style: AppType.body),
        ],
      ),
    ),
  );

  Future<void> _edit(Task task) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) =>
          TaskComposerScreen(controller: widget.controller, task: task),
    ),
  );

  void _toggleTask(Task task) {
    final operation = task.isCompleted
        ? widget.controller.restore(task)
        : widget.controller.complete(task);
    operation.catchError((_) => _showError());
  }

  void _openList(TaskListKind kind) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => TaskListScreen(
        controller: widget.controller,
        kind: kind,
        onToggle: _toggleTask,
        onActions: _showActions,
      ),
    ),
  );

  void _openStatistics() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => StatisticsScreen(
        controller: widget.controller,
        onActions: _showActions,
      ),
    ),
  );

  void _openSettings() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => SettingsScreen(controller: widget.controller),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final now = widget.controller.now;
    final today = TaskListKind.today.select(widget.controller);
    final tomorrow = TaskListKind.tomorrow.select(widget.controller);
    final later = TaskListKind.later.select(widget.controller);
    final completed = TaskListKind.completedToday.select(widget.controller);
    final tracking = widget.controller.timeTrackingEnabled;
    final completions = CompletionStats(
      widget.controller.tasks,
      now,
      widget.controller.logicalDay,
    );
    final workTime = workTimeStats(
      widget.controller.tasks,
      now,
      widget.controller.logicalDay,
    );

    return Scaffold(
      body: StatusBarFade(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  // Keep gesture clearance inside the scrollable viewport.
                  padding: EdgeInsets.fromLTRB(
                    16,
                    12 + MediaQuery.paddingOf(context).top,
                    16,
                    28 + MediaQuery.paddingOf(context).bottom,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      SizedBox(
                        height: 36,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                arabicDate(
                                  widget.controller.logicalDay.dayOf(now),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppType.caption,
                              ),
                            ),
                            SizedBox(
                              width: 66,
                              child: Center(
                                child: Image.asset(
                                  'assets/logo_mark.png',
                                  width: 58,
                                  height: 28,
                                  fit: BoxFit.contain,
                                  semanticLabel: 'نجيز',
                                ),
                              ),
                            ),
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _HeaderIcon(
                                      icon: Icons.bar_chart_rounded,
                                      tooltip: 'الإحصاءات',
                                      onTap: _openStatistics,
                                    ),
                                    const SizedBox(width: 6),
                                    _HeaderIcon(
                                      icon: Icons.settings_outlined,
                                      tooltip: 'الإعدادات',
                                      onTap: _openSettings,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _Stat(
                            value: '${completed.length}',
                            label: 'تم اليوم',
                            color: AppColors.green,
                            icon: Icons.check,
                            onTap: () => _openList(TaskListKind.completedToday),
                          ),
                          const SizedBox(width: 8),
                          _Stat(
                            value: tracking
                                ? compactDurationLabel(workTime.todayMinutes)
                                : '${completions.todayCount}',
                            label: 'عمل اليوم',
                            color: AppColors.blue,
                            icon: tracking
                                ? Icons.schedule_outlined
                                : Icons.check_circle_outline,
                            onTap: _openStatistics,
                          ),
                          const SizedBox(width: 8),
                          _Stat(
                            value: !tracking
                                ? completions.averageLabel
                                : workTime.averageMinutes == null
                                ? '-'
                                : compactDurationLabel(
                                    workTime.averageMinutes!,
                                  ),
                            label: 'متوسط 7 أيام',
                            color: AppColors.orange,
                            icon: Icons.trending_up_rounded,
                            onTap: _openStatistics,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TaskCaptureBar(onTap: _openComposer),
                      const SizedBox(height: 14),
                      TaskSection(
                        controller: widget.controller,
                        title: 'اليوم',
                        tasks: today,
                        showTime: tracking,
                        accent: AppColors.blue,
                        icon: Icons.adjust,
                        previewLimit: 5,
                        onOpenAll: () => _openList(TaskListKind.today),
                        onToggle: _toggleTask,
                        onActions: _showActions,
                      ),
                      const SizedBox(height: 13),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TaskSection(
                              controller: widget.controller,
                              title: 'غداً',
                              tasks: tomorrow,
                              accent: AppColors.blue,
                              icon: Icons.calendar_month_outlined,
                              previewLimit: 2,
                              denseRows: true,
                              showTime: false,
                              onOpenAll: () => _openList(TaskListKind.tomorrow),
                              onToggle: _toggleTask,
                              onActions: _showActions,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TaskSection(
                              controller: widget.controller,
                              title: 'لاحقاً',
                              tasks: later,
                              accent: AppColors.orange,
                              icon: Icons.all_inclusive,
                              previewLimit: 2,
                              denseRows: true,
                              showTime: false,
                              onOpenAll: () => _openList(TaskListKind.later),
                              onToggle: _toggleTask,
                              onActions: _showActions,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 13),
                      TaskSection(
                        controller: widget.controller,
                        title: 'تم اليوم',
                        tasks: completed,
                        showTime: tracking,
                        accent: AppColors.green,
                        icon: Icons.check,
                        previewLimit: 3,
                        onOpenAll: () => _openList(TaskListKind.completedToday),
                        onToggle: _toggleTask,
                        onActions: _showActions,
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 36,
        height: 36,
        decoration: panel(radius: 12),
        child: Icon(icon, size: 20, color: AppColors.muted),
      ),
    ),
  );
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.value,
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
  });
  final String value;
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: panel(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  value,
                  maxLines: 1,
                  style: TextStyle(
                    color: color,
                    fontSize: 18,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(icon, color: color, size: 13),
                const SizedBox(width: 4),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: AppType.caption.copyWith(fontSize: 10),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
