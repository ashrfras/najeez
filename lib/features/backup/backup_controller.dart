import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../tasks/data/sqlite_task_repository.dart';
import '../tasks/domain/task_controller.dart';
import 'cloud_backup.dart';

class BackupController extends ChangeNotifier {
  BackupController(
    this.repository,
    this.tasks, {
    CloudBackup? cloud,
    DateTime Function()? clock,
  }) : cloud = cloud ?? CloudBackup(),
       clock = clock ?? DateTime.now;

  final SqliteTaskRepository repository;
  final TaskController tasks;
  final CloudBackup cloud;
  final DateTime Function() clock;
  bool enabled = false;
  bool busy = false;
  bool applyingRestore = false;
  bool _discoveryChecked = false;
  DateTime? lastSuccess;
  String? message;
  bool get supported => cloud.supported;

  Future<void> loadSettings() async {
    enabled = await repository.backupSetting('enabled') == 'true';
    lastSuccess = DateTime.tryParse(
      await repository.backupSetting('last_success') ?? '',
    );
    _discoveryChecked =
        await repository.backupSetting('discovery_checked') == 'true';
    notifyListeners();
  }

  void _message(String text) {
    message = text;
    notifyListeners();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (busy || !supported) return;
    busy = true;
    message = null;
    notifyListeners();
    try {
      await action();
    } catch (error) {
      _message(_errorMessage(error));
    } finally {
      busy = false;
      applyingRestore = false;
      notifyListeners();
    }
  }

  Future<void> resetLocalData() async {
    if (busy) throw StateError('A cloud operation is in progress');
    busy = true;
    notifyListeners();
    try {
      await tasks.reset();
      await loadSettings();
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> setEnabled(bool value) => _run(() async {
    if (value) await cloud.checkAvailable();
    await repository.setBackupSetting('enabled', '$value');
    enabled = value;
    notifyListeners();
    if (value) await _save();
  });

  Future<void> saveNow() => _run(_save);

  Future<void> _save() async {
    _message('جارٍ حفظ نسخة احتياطية في iCloud…');
    await cloud.checkAvailable();
    final data = await repository.exportBackup();
    final savedAt = await cloud.save(data);
    // CloudKit has acknowledged the complete asset before advancing this date.
    await repository.setBackupSetting(
      'last_success',
      savedAt.toUtc().toIso8601String(),
    );
    lastSuccess = savedAt;
    await repository.setBackupSetting('discovery_checked', 'true');
    _discoveryChecked = true;
    _message('تم حفظ النسخة الاحتياطية في iCloud.');
  }

  Future<void> foreground(
    Future<bool> Function(DateTime) confirm,
  ) => _run(() async {
    if (!_discoveryChecked) {
      // Retry discovery on a later foreground if the account/network is unavailable.
      final date = await cloud.latestDate();
      if (date != null) {
        await _restore(confirm);
      }
      await repository.setBackupSetting('discovery_checked', 'true');
      _discoveryChecked = true;
      // Never overwrite the discovered copy in the same foreground event.
      if (date != null) return;
    }
    if (enabled &&
        (lastSuccess == null ||
            clock().difference(lastSuccess!) >= const Duration(hours: 24))) {
      await _save();
    }
  });

  Future<void> restore(Future<bool> Function(DateTime) confirm) =>
      _run(() => _restore(confirm));

  Future<void> _restore(Future<bool> Function(DateTime) confirm) async {
    _message('جارٍ تحميل النسخة الاحتياطية من iCloud…');
    await cloud.checkAvailable();
    final copy = await cloud.read();
    if (copy == null) {
      _message('لا توجد نسخة احتياطية في iCloud.');
      return;
    }
    // Confirmation refers to the exact downloaded copy, even if another device saves.
    if (!await confirm(copy.date)) {
      _message('أُلغيت الاستعادة. لم تتغير بياناتك.');
      return;
    }
    applyingRestore = true;
    notifyListeners();
    await repository.importBackup(copy.data, copy.date);
    await tasks.load();
    await loadSettings();
    _message('تمت استعادة النسخة الاحتياطية.');
  }

  String _errorMessage(Object error) {
    if (error is PlatformException) {
      return switch (error.code) {
        'unavailable' =>
          'iCloud غير متاح. سجّل الدخول إلى حساب Apple وفعّل iCloud للتطبيق ثم حاول مجددًا.',
        'network' =>
          'تعذّر الاتصال بـ iCloud. تحقق من الإنترنت وحاول مجددًا. بياناتك المحلية محفوظة.',
        'quota' => 'مساحة iCloud غير كافية. وفّر مساحة ثم حاول مجددًا.',
        'conflict' => 'تغيّرت النسخة على جهاز آخر. حاول مجددًا.',
        _ => 'تعذّرت عملية iCloud. حاول مجددًا. بياناتك المحلية محفوظة.',
      };
    }
    return 'تعذّر حفظ النسخة أو استعادتها. بياناتك المحلية محفوظة؛ حاول مجددًا.';
  }
}
