import 'package:baqi/features/tasks/domain/task.dart';
import 'package:baqi/features/tasks/domain/task_controller.dart';
import 'package:baqi/features/tasks/domain/task_dates.dart';
import 'package:baqi/features/tasks/domain/task_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryRepository implements TaskRepository {
  final records = <String, Task>{};
  @override
  Future<List<Task>> getTasks() async => records.values.toList();
  @override
  Future<void> upsertTask(Task task) async {
    records[task.id] = task;
  }

  @override
  Future<void> close() async {}
}

void main() {
  test(
    'multiple manual time entries accumulate and survive other task edits',
    () async {
      final repository = MemoryRepository();
      final controller = TaskController(
        repository,
        clock: () => DateTime(2026, 10, 13, 9),
      );
      await controller.load();
      await controller.create('مهمة');
      final original = controller.tasks.single;
      await controller.addTimeEntry(original, hours: 1, minutes: 30);
      await controller.addTimeEntry(original, hours: 0, minutes: 45);
      await controller.update(original, 'مهمة معدلة', bucket: TaskBucket.today);
      final task = controller.tasks.single;
      expect(task.totalMinutes, 135);
      expect(task.timeEntries.map((entry) => entry.minutes), [90, 45]);
      expect(repository.records[task.id]!.totalMinutes, 135);
      expect(
        () => controller.addTimeEntry(task, hours: 0, minutes: 0),
        throwsArgumentError,
      );
    },
  );

  test('removing one time entry persists the remaining entries', () async {
    final repository = MemoryRepository();
    final controller = TaskController(
      repository,
      clock: () => DateTime(2026, 10, 13, 9),
    );
    await controller.load();
    await controller.create('مهمة');
    final original = controller.tasks.single;
    await controller.addTimeEntry(original, hours: 1, minutes: 0);
    await controller.addTimeEntry(original, hours: 0, minutes: 20);
    final beforeDelete = controller.tasks.single;
    final deletedId = beforeDelete.timeEntries.first.id;
    await controller.removeTimeEntry(original, deletedId);
    final remaining = controller.tasks.single;
    expect(remaining.timeEntries.map((entry) => entry.minutes), [20]);
    expect(remaining.totalMinutes, 20);
    expect(repository.records[remaining.id]!.timeEntries.single.minutes, 20);
  });

  test('create, move, complete, restore and history grouping', () async {
    final repository = MemoryRepository();
    var now = DateTime(2026, 10, 11, 10, 24);
    final controller = TaskController(repository, clock: () => now);
    await controller.load();
    await controller.create('  مراجعة التصميم  ');
    var task = controller.tasks.single;
    expect(task.title, 'مراجعة التصميم');
    expect(task.bucket, TaskBucket.today);
    await controller.move(task, TaskBucket.tomorrow);
    task = controller.tasks.single;
    expect(task.scheduledDate, DateTime(2026, 10, 12));
    now = DateTime(2026, 10, 12, 8);
    expect(visibleBucket(task, now), TaskBucket.today);
    await controller.complete(task);
    task = controller.tasks.single;
    expect(task.completedAt, now);
    expect(completedByDay(controller.tasks)[DateTime(2026, 10, 12)], [task]);
    await controller.restore(task);
    task = controller.tasks.single;
    expect(task.completedAt, isNull);
    expect(task.bucket, TaskBucket.today);
    expect(task.scheduledDate, isNull);
    expect(completedByDay(controller.tasks), isEmpty);
    await controller.delete(task);
    expect(controller.tasks, isEmpty);
    expect(repository.records.values.single.isDeleted, isTrue);
  });

  test('tomorrow moves to today at 5 AM, including after missed days', () {
    final task = Task(
      id: 'a',
      title: 'مهمة',
      bucket: TaskBucket.tomorrow,
      createdAt: DateTime(2026, 10, 10),
      updatedAt: DateTime(2026, 10, 10),
      scheduledDate: DateTime(2026, 10, 11),
    );
    expect(
      visibleBucket(task, DateTime(2026, 10, 11, 4, 59)),
      TaskBucket.tomorrow,
    );
    expect(visibleBucket(task, DateTime(2026, 10, 11, 5)), TaskBucket.today);
    expect(visibleBucket(task, DateTime(2026, 10, 12)), TaskBucket.today);
  });

  test('later stays later and has no scheduled date', () async {
    final repository = MemoryRepository();
    final now = DateTime(2026, 10, 11, 20);
    final controller = TaskController(repository, clock: () => now);
    await controller.load();
    await controller.create('مكالمة', bucket: TaskBucket.later, tag: 'شخصي');
    expect(scheduleFor(TaskBucket.later, now), isNull);
    expect(
      visibleBucket(controller.tasks.single, DateTime(2026, 11, 11)),
      TaskBucket.later,
    );
    await controller.complete(controller.tasks.single);
    await controller.restore(controller.tasks.single);
    final task = controller.tasks.single;
    expect(task.bucket, TaskBucket.later);
    expect(task.scheduledDate, isNull);
    expect(task.tag, 'شخصي');
  });

  test(
    'editing a tomorrow task without moving it preserves its date',
    () async {
      final repository = MemoryRepository();
      var now = DateTime(2026, 10, 11, 10);
      final controller = TaskController(repository, clock: () => now);
      await controller.load();
      await controller.create('قديم', bucket: TaskBucket.tomorrow, tag: 'عمل');
      final original = controller.tasks.single;
      now = DateTime(2026, 10, 12, 4, 30);
      await controller.update(
        original,
        'جديد',
        bucket: TaskBucket.tomorrow,
        tag: 'شخصي',
      );
      final edited = controller.tasks.single;
      expect(edited.scheduledDate, DateTime(2026, 10, 12));
      expect(edited.tag, 'شخصي');
      expect(
        visibleBucket(edited, DateTime(2026, 10, 12, 5)),
        TaskBucket.today,
      );
    },
  );
}
