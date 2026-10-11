import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/arabic_dates.dart';
import '../../../core/design.dart';
import '../../history/presentation/history_screen.dart';
import '../domain/task.dart';
import '../domain/task_controller.dart';
import 'task_composer_screen.dart';
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
    _scheduleFiveAm();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _scheduleFiveAm() {
    _dayTimer?.cancel();
    final now = DateTime.now();
    final todayAtFive = DateTime(now.year, now.month, now.day, 5);
    final nextRefresh = now.isBefore(todayAtFive)
        ? todayAtFive
        : DateTime(now.year, now.month, now.day + 1, 5);
    _dayTimer = Timer(nextRefresh.difference(now), () {
      widget.controller.refreshDay();
      _scheduleFiveAm();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.controller.refreshDay();
      _scheduleFiveAm();
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

  void _showActions(Task task) => showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (sheetContext) => SafeArea(
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
            const SizedBox(height: 18),
            if (task.isCompleted)
              _action(
                Icons.undo,
                'إعادة إلى المهام',
                AppColors.green,
                () => widget.controller.restore(task),
              )
            else ...[
              _action(
                Icons.check_circle_outline,
                'تمت المهمة',
                AppColors.green,
                () => widget.controller.complete(task),
              ),
              _action(
                Icons.adjust,
                'نقل إلى اليوم',
                AppColors.blue,
                () => widget.controller.move(task, TaskBucket.today),
              ),
              _action(
                Icons.calendar_month_outlined,
                'نقل إلى غداً',
                AppColors.blue,
                () => widget.controller.move(task, TaskBucket.tomorrow),
              ),
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
            _action(
              Icons.delete_outline,
              'حذف المهمة',
              AppColors.red,
              () => widget.controller.delete(task),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _action(
    IconData icon,
    String label,
    Color color,
    Future<void> Function() callback,
  ) => Builder(
    builder: (context) => InkWell(
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
          border: Border(
            bottom: BorderSide(color: AppColors.border, width: .6),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 15),
            Text(label, style: AppType.body),
          ],
        ),
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

  @override
  Widget build(BuildContext context) {
    final now = widget.controller.now;
    final today = TaskListKind.today.select(widget.controller);
    final tomorrow = TaskListKind.tomorrow.select(widget.controller);
    final later = TaskListKind.later.select(widget.controller);
    final completed = TaskListKind.completedToday.select(widget.controller);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      SizedBox(
                        height: 36,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                arabicDate(now),
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
                                child: GestureDetector(
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => HistoryScreen(
                                        controller: widget.controller,
                                      ),
                                    ),
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 5,
                                    ),
                                    decoration: panel(radius: 12),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.history,
                                          size: 16,
                                          color: AppColors.muted,
                                        ),
                                        SizedBox(width: 5),
                                        Text('السجل', style: AppType.caption),
                                      ],
                                    ),
                                  ),
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
                            count: completed.length,
                            label: 'تم اليوم',
                            color: AppColors.green,
                            icon: Icons.check,
                            onTap: () => _openList(TaskListKind.completedToday),
                          ),
                          const SizedBox(width: 8),
                          _Stat(
                            count: tomorrow.length,
                            label: 'غداً',
                            color: AppColors.blue,
                            icon: Icons.calendar_month_outlined,
                            onTap: () => _openList(TaskListKind.tomorrow),
                          ),
                          const SizedBox(width: 8),
                          _Stat(
                            count: later.length,
                            label: 'لاحقاً',
                            color: AppColors.orange,
                            icon: Icons.all_inclusive,
                            onTap: () => _openList(TaskListKind.later),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      InkWell(
                        onTap: _openComposer,
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        child: Container(
                          decoration: panel(color: AppColors.surfaceRaised),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'أضف مهمة بسرعة ...',
                                  style: AppType.caption,
                                ),
                              ),
                              Container(
                                width: 37,
                                height: 37,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.blue,
                                ),
                                child: const Icon(
                                  Icons.add,
                                  color: AppColors.background,
                                  size: 25,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TaskSection(
                        title: 'اليوم',
                        tasks: today,
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
                              title: 'غداً',
                              tasks: tomorrow,
                              accent: AppColors.blue,
                              icon: Icons.calendar_month_outlined,
                              previewLimit: 2,
                              onOpenAll: () => _openList(TaskListKind.tomorrow),
                              onToggle: _toggleTask,
                              onActions: _showActions,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TaskSection(
                              title: 'لاحقاً',
                              tasks: later,
                              accent: AppColors.orange,
                              icon: Icons.all_inclusive,
                              previewLimit: 2,
                              onOpenAll: () => _openList(TaskListKind.later),
                              onToggle: _toggleTask,
                              onActions: _showActions,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 13),
                      TaskSection(
                        title: 'تم اليوم',
                        tasks: completed,
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

class _Stat extends StatelessWidget {
  const _Stat({
    required this.count,
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
  });
  final int count;
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
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: panel(),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: .15),
              ),
              child: Icon(icon, color: color, size: 21),
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$count',
                    style: TextStyle(
                      color: color,
                      fontSize: 22,
                      height: 1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.caption.copyWith(fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
