import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:baqi/features/backup/backup_controller.dart';
import 'package:baqi/features/backup/cloud_backup.dart';
import 'package:baqi/features/tasks/data/sqlite_task_repository.dart';
import 'package:baqi/features/tasks/domain/task.dart';
import 'package:baqi/features/tasks/domain/task_controller.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class FakeCloud extends CloudBackup {
  @override
  bool get supported => true;
  CloudCopy? copy;
  Object? failure;
  int saves = 0;
  Completer<void>? pending;
  final date = DateTime.utc(2026, 10, 19, 12);
  @override
  Future<void> checkAvailable() async {
    if (failure != null) throw failure!;
  }

  @override
  Future<DateTime?> latestDate() async {
    await checkAvailable();
    return copy?.date;
  }

  @override
  Future<DateTime> save(Uint8List data) async {
    saves++;
    await pending?.future;
    await checkAvailable();
    copy = CloudCopy(date, data);
    return date;
  }

  @override
  Future<CloudCopy?> read() async => copy;
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  late Directory directory;
  late SqliteTaskRepository repository;
  late TaskController tasks;
  late FakeCloud cloud;
  late BackupController backup;
  late DateTime now;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('najeez_backup_');
    repository = await SqliteTaskRepository.open(
      databasePath: '${directory.path}/db',
    );
    tasks = TaskController(repository);
    await tasks.load();
    cloud = FakeCloud();
    now = cloud.date;
    backup = BackupController(
      repository,
      tasks,
      cloud: cloud,
      clock: () => now,
    );
    await backup.loadSettings();
  });
  tearDown(() async {
    backup.dispose();
    tasks.dispose();
    await repository.close();
    await directory.delete(recursive: true);
  });

  test(
    'opt-in immediately saves, foreground waits 24h, manual ignores age, opt-out retains copy',
    () async {
      expect(backup.enabled, isFalse);
      await backup.foreground((_) async => false);
      expect(cloud.saves, 0);
      await backup.setEnabled(true);
      expect(cloud.saves, 1);
      expect(backup.lastSuccess, cloud.date);
      now = now.add(const Duration(hours: 23, minutes: 59));
      await backup.foreground((_) async => false);
      expect(cloud.saves, 1);
      await backup.saveNow();
      expect(cloud.saves, 2);
      now = now.add(const Duration(minutes: 1));
      await backup.foreground((_) async => false);
      expect(cloud.saves, 3);
      await backup.setEnabled(false);
      now = now.add(const Duration(days: 2));
      await backup.foreground((_) async => false);
      expect(cloud.saves, 3);
      expect(cloud.copy, isNotNull);
    },
  );

  test(
    'failed and overlapping saves never advance the successful date',
    () async {
      await backup.setEnabled(true);
      final previous = backup.lastSuccess;
      cloud.pending = Completer<void>();
      final saving = backup.saveNow();
      while (cloud.saves < 2) {
        await Future<void>.delayed(Duration.zero);
      }
      await backup.saveNow();
      await backup.restore((_) async => true);
      expect(cloud.saves, 2);
      expect(backup.lastSuccess, previous);
      cloud.failure = PlatformException(code: 'network');
      cloud.pending!.complete();
      await saving;
      expect(backup.lastSuccess, previous);
      expect(
        await repository.backupSetting('last_success'),
        previous!.toUtc().toIso8601String(),
      );
      expect(backup.busy, isFalse);
      expect(backup.message, contains('الإنترنت'));
    },
  );

  test(
    'successful first save is not offered as a newly discovered copy',
    () async {
      await backup.setEnabled(true);
      await backup.loadSettings();
      var prompts = 0;
      await backup.foreground((_) async {
        prompts++;
        return false;
      });
      expect(prompts, 0);
      expect(cloud.saves, 1);
    },
  );

  test('reset stops automatic backups and retains cloud copy', () async {
    await backup.setEnabled(true);
    final copy = cloud.copy;
    await backup.resetLocalData();
    expect(backup.enabled, isFalse);
    expect(backup.lastSuccess, isNull);
    expect(cloud.copy, same(copy));
    now = now.add(const Duration(days: 3));
    await backup.foreground((_) async => false);
    expect(cloud.saves, 1);
  });

  test(
    'unavailable account leaves opt-in disabled and preserves local data',
    () async {
      await tasks.create('محلي');
      cloud.failure = PlatformException(code: 'unavailable');
      await backup.setEnabled(true);
      expect(backup.enabled, isFalse);
      expect(backup.lastSuccess, isNull);
      expect((await repository.getTasks()).single.title, 'محلي');
      expect(backup.message, contains('iCloud غير متاح'));
    },
  );

  test(
    'restore round trip includes completed/deleted history, time, pins and settings',
    () async {
      final date = DateTime(2026, 10, 18);
      await repository.upsertTask(
        Task(
          id: 'task',
          title: 'مهمة',
          bucket: TaskBucket.tomorrow,
          createdAt: date,
          updatedAt: date,
          completedAt: date,
          pinnedAt: date,
          scheduledDate: date,
          tag: 'عمل',
          isDeleted: true,
          timeEntries: [TimeEntry(id: 'time', minutes: 95, createdAt: date)],
        ),
      );
      await tasks.setLogicalDayStart(240);
      await tasks.setTimeTrackingEnabled(false);
      await backup.saveNow();
      await repository.reset();
      await tasks.create('بيانات حالية');
      await backup.restore((date) async {
        expect(date, cloud.date);
        return true;
      });
      final restored = (await repository.getTasks()).single;
      expect(restored.id, 'task');
      expect(restored.completedAt, date);
      expect(restored.isDeleted, isTrue);
      expect(restored.pinnedAt, date);
      expect(restored.scheduledDate, date);
      expect(restored.tag, 'عمل');
      expect(restored.timeEntries.single.minutes, 95);
      expect(tasks.logicalDay.startMinutes, 240);
      expect(tasks.timeTrackingEnabled, isFalse);
      expect(backup.enabled, isFalse);
    },
  );

  test(
    'discovery offers dated restore once; cancellation does not overwrite cloud or local data',
    () async {
      await tasks.create('سحابي');
      await backup.saveNow();
      await repository.reset();
      await tasks.load();
      await tasks.create('محلي');
      await backup.loadSettings();
      var prompts = 0;
      await backup.foreground((date) async {
        prompts++;
        expect(date, cloud.date);
        return false;
      });
      await backup.foreground((_) async {
        prompts++;
        return true;
      });
      expect(prompts, 1);
      expect(tasks.tasks.single.title, 'محلي');
      expect(cloud.saves, 1);
      await backup.restore((_) async => true);
      expect(tasks.tasks.single.title, 'سحابي');
    },
  );

  test(
    'invalid backups and SQL failures roll back all local data and settings',
    () async {
      await tasks.create('محلي');
      await tasks.setLogicalDayStart(180);
      final payload =
          jsonDecode(utf8.decode(await repository.exportBackup()))
              as Map<String, dynamic>;
      final rows = payload['tasks'] as List;
      rows.add(
        rows.single,
      ); // Duplicate primary key fails after deletion/insertion.
      await expectLater(
        repository.importBackup(
          Uint8List.fromList(utf8.encode(jsonEncode(payload))),
          cloud.date,
        ),
        throwsA(isA<DatabaseException>()),
      );
      expect((await repository.getTasks()).single.title, 'محلي');
      expect(await repository.getLogicalDayStartMinutes(), 180);
      for (final data in ['{}', '{"version":99}', 'not json']) {
        await expectLater(
          repository.importBackup(
            Uint8List.fromList(utf8.encode(data)),
            cloud.date,
          ),
          throwsA(anything),
        );
      }
      expect((await repository.getTasks()).single.title, 'محلي');
    },
  );
}
