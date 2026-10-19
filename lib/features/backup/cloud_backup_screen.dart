import 'package:flutter/material.dart';

import '../../core/design.dart';
import 'backup_scope.dart';

class CloudBackupScreen extends StatelessWidget {
  const CloudBackupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final backup = BackupScope.of(context);
    final available = backup?.supported == true;
    final ready = available && !backup!.busy;
    return Scaffold(
      appBar: AppBar(
        title: const Text('الحفظ السحابي', style: AppType.section),
        centerTitle: false,
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 28),
              children: [
                Container(
                  decoration: panel(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text('الحفظ السحابي', style: AppType.body),
                          ),
                          Switch(
                            key: const ValueKey('cloud-backup-switch'),
                            value: backup?.enabled ?? false,
                            onChanged: backup?.busy == true
                                ? null
                                : (enabled) {
                                    if (!available) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'الحفظ الاحتياطي متوفر فقط على الأجهزة التي تدعم iCloud.',
                                          ),
                                        ),
                                      );
                                      return;
                                    }
                                    backup?.setEnabled(enabled);
                                  },
                            padding: EdgeInsets.zero,
                            activeTrackColor: AppColors.blue,
                            activeThumbColor: AppColors.text,
                            inactiveTrackColor: AppColors.surfaceRaised,
                            inactiveThumbColor: AppColors.muted,
                            trackOutlineColor: WidgetStateProperty.resolveWith((
                              states,
                            ) {
                              return states.contains(WidgetState.selected)
                                  ? Colors.transparent
                                  : AppColors.border;
                            }),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'تفعيل الحفظ السحابي يحفظ جميع مهامك وسجل الإنجازات وإدخالات الوقت والإعدادات، تلقائيا كل 24 ساعة على iCloud.',
                        style: AppType.caption,
                      ),
                      const Divider(height: 32, color: AppColors.border),
                      const Text('آخر نسخة احتياطية', style: AppType.body),
                      const SizedBox(height: 8),
                      Text(
                        backup?.lastSuccess == null
                            ? 'لم تُحفظ نسخة بعد'
                            : backupDateLabel(backup!.lastSuccess!),
                        style: AppType.caption,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  decoration: panel(),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      _BackupAction(
                        onTap: ready ? backup.saveNow : null,
                        icon: Icons.backup_outlined,
                        label: 'إنشاء نسخة الآن',
                      ),
                      const Divider(height: 1, color: AppColors.border),
                      _BackupAction(
                        onTap: !ready
                            ? null
                            : () => backup.restore(
                                (date) async =>
                                    context.mounted &&
                                    await confirmBackupRestore(context, date),
                              ),
                        icon: Icons.restore,
                        label: 'استعادة النسخة الاحتياطية',
                      ),
                    ],
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

class _BackupAction extends StatelessWidget {
  const _BackupAction({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onTap != null,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Row(
          children: [
            Icon(icon, size: 21, color: AppColors.muted),
            const SizedBox(width: 13),
            Expanded(
              child: Text(
                label,
                style: AppType.body.copyWith(
                  color: onTap == null ? AppColors.muted : AppColors.text,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
