import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/design.dart';
import '../../../core/status_bar_fade.dart';
import '../../tasks/domain/task_controller.dart';
import 'app_info_screen.dart';
import '../../backup/backup_scope.dart';
import '../../backup/cloud_backup_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.controller});

  final TaskController controller;

  Future<void> _reset(BuildContext context) async {
    final didReset = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ResetDialog(
        reset: BackupScope.of(context)?.resetLocalData ?? controller.reset,
      ),
    );
    if (didReset != true || !context.mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم حذف جميع البيانات وإعادة ضبط التطبيق.')),
    );
  }

  Future<void> _chooseLogicalDay(BuildContext context) => showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _LogicalDayPickerDialog(
      controller: controller,
      initialHour: controller.logicalDay.hour.clamp(0, 12),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final backup = BackupScope.of(context);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => Scaffold(
        body: StatusBarFade(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  18 + MediaQuery.paddingOf(context).top,
                  16,
                  28 + MediaQuery.paddingOf(context).bottom,
                ),
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
                          'الإعدادات',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.title,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  _SettingsGroup(
                    title: 'إعدادات التطبيق',
                    items: [
                      _SettingsItem(
                        Icons.today_outlined,
                        'اليوم المنطقي',
                        subtitle: 'حدد الساعة التي يبدأ عندها يوم جديد',
                        trailing: startTimeLabel(controller),
                        onTap: () => _chooseLogicalDay(context),
                      ),
                      _SettingsItem(
                        Icons.timer_outlined,
                        'تتبع الوقت',
                        subtitle: 'سجّل الوقت الذي تقضيه على مهامك',
                        trailingWidget: _TimeTrackingSwitch(
                          controller: controller,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),
                  _SettingsGroup(
                    title: 'معلومات',
                    items: [
                      _SettingsItem(
                        Icons.privacy_tip_outlined,
                        'سياسة الخصوصية',
                        onTap: () => Navigator.push<void>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PrivacyScreen(),
                          ),
                        ),
                      ),
                      _SettingsItem(
                        Icons.info_outline,
                        'عن التطبيق',
                        onTap: () => Navigator.push<void>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AboutScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),
                  _SettingsGroup(
                    title: 'البيانات',
                    items: [
                      _SettingsItem(
                        Icons.cloud_outlined,
                        'الحفظ السحابي',
                        subtitle: 'الحفظ الإحتياطي للبيانات عبر iCloud',
                        onTap: () => Navigator.push<void>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CloudBackupScreen(),
                          ),
                        ),
                      ),
                      _SettingsItem(
                        Icons.restart_alt_rounded,
                        'إعادة الضبط',
                        color: AppColors.red,
                        onTap: backup?.busy == true
                            ? null
                            : () => _reset(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResetDialog extends StatefulWidget {
  const _ResetDialog({required this.reset});

  final Future<void> Function() reset;

  @override
  State<_ResetDialog> createState() => _ResetDialogState();
}

class _ResetDialogState extends State<_ResetDialog> {
  bool _resetting = false;
  bool _failed = false;

  Future<void> _confirm() async {
    if (_resetting) return;
    setState(() {
      _resetting = true;
      _failed = false;
    });
    try {
      await widget.reset();
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _resetting = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_resetting,
    child: AlertDialog(
      scrollable: true,
      title: const Text('إعادة ضبط التطبيق؟'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'سيتم حذف جميع المهام، بما فيها المكتملة والمحذوفة، والوسوم وسجلات الوقت والإحصائيات، وإعادة الإعدادات إلى حالتها الأولى.\n\nهذا الإجراء نهائي، ولا يمكن استرجاع البيانات بعد حذفها.',
          ),
          if (_failed)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'تعذّرت إعادة الضبط. لم تُحذف البيانات. حاول مرة أخرى.',
                style: TextStyle(color: AppColors.red),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _resetting ? null : () => Navigator.of(context).pop(false),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.red),
          onPressed: _resetting ? null : _confirm,
          child: _resetting
              ? Semantics(
                  label: 'جارٍ حذف البيانات',
                  child: const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : const Text('حذف جميع البيانات'),
        ),
      ],
    ),
  );
}

class _LogicalDayPickerDialog extends StatefulWidget {
  const _LogicalDayPickerDialog({
    required this.controller,
    required this.initialHour,
  });

  final TaskController controller;
  final int initialHour;

  @override
  State<_LogicalDayPickerDialog> createState() =>
      _LogicalDayPickerDialogState();
}

class _LogicalDayPickerDialogState extends State<_LogicalDayPickerDialog> {
  late final FixedExtentScrollController _scrollController;
  late int _selectedHour;
  bool _saving = false;
  bool _saveFailed = false;

  @override
  void initState() {
    super.initState();
    _selectedHour = widget.initialHour;
    _scrollController = FixedExtentScrollController(initialItem: _selectedHour);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _hourLabel(int hour) => '${hour.toString().padLeft(2, '0')}:00';

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _saveFailed = false;
    });
    // Let the progress state paint before persistence and dependent views update.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    try {
      await widget.controller.setLogicalDayStart(_selectedHour * 60);
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _saveFailed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      scrollable: true,
      title: const Text('اليوم المنطقي'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "لا ينتهي يوم الجميع عند منتصف الليل.\nاختر الساعة التي يبدأ عندها يومك الجديد. مثلا، إذا كنت تعمل حتى 4 صباحا، فسيظل 'نجيز' يعتبر الوقت قبلها جزءا من يومك السابق.",
            ),
            const SizedBox(height: 18),
            Text(
              'يبدأ يومك عند',
              textAlign: TextAlign.center,
              style: AppType.caption,
            ),
            const SizedBox(height: 4),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              child: Text(
                _hourLabel(_selectedHour),
                key: ValueKey(_selectedHour),
                textAlign: TextAlign.center,
                style: AppType.title.copyWith(
                  color: AppColors.blue,
                  fontSize: 36,
                ),
              ),
            ),
            const SizedBox(height: 8),
            AbsorbPointer(
              absorbing: _saving,
              child: SizedBox(
                height: 166,
                child: CupertinoPicker(
                  key: const ValueKey('logical-day-hour-picker'),
                  scrollController: _scrollController,
                  itemExtent: 46,
                  backgroundColor: Colors.transparent,
                  selectionOverlay: CupertinoPickerDefaultSelectionOverlay(
                    background: AppColors.blue.withValues(alpha: .14),
                  ),
                  onSelectedItemChanged: (hour) {
                    setState(() => _selectedHour = hour);
                    HapticFeedback.selectionClick();
                  },
                  children: [
                    for (var hour = 0; hour <= 12; hour++)
                      Center(
                        child: Text(
                          _hourLabel(hour),
                          style: AppType.body.copyWith(fontSize: 20),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (_saveFailed)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'تعذّر حفظ الإعداد. حاول مرة أخرى.',
                  style: TextStyle(color: AppColors.red),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? Semantics(
                  label: 'جارٍ التحديث',
                  child: const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : const Text('حفظ'),
        ),
      ],
    ),
  );
}

String startTimeLabel(TaskController controller) {
  final start = controller.logicalDay;
  return '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
}

class _SettingsItem {
  const _SettingsItem(
    this.icon,
    this.label, {
    this.color = AppColors.muted,
    this.subtitle,
    this.trailing,
    this.trailingWidget,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final String? subtitle;
  final String? trailing;
  final Widget? trailingWidget;
  final VoidCallback? onTap;
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, required this.items});

  final String title;
  final List<_SettingsItem> items;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
        child: Text(title, style: AppType.section),
      ),
      Container(
        decoration: panel(),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (var index = 0; index < items.length; index++) ...[
              if (index > 0) const Divider(height: 1, color: AppColors.border),
              InkWell(
                onTap: items[index].onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 17,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        items[index].icon,
                        color: items[index].color,
                        size: 21,
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              items[index].label,
                              style: AppType.body.copyWith(
                                color: items[index].color == AppColors.red
                                    ? AppColors.red
                                    : AppColors.text,
                              ),
                            ),
                            if (items[index].subtitle != null) ...[
                              const SizedBox(height: 5),
                              Text(
                                items[index].subtitle!,
                                style: AppType.caption,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (items[index].trailingWidget != null)
                        items[index].trailingWidget!
                      else if (items[index].trailing != null ||
                          items[index].onTap == null)
                        Text(
                          items[index].trailing ?? 'قريباً',
                          style: AppType.caption,
                        )
                      else
                        const Icon(
                          Icons.chevron_right,
                          size: 20,
                          color: AppColors.muted,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ],
  );
}

class _TimeTrackingSwitch extends StatefulWidget {
  const _TimeTrackingSwitch({required this.controller});
  final TaskController controller;

  @override
  State<_TimeTrackingSwitch> createState() => _TimeTrackingSwitchState();
}

class _TimeTrackingSwitchState extends State<_TimeTrackingSwitch> {
  bool _saving = false;

  Future<void> _change(bool enabled) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          scrollable: true,
          title: Text(enabled ? 'تفعيل تتبع الوقت؟' : 'تعطيل تتبع الوقت؟'),
          content: Text(
            enabled
                ? 'ستتمكن من تسجيل الوقت الذي تقضيه على مهامك، وستعتمد الإحصاءات على الوقت المسجل وتوزيعه بين التصنيفات.\n\nسيُعاد عرض جميع الأوقات التي سجلتها سابقاً، إن وجدت.'
                : 'سيتم إخفاء أدوات تسجيل الوقت، وستعتمد الإحصاءات على عدد المهام المكتملة بدلاً من الوقت المقضي.\n\nستبقى جميع الأوقات المسجلة محفوظة، ويمكنك استعادتها بإعادة تفعيل الميزة في أي وقت.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(enabled ? 'تفعيل' : 'تعطيل'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      await widget.controller.setTimeTrackingEnabled(enabled);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذّر حفظ الإعداد. حاول مرة أخرى.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'تتبع الوقت',
    child: Transform.scale(
      scale: .8,
      alignment: AlignmentDirectional.centerEnd,
      transformHitTests: false,
      child: Switch(
        key: const ValueKey('time-tracking-switch'),
        padding: EdgeInsets.zero,
        activeTrackColor: AppColors.blue,
        activeThumbColor: AppColors.text,
        inactiveTrackColor: AppColors.surfaceRaised,
        inactiveThumbColor: AppColors.muted,
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? Colors.transparent
              : AppColors.border;
        }),
        value: widget.controller.timeTrackingEnabled,
        onChanged: _saving ? null : _change,
      ),
    ),
  );
}
