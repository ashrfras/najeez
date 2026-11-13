import 'dart:io';

import 'package:baqi/main.dart';
import 'package:baqi/features/tasks/data/sqlite_task_repository.dart';
import 'package:baqi/features/tasks/domain/task.dart';
import 'package:baqi/features/tasks/domain/task_controller.dart';
import 'package:baqi/features/tasks/presentation/focus_bar.dart';
import 'package:baqi/features/tasks/presentation/task_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'widget_test.dart' show MemoryRepository;

class FocusRepository extends MemoryRepository {
  FocusSession? session;
  bool fail = false;
  @override
  Future<FocusSession?> getFocusSession() async => session;
  @override
  Future<void> saveFocusSession(FocusSession? value, {Task? task}) async {
    if (fail) throw StateError('disk full');
    if (task != null) await upsertTask(task);
    session = value;
  }
}

void main() {
  test(
    'focus survives SQLite reopen and records elapsed time once without completion',
    () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final directory = await Directory.systemTemp.createTemp('focus_test');
      addTearDown(() => directory.delete(recursive: true));
      final path = '${directory.path}/tasks.db';
      var now = DateTime.utc(2026, 11, 12, 10);
      var repository = await SqliteTaskRepository.open(databasePath: path);
      final controller = TaskController(repository, clock: () => now);
      await controller.load();
      await controller.create('تقرير');
      await controller.addTimeEntry(
        controller.tasks.single,
        hours: 0,
        minutes: 5,
      );
      await controller.startFocus(controller.tasks.single);
      controller.dispose();
      await repository.close();
      now = now.add(const Duration(hours: 3, seconds: 12));
      repository = await SqliteTaskRepository.open(databasePath: path);
      final reopened = TaskController(repository, clock: () => now);
      await reopened.load();
      expect(reopened.focusElapsed, const Duration(hours: 3, seconds: 12));
      await reopened.finishFocus();
      await reopened.finishFocus();
      expect(reopened.tasks.single.totalMinutes, 185);
      expect(reopened.tasks.single.timeEntries.length, 2);
      expect(reopened.tasks.single.isCompleted, isFalse);
      expect(await repository.getFocusSession(), isNull);
      reopened.dispose();
      await repository.close();
    },
  );

  test(
    'switch requires confirmation and failed saving preserves session and entries',
    () async {
      var now = DateTime.utc(2026, 11, 12);
      final repository = FocusRepository();
      final controller = TaskController(repository, clock: () => now);
      addTearDown(controller.dispose);
      await controller.load();
      await controller.create('أ');
      final first = controller.tasks.single;
      await controller.create('ب');
      final second = controller.tasks.first;
      await controller.startFocus(first);
      now = now.add(const Duration(minutes: 2));
      await expectLater(controller.startFocus(second), throwsStateError);
      repository.fail = true;
      await expectLater(controller.finishFocus(), throwsStateError);
      expect(controller.focusedTask?.id, first.id);
      expect(
        controller.tasks.every((task) => task.timeEntries.isEmpty),
        isTrue,
      );
      repository.fail = false;
      await Future.wait([
        controller.startFocus(second, finishPrevious: true),
        controller.startFocus(second, finishPrevious: true),
      ]);
      expect(controller.focusedTask?.id, second.id);
      expect(
        controller.tasks.firstWhere((task) => task.id == first.id).totalMinutes,
        2,
      );
      await controller.setTimeTrackingEnabled(false);
      expect(controller.focusSession, isNull);
      expect(
        controller.tasks
            .firstWhere((task) => task.id == second.id)
            .totalMinutes,
        0,
      );
    },
  );

  for (final (duration, expected) in [
    (Duration.zero, 0),
    (const Duration(seconds: 39), 0),
    (const Duration(seconds: 40), 0),
    (const Duration(seconds: 59, milliseconds: 999), 0),
    (const Duration(minutes: 1), 1),
    (const Duration(minutes: 20, seconds: 39, milliseconds: 999), 20),
    (const Duration(minutes: 20, seconds: 40), 21),
    (const Duration(minutes: 20, seconds: 59), 21),
    (const Duration(minutes: 21), 21),
  ]) {
    test('focus duration $duration records $expected minutes', () async {
      var now = DateTime.utc(2026, 11, 12);
      final repository = FocusRepository();
      final controller = TaskController(repository, clock: () => now);
      addTearDown(controller.dispose);
      await controller.load();
      await controller.create('مهمة');
      await controller.addTimeEntry(
        controller.tasks.single,
        hours: 0,
        minutes: 5,
      );
      await controller.startFocus(controller.tasks.single);
      now = now.add(duration);
      await controller.finishFocus();
      expect(controller.tasks.single.totalMinutes, 5 + expected);
      expect(controller.tasks.single.timeEntries.length, expected == 0 ? 1 : 2);
      expect(controller.tasks.single.isCompleted, isFalse);
      expect(controller.focusSession, isNull);
      expect(await repository.getFocusSession(), isNull);
    });
  }

  for (final viaMenu in [false, true]) {
    testWidgets('focus completion toast via ${viaMenu ? 'menu' : 'bar'}', (
      tester,
    ) async {
      var now = DateTime.utc(2026, 11, 12);
      final repository = FocusRepository();
      final controller = TaskController(repository, clock: () => now);
      addTearDown(controller.dispose);
      await controller.load();
      await controller.create('مهمة');
      await controller.startFocus(controller.tasks.single);
      await tester.pumpWidget(
        BaqiApp(controller: controller, splashDuration: Duration.zero),
      );
      now = now.add(const Duration(minutes: 23, seconds: 40));
      if (viaMenu) {
        await tester.tap(find.widgetWithText(TaskRow, 'مهمة'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('إنهاء التركيز'));
      } else {
        await tester.tap(find.byKey(const ValueKey('finish-focus')));
      }
      await tester.pumpAndSettle();
      expect(find.text('تم تسجيل 24 دقيقة من التركيز'), findsOneWidget);
      expect(controller.tasks.single.totalMinutes, 24);
      expect(find.byType(FocusBar), findsNothing);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.text('تم تسجيل 24 دقيقة من التركيز'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
    'no recording toast for failed save or a session under one minute',
    (tester) async {
      var now = DateTime.utc(2026, 11, 12);
      final repository = FocusRepository();
      final controller = TaskController(repository, clock: () => now);
      addTearDown(controller.dispose);
      await controller.load();
      await controller.create('مهمة');
      await controller.startFocus(controller.tasks.single);
      await tester.pumpWidget(
        BaqiApp(controller: controller, splashDuration: Duration.zero),
      );
      now = now.add(const Duration(minutes: 24));
      repository.fail = true;
      await tester.tap(find.byKey(const ValueKey('finish-focus')));
      await tester.pumpAndSettle();
      expect(find.textContaining('تم تسجيل'), findsNothing);
      expect(find.byType(FocusBar), findsOneWidget);
      repository.fail = false;
      now = now
          .subtract(const Duration(minutes: 24))
          .add(const Duration(seconds: 59));
      await tester.tap(find.byKey(const ValueKey('finish-focus')));
      await tester.pumpAndSettle();
      expect(find.textContaining('تم تسجيل'), findsNothing);
      expect(controller.tasks.single.timeEntries, isEmpty);
      expect(find.byType(FocusBar), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('focus bar fits iPhone safe area; switch can cancel or save', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = FakeViewPadding(bottom: 34);
    addTearDown(tester.view.reset);
    var now = DateTime.utc(2026, 11, 12);
    final controller = TaskController(FocusRepository(), clock: () => now);
    addTearDown(controller.dispose);
    await controller.load();
    await controller.create('الأولى');
    await controller.create('الثانية');
    await tester.pumpWidget(
      BaqiApp(controller: controller, splashDuration: Duration.zero),
    );
    await tester.tap(find.text('الأولى'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ابدأ التركيز'));
    await tester.pumpAndSettle();
    expect(find.byType(FocusBar), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Icon && widget.semanticLabel == 'قيد التركيز',
      ),
      findsOneWidget,
    );
    final bar = tester.getRect(find.byKey(const ValueKey('focus-bar')));
    expect(bar.bottom, lessThanOrEqualTo(844 - 34));
    expect(tester.getRect(find.byType(Navigator)).bottom, 844);
    expect(find.byType(BackdropFilter), findsOneWidget);
    final decoration =
        tester
                .widget<Container>(find.byKey(const ValueKey('focus-bar')))
                .decoration!
            as BoxDecoration;
    expect(decoration.color!.a, lessThan(1));
    now = now.add(const Duration(minutes: 12, seconds: 34));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('00:12:34'), findsOneWidget);
    await tester.tap(find.widgetWithText(TaskRow, 'الأولى'));
    await tester.pumpAndSettle();
    expect(find.text('إنهاء التركيز'), findsOneWidget);
    Navigator.of(tester.element(find.text('إنهاء التركيز'))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TaskRow, 'الثانية'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ابدأ التركيز'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();
    expect(controller.focusedTask?.title, 'الأولى');
    await tester.tap(find.widgetWithText(TaskRow, 'الثانية'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ابدأ التركيز'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حفظ وبدء التركيز'));
    await tester.pumpAndSettle();
    expect(controller.focusedTask?.title, 'الثانية');
    expect(find.text('تم تسجيل 12 دقيقة من التركيز'), findsOneWidget);
    expect(
      controller.tasks
          .firstWhere((task) => task.title == 'الأولى')
          .totalMinutes,
      12,
    );
    await tester.tap(find.byKey(const ValueKey('finish-focus')));
    await tester.pumpAndSettle();
    expect(find.byType(FocusBar), findsNothing);
    expect(controller.tasks.every((task) => !task.isCompleted), isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
