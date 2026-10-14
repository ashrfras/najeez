import 'package:baqi/main.dart';
import 'package:baqi/core/design.dart';
import 'package:baqi/features/tasks/domain/task_controller.dart';
import 'package:baqi/features/tasks/domain/task.dart';
import 'package:baqi/features/tasks/domain/task_repository.dart';
import 'package:baqi/features/tasks/presentation/task_list_screen.dart';
import 'package:baqi/features/tasks/presentation/task_widgets.dart';
import 'package:baqi/features/history/presentation/history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  testWidgets('task row places time before tag without an actions icon', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final now = DateTime(2026, 10, 13);
    var actions = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: TaskRow(
              task: Task(
                id: 'tagged-task',
                title: 'مهمة للتجربة',
                bucket: TaskBucket.today,
                createdAt: now,
                updatedAt: now,
                tag: 'عمل',
                timeEntries: [
                  TimeEntry(id: 'entry', minutes: 75, createdAt: now),
                ],
              ),
              onToggle: () {},
              onActions: () => actions++,
            ),
          ),
        ),
      ),
    );

    final time = find.text('◷ 1 س 15 د');
    final tag = find.text('عمل');
    expect(find.byIcon(Icons.more_horiz), findsNothing);
    expect(
      (tester.getCenter(time).dy - tester.getCenter(tag).dy).abs(),
      lessThan(8),
    );
    expect(tester.getCenter(time).dx, greaterThan(tester.getCenter(tag).dx));
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('مهمة للتجربة'));
    expect(actions, 1);
  });

  testWidgets('history shows total time beneath completed tasks', (
    tester,
  ) async {
    final now = DateTime(2026, 10, 13, 9);
    final repository = MemoryRepository();
    repository.tasks.add(
      Task(
        id: 'finished',
        title: 'مهمة مكتملة',
        bucket: TaskBucket.today,
        createdAt: now,
        updatedAt: now,
        completedAt: now,
        timeEntries: [
          TimeEntry(id: 'one', minutes: 50, createdAt: now),
          TimeEntry(id: 'two', minutes: 40, createdAt: now),
        ],
      ),
    );
    final controller = TaskController(repository, clock: () => now);
    await controller.load();
    await tester.pumpWidget(
      BaqiApp(controller: controller, splashDuration: Duration.zero),
    );
    await tester.tap(find.text('السجل'));
    await tester.pumpAndSettle();
    expect(find.byType(HistoryScreen), findsOneWidget);
    await tester.tap(find.text('الثلاثاء، 13 أكتوبر'));
    await tester.pumpAndSettle();
    expect(find.text('مهمة مكتملة'), findsOneWidget);
    expect(find.text('◷ 1 س 30 د'), findsOneWidget);
    expect(find.text('09:00'), findsOneWidget);
    await tester.tap(find.text('مهمة مكتملة'));
    await tester.pumpAndSettle();
    expect(find.text('اكتملت: الثلاثاء، 13 أكتوبر، 09:00'), findsOneWidget);
  });

  testWidgets('completed today shows completion time only in details', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final completedAt = DateTime(2026, 10, 13, 9, 37);
    final repository = MemoryRepository();
    repository.tasks.add(
      Task(
        id: 'finished',
        title: 'مهمة مكتملة',
        bucket: TaskBucket.today,
        createdAt: completedAt,
        updatedAt: completedAt,
        completedAt: completedAt,
      ),
    );
    final controller = TaskController(repository, clock: () => completedAt);
    await controller.load();
    await tester.pumpWidget(
      BaqiApp(controller: controller, splashDuration: Duration.zero),
    );
    expect(find.text('09:37'), findsNothing);
    await tester.tap(find.text('تم اليوم').last);
    await tester.pumpAndSettle();
    expect(find.byType(TaskListScreen), findsOneWidget);
    expect(find.text('09:37'), findsNothing);
    await tester.tap(find.text('مهمة مكتملة'));
    await tester.pumpAndSettle();
    expect(find.text('اكتملت: الثلاثاء، 13 أكتوبر، 09:37'), findsOneWidget);
  });

  testWidgets('time entries can be deleted from the entries sheet', (
    tester,
  ) async {
    final now = DateTime(2026, 10, 13, 9);
    final repository = MemoryRepository();
    repository.tasks.add(
      Task(
        id: 'timed',
        title: 'مهمة موقّتة',
        bucket: TaskBucket.today,
        createdAt: now,
        updatedAt: now,
        timeEntries: [
          TimeEntry(id: 'first', minutes: 30, createdAt: now),
          TimeEntry(id: 'second', minutes: 45, createdAt: now),
        ],
      ),
    );
    final controller = TaskController(repository, clock: () => now);
    await controller.load();
    await tester.pumpWidget(
      BaqiApp(controller: controller, splashDuration: Duration.zero),
    );
    await tester.tap(find.text('مهمة موقّتة'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('عرض إدخالات الوقت (2)'));
    await tester.pumpAndSettle();
    final deleteIcon = tester.widget<IconButton>(
      find.byKey(const ValueKey('delete-time-entry-second')),
    );
    expect(deleteIcon.color, AppColors.muted);
    expect(deleteIcon.iconSize, 18);
    await tester.tap(find.byKey(const ValueKey('delete-time-entry-second')));
    await tester.pumpAndSettle();
    expect(find.text('حذف إدخال الوقت؟'), findsOneWidget);
    expect(controller.tasks.single.totalMinutes, 75);
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();
    expect(controller.tasks.single.totalMinutes, 75);
    await tester.tap(find.byKey(const ValueKey('delete-time-entry-second')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حذف'));
    await tester.pumpAndSettle();
    expect(controller.tasks.single.totalMinutes, 30);
    expect(find.text('المجموع: 30 د'), findsOneWidget);
    expect(find.text('45 د'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('delete-time-entry-first')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حذف'));
    await tester.pumpAndSettle();
    expect(controller.tasks.single.timeEntries, isEmpty);
    expect(find.text('المجموع: 0 د'), findsOneWidget);
    expect(find.text('لا توجد إدخالات وقت'), findsOneWidget);
  });

  testWidgets('wheel-selected time appears in task details and list totals', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final controller = TaskController(
      MemoryRepository(),
      clock: () => DateTime(2026, 10, 13, 9),
    );
    await controller.load();
    await controller.create('تقرير');
    await tester.pumpWidget(
      BaqiApp(controller: controller, splashDuration: Duration.zero),
    );
    await tester.tap(find.text('تقرير'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إضافة وقت'));
    await tester.pumpAndSettle();
    final hoursPicker = find.byKey(const ValueKey('time-hours'));
    final minutesPicker = find.byKey(const ValueKey('time-minutes'));
    expect(find.byType(TextFormField), findsNothing);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'إضافة'))
          .onPressed,
      isNull,
    );
    tester
        .state<ScrollableState>(
          find.descendant(
            of: hoursPicker,
            matching: find.byWidgetPredicate((widget) => widget is Scrollable),
          ),
        )
        .position
        .jumpTo(38);
    tester
        .state<ScrollableState>(
          find.descendant(
            of: minutesPicker,
            matching: find.byWidgetPredicate((widget) => widget is Scrollable),
          ),
        )
        .position
        .jumpTo(25 * 38);
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'إضافة'))
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.text('إضافة'));
    await tester.pumpAndSettle();
    expect(controller.tasks.single.totalMinutes, 85);
    expect(find.text('عرض إدخالات الوقت (1)'), findsOneWidget);
    expect(find.text('1 س 25 د'), findsNothing);
    await tester.tap(find.text('عرض إدخالات الوقت (1)'));
    await tester.pumpAndSettle();
    expect(find.text('1 س 25 د'), findsOneWidget);
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(find.text('◷ 1 س 25 د'), findsOneWidget);
    await tester.tap(find.text('اليوم').first);
    await tester.pumpAndSettle();
    expect(find.byType(TaskListScreen), findsOneWidget);
    expect(find.text('◷ 1 س 25 د'), findsOneWidget);
  });

  testWidgets(
    'tomorrow and later hide preview totals but show them in full lists',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final now = DateTime(2026, 10, 13, 9);
      final repository = MemoryRepository();
      for (final bucket in [TaskBucket.tomorrow, TaskBucket.later]) {
        repository.tasks.add(
          Task(
            id: bucket.name,
            title: 'مهمة ${bucket.name}',
            bucket: bucket,
            createdAt: now,
            updatedAt: now,
            scheduledDate: bucket == TaskBucket.tomorrow
                ? DateTime(2026, 10, 14)
                : null,
            timeEntries: [
              TimeEntry(
                id: 'entry-${bucket.name}',
                minutes: 45,
                createdAt: now,
              ),
            ],
          ),
        );
      }
      final controller = TaskController(repository, clock: () => now);
      await controller.load();
      await tester.pumpWidget(
        BaqiApp(controller: controller, splashDuration: Duration.zero),
      );
      expect(find.text('◷ 45 د'), findsNothing);
      await tester.tap(find.text('غداً').last);
      await tester.pumpAndSettle();
      expect(find.text('◷ 45 د'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      await tester.tap(find.text('لاحقاً').last);
      await tester.pumpAndSettle();
      expect(find.text('◷ 45 د'), findsOneWidget);
    },
  );

  testWidgets('checking a task animates and vibrates before completion', (
    tester,
  ) async {
    final now = DateTime(2026, 10, 13);
    final task = Task(
      id: 'animated-task',
      title: 'مهمة للتجربة',
      bucket: TaskBucket.today,
      createdAt: now,
      updatedAt: now,
    );
    final feedback = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          feedback.add(call.arguments as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    var toggles = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TaskRow(
            task: task,
            onToggle: () => toggles++,
            onActions: () {},
          ),
        ),
      ),
    );

    final checkbox = find.descendant(
      of: find.byType(TaskRow),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration! as BoxDecoration).shape == BoxShape.circle,
      ),
    );
    await tester.tap(checkbox.first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(feedback, ['HapticFeedbackType.mediumImpact']);
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(toggles, 0);

    await tester.pumpAndSettle();
    expect(toggles, 1);
  });

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
          title: 'مهمة طويلة للغد تحتاج إلى اختصار في البطاقة $i',
          bucket: TaskBucket.tomorrow,
          createdAt: now,
          updatedAt: now,
          scheduledDate: DateTime(2026, 10, 12),
        ),
      );
      repository.tasks.add(
        Task(
          id: 'later$i',
          title: 'مهمة مؤجلة طويلة تحتاج إلى اختصار في البطاقة $i',
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
    for (final sectionIndex in [1, 2]) {
      final row = find
          .descendant(
            of: sections.at(sectionIndex),
            matching: find.byType(TaskRow),
          )
          .first;
      final title = find.descendant(of: row, matching: find.byType(Text)).first;
      expect(tester.widget<Text>(title).maxLines, 1);
      expect(tester.widget<Text>(title).overflow, TextOverflow.ellipsis);
      final checkbox = find
          .descendant(
            of: row,
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Container &&
                  widget.decoration is BoxDecoration &&
                  (widget.decoration! as BoxDecoration).shape ==
                      BoxShape.circle,
            ),
          )
          .first;
      expect(tester.getSize(checkbox), const Size(18, 18));
    }
    final completedRow = find
        .descendant(of: sections.at(3), matching: find.byType(TaskRow))
        .first;
    expect(
      tester
          .widget<Text>(
            find
                .descendant(of: completedRow, matching: find.byType(Text))
                .first,
          )
          .maxLines,
      2,
    );
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
