import 'package:baqi/main.dart';
import 'package:baqi/features/tasks/domain/task.dart';
import 'package:baqi/features/tasks/domain/task_controller.dart';
import 'package:baqi/features/tasks/domain/task_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class VisualRepository implements TaskRepository {
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
  Future<void> close() async {}
}

void main() {
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
    await tester.tap(find.text('أضف مهمة بسرعة ...'));
    await tester.pumpAndSettle();
    expect(find.text('إضافة مهمة'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
