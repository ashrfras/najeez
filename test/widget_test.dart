import 'package:baqi/main.dart';
import 'package:baqi/features/tasks/domain/task_controller.dart';
import 'package:baqi/features/tasks/domain/task.dart';
import 'package:baqi/features/tasks/domain/task_repository.dart';
import 'package:baqi/features/tasks/presentation/task_list_screen.dart';
import 'package:baqi/features/tasks/presentation/task_widgets.dart';
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
  testWidgets('other sections keep full counts and bounded previews', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final now = DateTime(2026, 10, 11, 10);
    final repository = MemoryRepository();
    for (var i = 0; i < 3; i++) {
      repository.tasks.add(
        Task(
          id: 'tomorrow$i',
          title: 'غد $i',
          bucket: TaskBucket.tomorrow,
          createdAt: now,
          updatedAt: now,
          scheduledDate: DateTime(2026, 10, 12),
        ),
      );
      repository.tasks.add(
        Task(
          id: 'later$i',
          title: 'مؤجل $i',
          bucket: TaskBucket.later,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
    for (var i = 0; i < 5; i++) {
      repository.tasks.add(
        Task(
          id: 'done$i',
          title: 'مكتمل $i',
          bucket: TaskBucket.today,
          createdAt: now,
          updatedAt: now,
          completedAt: now.add(Duration(minutes: i)),
        ),
      );
    }
    final controller = TaskController(repository, clock: () => now);
    await controller.load();
    await tester.pumpWidget(
      BaqiApp(controller: controller, splashDuration: Duration.zero),
    );
    final sections = find.byType(TaskSection);
    expect(
      find.descendant(of: sections.at(1), matching: find.byType(TaskRow)),
      findsNWidgets(2),
    );
    expect(
      find.descendant(of: sections.at(2), matching: find.byType(TaskRow)),
      findsNWidgets(2),
    );
    expect(
      find.descendant(of: sections.at(3), matching: find.byType(TaskRow)),
      findsNWidgets(3),
    );
    expect(find.text('مكتمل 4'), findsOneWidget);
    expect(find.text('مكتمل 1'), findsNothing);
    expect(find.text('عرض 2 مهام أخرى'), findsOneWidget);
    expect(find.text('عرض 1 مهام أخرى'), findsNWidgets(2));
  });

  testWidgets('today preview opens the live full list', (tester) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final repository = MemoryRepository();
    final controller = TaskController(repository);
    await controller.load();
    for (var i = 1; i <= 7; i++) {
      await controller.create('مهمة $i');
    }
    await tester.pumpWidget(
      BaqiApp(controller: controller, splashDuration: Duration.zero),
    );
    expect(find.byType(TaskRow), findsNWidgets(5));
    expect(find.text('عرض 2 مهام أخرى'), findsOneWidget);
    expect(
      find.descendant(
        of: find.widgetWithText(TaskSection, 'اليوم'),
        matching: find.text('7'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('عرض 2 مهام أخرى'));
    await tester.pumpAndSettle();
    expect(find.byType(TaskListScreen), findsOneWidget);
    expect(find.byType(TaskRow), findsNWidgets(7));
    await tester.tap(find.text('مهمة 7'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تمت المهمة'));
    await tester.pumpAndSettle();
    expect(find.byType(TaskRow), findsNWidgets(6));

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.byType(TaskRow), findsNWidgets(6));
    expect(find.text('عرض 1 مهام أخرى'), findsOneWidget);
  });

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
