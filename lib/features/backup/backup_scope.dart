import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'backup_controller.dart';

String backupDateLabel(DateTime date) =>
    DateFormat('yyyy/MM/dd – HH:mm', 'ar').format(date.toLocal());

Future<bool> confirmBackupRestore(BuildContext context, DateTime date) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('استعادة النسخة الاحتياطية؟'),
        content: Text(
          'توجد نسخة في iCloud بتاريخ ${backupDateLabel(date)}.\n\nستُستبدل جميع بياناتك الحالية، بما فيها المهام وسجل الإنجازات وإدخالات الوقت والإعدادات، ببيانات هذه النسخة.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('استعادة'),
          ),
        ],
      ),
    ) ??
    false;

class BackupScope extends InheritedNotifier<BackupController> {
  const BackupScope({
    super.key,
    required BackupController controller,
    required super.child,
  }) : super(notifier: controller);

  static BackupController? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BackupScope>()?.notifier;
}
