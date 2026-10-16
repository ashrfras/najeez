import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/design.dart';
import '../../tasks/domain/task_controller.dart';
import 'app_info_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.controller});

  final TaskController controller;

  Future<void> _chooseLogicalDay(BuildContext context) => showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _LogicalDayPickerDialog(
      controller: controller,
      initialHour: controller.logicalDay.hour.clamp(0, 12),
    ),
  );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => Scaffold(
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
                    const _SettingsItem(
                      Icons.backup_outlined,
                      'الحفظ الاحتياطي',
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
                        MaterialPageRoute(builder: (_) => const AboutScreen()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 25),
                const _SettingsGroup(
                  title: 'البيانات',
                  items: [
                    _SettingsItem(
                      Icons.restart_alt_rounded,
                      'إعادة الضبط',
                      color: AppColors.red,
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
              'لا ينتهي يوم الجميع عند منتصف الليل.\nاختر الساعة التي يبدأ عندها يومك الجديد. مثلا، إذا اخترت 4 صباحا، فسيظل نجيز يعتبر الوقت قبلها جزءا من يومك السابق.',
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
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final String? subtitle;
  final String? trailing;
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
                      if (items[index].trailing != null ||
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
