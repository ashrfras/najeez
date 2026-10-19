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
                            activeTrackColor: AppColors.blue,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'تفعيل الحفظ السحابي يحفظ جميع مهامك وسجل الإنجازات وإدخالات الوقت والإعدادات، تلقائيا كل 24 ساعة على iCloud.',
                        style: AppType.caption,
                      ),
                      const Divider(height: 32, color: AppColors.border),
                      const Text(
                        'آخر نسخة احتياطية ناجحة',
                        style: AppType.body,
                      ),
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
                OutlinedButton.icon(
                  onPressed: ready ? backup.saveNow : null,
                  icon: const Icon(Icons.backup_outlined),
                  label: const Text('إنشاء نسخة الآن'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: !ready
                      ? null
                      : () => backup.restore(
                          (date) async =>
                              context.mounted &&
                              await confirmBackupRestore(context, date),
                        ),
                  icon: const Icon(Icons.restore),
                  label: const Text('استعادة النسخة الاحتياطية'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
