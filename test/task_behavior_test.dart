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
