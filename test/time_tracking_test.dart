import 'package:baqi/main.dart';
import 'package:baqi/features/tasks/domain/completion_stats.dart';
import 'package:baqi/features/tasks/domain/task.dart';
import 'package:baqi/features/tasks/domain/task_controller.dart';
import 'package:baqi/features/tasks/domain/task_dates.dart';
import 'package:baqi/features/tasks/presentation/task_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test.dart' show MemoryRepository;

class TrackingRepository extends MemoryRepository {
  bool enabled = true;
  bool failSave = false;
  @override
  Future<bool> getTimeTrackingEnabled() async => enabled;
  @override
  Future<void> setTimeTrackingEnabled(bool value) async {
    if (failSave) throw StateError('save failed');
    enabled = value;
  }
}

Task completed(String id, DateTime? date, {bool deleted = false}) => Task(
  id: id,
  title: id,
  bucket: TaskBucket.today,
  createdAt: DateTime(2026, 10, 1),
  updatedAt: DateTime(2026, 10, 17),
  completedAt: date,
  isDeleted: deleted,
  timeEntries: [
    TimeEntry(id: id, minutes: 90, createdAt: DateTime(2026, 10, 17, 10)),
  ],
);

void main() {
  test('completion average includes empty logical days and excludes today', () {
    final stats = CompletionStats(
      [
        completed('today', DateTime(2026, 10, 17, 4)),
        completed('yesterday', DateTime(2026, 10, 17, 3, 59)),
        completed('first', DateTime(2026, 10, 10, 4)),
        completed('outside', DateTime(2026, 10, 10, 3, 59)),
        completed('future', DateTime(2026, 10, 18, 4)),
        completed('deleted', DateTime(2026, 10, 16, 12), deleted: true),
        completed('open', null),
      ],
      DateTime(2026, 10, 17, 12),
      const LogicalDay(240),
    );
    expect(stats.todayCount, 1);
    expect(stats.averageCount, 2 / 7);
    expect(stats.averageLabel, '0.3');
    expect(CompletionStats([], DateTime(2026, 10, 17)).averageLabel, '0');
    final fullWeek = CompletionStats([
      for (var day = 10; day <= 16; day++)
        completed('$day', DateTime(2026, 10, day, 12)),
    ], DateTime(2026, 10, 17));
    expect(fullWeek.averageLabel, '1');
  });

  test('failed setting save preserves mode and task data', () async {
    final repository = TrackingRepository()
      ..tasks.add(completed('done', DateTime(2026, 10, 17)));
    final controller = TaskController(repository);
    addTearDown(controller.dispose);
    await controller.load();
    repository.failSave = true;
    await expectLater(
      controller.setTimeTrackingEnabled(false),
      throwsStateError,
    );
    expect(controller.timeTrackingEnabled, isTrue);
    repository.failSave = false;
    await controller.setTimeTrackingEnabled(false);
    final reopened = TaskController(repository);
    addTearDown(reopened.dispose);
    await reopened.load();
    expect(reopened.timeTrackingEnabled, isFalse);
    expect(reopened.tasks.single.totalMinutes, 90);
    await reopened.setTimeTrackingEnabled(true);
    expect(reopened.tasks.single.totalMinutes, 90);
  });

  testWidgets(
    'settings switches home, task actions and full list without data loss',
    (tester) async {
      final repository = TrackingRepository()
        ..tasks.addAll([
          completed('مهمة منجزة', DateTime(2026, 10, 17, 9)),
          completed('مهمة مفتوحة', null),
          completed('إنجاز سابق', DateTime(2026, 10, 16, 10)),
        ]);
      final controller = TaskController(
        repository,
        clock: () => DateTime(2026, 10, 17, 12),
      );
      await controller.load();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        BaqiApp(controller: controller, splashDuration: Duration.zero),
      );
      await tester.pumpAndSettle();
      expect(find.text('4س 30د'), findsOneWidget);
      expect(find.text('تركيز اليوم'), findsOneWidget);
      expect(find.text('إنجاز اليوم'), findsNothing);
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Switch>(find.byKey(const ValueKey('time-tracking-switch')))
            .value,
        isTrue,
      );
      await tester.tap(find.byKey(const ValueKey('time-tracking-switch')));
      await tester.pumpAndSettle();
      expect(find.text('تعطيل تتبع الوقت؟'), findsOneWidget);
      expect(
        find.text(
          'سيتم إخفاء أدوات تسجيل الوقت، وستعتمد الإحصاءات على عدد المهام المكتملة بدلاً من الوقت المقضي.\n\nستبقى جميع الأوقات المسجلة محفوظة، ويمكنك استعادتها بإعادة تفعيل الميزة في أي وقت.',
        ),
        findsOneWidget,
      );
      expect(repository.enabled, isTrue);
      expect(controller.timeTrackingEnabled, isTrue);
      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Switch>(find.byKey(const ValueKey('time-tracking-switch')))
            .value,
        isTrue,
      );
      await tester.tap(find.byKey(const ValueKey('time-tracking-switch')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تعطيل'));
      await tester.pumpAndSettle();
      expect(repository.enabled, isFalse);
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      expect(find.text('4س 30د'), findsNothing);
      expect(find.text('إنجاز اليوم'), findsOneWidget);
      expect(find.text('تركيز اليوم'), findsNothing);
      expect(find.text('0.1'), findsOneWidget);
      for (final row in tester.widgetList<TaskRow>(find.byType(TaskRow))) {
        expect(row.showTime, isFalse);
      }
      await tester.tap(find.text('مهمة مفتوحة'));
      await tester.pumpAndSettle();
      expect(find.text('إضافة وقت'), findsNothing);
      expect(find.textContaining('مدة التركيز'), findsNothing);
      expect(find.textContaining('عرض إدخالات الوقت'), findsNothing);
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('تم اليوم').first);
      await tester.pumpAndSettle();
      expect(tester.widget<TaskRow>(find.byType(TaskRow)).showTime, isFalse);
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('time-tracking-switch')));
      await tester.pumpAndSettle();
      expect(find.text('تفعيل تتبع الوقت؟'), findsOneWidget);
      expect(
        find.text(
          'ستتمكن من تسجيل الوقت الذي تقضيه على مهامك، وستعتمد الإحصاءات على الوقت المسجل وتوزيعه بين التصنيفات.\n\nسيُعاد عرض جميع الأوقات التي سجلتها سابقاً، إن وجدت.',
        ),
        findsOneWidget,
      );
      expect(repository.enabled, isFalse);
      expect(controller.timeTrackingEnabled, isFalse);
      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Switch>(find.byKey(const ValueKey('time-tracking-switch')))
            .value,
        isFalse,
      );
      await tester.tap(find.byKey(const ValueKey('time-tracking-switch')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تفعيل'));
      await tester.pumpAndSettle();
      expect(repository.enabled, isTrue);
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      expect(find.text('4س 30د'), findsOneWidget);
      expect(find.text('تركيز اليوم'), findsOneWidget);
      expect(find.text('إنجاز اليوم'), findsNothing);
      await tester.tap(find.text('مهمة مفتوحة'));
      await tester.pumpAndSettle();
      expect(find.text('إضافة وقت'), findsOneWidget);
      expect(find.text('مدة التركيز: 1 س 30 د'), findsOneWidget);
      expect(find.text('عرض إدخالات الوقت (1)'), findsOneWidget);
      expect(controller.tasks.every((task) => task.totalMinutes == 90), isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}
