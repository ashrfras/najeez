import 'package:baqi/main.dart';
import 'package:baqi/features/tasks/domain/task_controller.dart';
import 'package:baqi/features/tasks/domain/task.dart';
import 'package:baqi/features/tasks/domain/task_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryRepository implements TaskRepository {
  final tasks = <Task>[];
  @override
  Future<List<Task>> getTasks() async => tasks;
  @override
  Future<void> upsertTask(Task task) async {
    tasks.removeWhere((item) => item.id == task.id);
    tasks.add(task);
  }

  @override
  Future<void> close() async {}
}

void main() {
  testWidgets('capture opens composer and saves a new tag and bucket', (
    tester,
  ) async {
    final controller = TaskController(MemoryRepository());
    await controller.load();
    await tester.pumpWidget(
      BaqiApp(controller: controller, splashDuration: Duration.zero),
    );
    await tester.tap(find.text('أضف مهمة بسرعة ...'));
    await tester.pumpAndSettle();
    expect(find.text('إضافة مهمة'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'إرسال الملاحظات');
    await tester.tap(find.text('لاحقاً').last);
    await tester.tap(find.text('وسم جديد +'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'دارجار');
    await tester.tap(find.byTooltip('اعتماد الوسم'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إضافة'));
    await tester.pumpAndSettle();
    expect(controller.tasks.single.title, 'إرسال الملاحظات');
    expect(controller.tasks.single.bucket, TaskBucket.later);
    expect(controller.tasks.single.tag, 'دارجار');
    expect(find.text('إرسال الملاحظات'), findsOneWidget);
  });

  testWidgets('composer can reuse an existing tag', (tester) async {
    final controller = TaskController(MemoryRepository());
    await controller.load();
    await controller.create('مهمة سابقة', tag: 'شخصي');
    await tester.pumpWidget(
      BaqiApp(controller: controller, splashDuration: Duration.zero),
    );
    await tester.tap(find.text('أضف مهمة بسرعة ...'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'مهمة جديدة');
    await tester.tap(find.text('شخصي').last);
    await tester.tap(find.text('إضافة'));
    await tester.pumpAndSettle();
    expect(controller.tasks.first.tag, 'شخصي');
  });

  testWidgets('editing opens the full task screen and saves all fields', (
    tester,
  ) async {
    final controller = TaskController(MemoryRepository());
    await controller.load();
    await controller.create('عنوان قديم', tag: 'شخصي');
    await tester.pumpWidget(
      BaqiApp(controller: controller, splashDuration: Duration.zero),
    );
    await tester.tap(find.text('عنوان قديم'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تعديل المهمة'));
    await tester.pumpAndSettle();
    expect(find.text('تعديل المهمة'), findsOneWidget);
    expect(find.text('شخصي'), findsOneWidget);
    expect(find.text('غداً'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'عنوان جديد');
    await tester.tap(find.text('غداً'));
    await tester.tap(find.text('شخصي'));
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(controller.tasks.single.title, 'عنوان جديد');
    expect(controller.tasks.single.bucket, TaskBucket.tomorrow);
    expect(controller.tasks.single.tag, isNull);
  });
}
