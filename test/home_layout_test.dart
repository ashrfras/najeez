import 'package:baqi/main.dart';
import 'package:baqi/features/tasks/domain/task.dart';
import 'package:baqi/features/tasks/domain/task_controller.dart';
import 'package:baqi/features/tasks/domain/task_repository.dart';
import 'package:baqi/features/tasks/presentation/home_screen.dart';
import 'package:baqi/features/tasks/presentation/task_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class VisualRepository extends TaskRepository {
  @override
  Future<List<Task>> getTasks() async {
    final now = DateTime(2026, 10, 11, 10, 24);
    Task task(
      String id,
      String title,
      TaskBucket bucket, {
      DateTime? completed,
    }) => Task(
      id: id,
      title: title,
      bucket: bucket,
      createdAt: now,
      updatedAt: now,
      completedAt: completed,
      scheduledDate: bucket == TaskBucket.tomorrow
          ? DateTime(2026, 10, 12)
          : null,
    );
    return [
      task('1', 'إنهاء صفحة التسجيل في دارجار', TaskBucket.today),
      task('2', 'مراجعة تصميم الجبة', TaskBucket.today),
      task('3', 'إرسال الملاحظات للصانع', TaskBucket.today),
      task('4', 'تجربة النسخة الجديدة', TaskBucket.tomorrow),
      task('5', 'مراجعة الملفات الجديدة', TaskBucket.later),
      task('6', 'تعديل مشكلة Firebase', TaskBucket.today, completed: now),
    ];
  }

  @override
  Future<void> upsertTask(Task task) async {}
  @override
  Future<void> reset() async {}

  @override
  Future<void> close() async {}
}

void main() {
  for (final bottomInset in [0.0, 34.0]) {
    testWidgets('home scrolls to the edge with $bottomInset bottom inset', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 600);
      tester.view.viewPadding = FakeViewPadding(top: 47, bottom: bottomInset);
      tester.view.padding = FakeViewPadding(top: 47, bottom: bottomInset);
      addTearDown(tester.view.reset);
      final controller = TaskController(
        VisualRepository(),
        clock: () => DateTime(2026, 10, 11, 10, 24),
      );
      addTearDown(controller.dispose);
      await controller.load();
      await tester.pumpWidget(
        BaqiApp(controller: controller, splashDuration: Duration.zero),
      );
      await tester.pumpAndSettle();

      final scroll = find.descendant(
        of: find.byType(HomeScreen),
        matching: find.byType(CustomScrollView),
      );
      expect(tester.getRect(scroll).top, 0);
      expect(tester.getRect(scroll).bottom, 600);
      final position = tester
          .state<ScrollableState>(
            find.descendant(of: scroll, matching: find.byType(Scrollable)),
          )
          .position;
      expect(position.maxScrollExtent, greaterThan(0));
      await tester.drag(scroll, const Offset(0, -1000));
      await tester.pumpAndSettle();
      expect(position.pixels, closeTo(position.maxScrollExtent, .01));
      expect(
        tester.getRect(find.byType(TaskSection).last).bottom,
        closeTo(600 - bottomInset - 28, .01),
      );
      expect(find.text('تعديل مشكلة Firebase').hitTestable(), findsOneWidget);

      // Scaffold still resizes for the keyboard without duplicating its inset.
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      tester.view.padding = const FakeViewPadding(top: 47);
      await tester.pumpAndSettle();
      expect(tester.getRect(scroll).bottom, 300);
      await tester.drag(scroll, const Offset(0, -1000));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byType(TaskSection).last).bottom,
        closeTo(300 - 28, .01),
      );

      tester.view.viewInsets = FakeViewPadding.zero;
      tester.view.padding = FakeViewPadding(top: 47, bottom: bottomInset);
      await tester.pumpAndSettle();
      expect(tester.getRect(scroll).bottom, 600);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('home fits a compact phone in RTL', (tester) async {
    await (FontLoader('Plex Arabic')
          ..addFont(
            rootBundle.load('assets/fonts/IBMPlexSansArabic-Regular.ttf'),
          )
          ..addFont(rootBundle.load('assets/fonts/IBMPlexSansArabic-Bold.ttf')))
        .load();
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final controller = TaskController(
      VisualRepository(),
      clock: () => DateTime(2026, 10, 11, 10, 24),
    );
    await controller.load();
    await tester.pumpWidget(
      BaqiApp(controller: controller, splashDuration: Duration.zero),
    );
    await tester.pumpAndSettle();
    expect(find.text('اليوم'), findsOneWidget);
    expect(find.text('عمل اليوم'), findsOneWidget);
    expect(find.text('0د'), findsOneWidget);
    expect(find.text('متوسط 7 أيام'), findsOneWidget);
    expect(find.text('-'), findsOneWidget);
    expect(tester.getCenter(find.byType(Image)).dx, closeTo(195, 0.5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('task composer fits a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(960, 1920);
    tester.view.devicePixelRatio = 3;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final controller = TaskController(VisualRepository());
    await controller.load();
    await tester.pumpWidget(
      BaqiApp(controller: controller, splashDuration: Duration.zero),
    );
    await tester.tap(find.text('أضف مهمة ...'));
    await tester.pumpAndSettle();
    expect(find.text('إضافة مهمة'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
