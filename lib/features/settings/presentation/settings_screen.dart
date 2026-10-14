import 'package:flutter/material.dart';
import '../../../core/design.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
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
              const _SettingsGroup(
                title: 'إعدادات التطبيق',
                items: [
                  _SettingsItem(Icons.today_outlined, 'منطق اليوم التالي'),
                  _SettingsItem(Icons.backup_outlined, 'الحفظ الاحتياطي'),
                ],
              ),
              const SizedBox(height: 25),
              const _SettingsGroup(
                title: 'معلومات',
                items: [
                  _SettingsItem(Icons.privacy_tip_outlined, 'سياسة الخصوصية'),
                  _SettingsItem(Icons.info_outline, 'عن التطبيق'),
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
  );
}

class _SettingsItem {
  const _SettingsItem(this.icon, this.label, {this.color = AppColors.muted});

  final IconData icon;
  final String label;
  final Color color;
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
              Padding(
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
                      child: Text(
                        items[index].label,
                        style: AppType.body.copyWith(
                          color: items[index].color == AppColors.red
                              ? AppColors.red
                              : AppColors.text,
                        ),
                      ),
                    ),
                    const Text('قريباً', style: AppType.caption),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    ],
  );
}
