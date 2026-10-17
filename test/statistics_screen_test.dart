import 'dart:io';
import 'dart:ui' as ui;

import 'package:baqi/core/design.dart';
import 'package:baqi/features/statistics/presentation/statistics_screen.dart';
import 'package:baqi/features/tasks/domain/task.dart';
import 'package:baqi/features/tasks/domain/task_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test.dart' show MemoryRepository;

void main() {
  final now = DateTime(2026, 10, 17, 12);
  Future<TaskController> mount(
    WidgetTester tester,
    List<Task> tasks, {
    double width = 390,
    int startMinutes = 0,
    bool tracking = true,
  }) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final repository = MemoryRepository()..tasks.addAll(tasks);
    final controller = TaskController(repository, clock: () => now);
    await controller.load();
    await controller.setLogicalDayStart(startMinutes);
    await controller.setTimeTrackingEnabled(tracking);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: AppColors.background,
          fontFamily: 'Plex Arabic',
          colorScheme: const ColorScheme.dark(
            primary: AppColors.blue,
            surface: AppColors.surface,
          ),
        ),
        home: RepaintBoundary(
          key: const ValueKey('preview'),
          child: StatisticsScreen(controller: controller, onActions: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  Task task(
    String title,
    int hour, {
    int minutes = 0,
    String? tag,
    DateTime? date,
  }) {
    final completed = date ?? DateTime(2026, 10, 17, hour);
    return Task(
      id: title,
      title: title,
      bucket: TaskBucket.today,
      createdAt: completed,
      updatedAt: completed,
      completedAt: completed,
      tag: tag,
      timeEntries: minutes == 0
          ? []
          : [TimeEntry(id: title, minutes: minutes, createdAt: completed)],
    );
  }

  testWidgets(
    'task mode counts only completions, includes untagged and restores time',
    (tester) async {
      final controller = await mount(
        tester,
        [
          task('مهمة عمل', 11, minutes: 90, tag: 'عمل'),
          task('مهمة ثانية', 10, tag: 'عمل'),
          task('بدون تصنيف', 9),
          task('تصنيف فارغ', 8, tag: '  '),
          task('قبل بداية اليوم', 3, tag: 'سابق'),
          task('قديمة', 8, date: DateTime(2026, 10, 9, 8), tag: 'قديم'),
          task(
            'مفتوحة',
            8,
            minutes: 900,
            tag: 'مفتوح',
          ).copyWith(clearCompletedAt: true),
          task(
            'محذوفة',
            8,
            minutes: 900,
            tag: 'محذوف',
          ).copyWith(isDeleted: true),
        ],
        tracking: false,
        startMinutes: 240,
        width: 320,
      );
      expect(find.text('الوقت المسجل'), findsNothing);
      expect(find.text('عمل'), findsNWidgets(2));
      expect(find.text('غير مصنف'), findsNWidgets(2));
      expect(find.text('40%'), findsNWidgets(2)); // Weekly: two of five each.
      expect(find.text('50%'), findsNWidgets(2)); // Today: two of four each.
      expect(find.text('20%'), findsOneWidget);
    expect(find.text('المهام: 2'), findsNWidgets(4));
    expect(find.text('المهام: 1'), findsOneWidget);
      expect(find.text('مفتوح'), findsNothing);
      expect(find.text('محذوف'), findsNothing);
      expect(find.text('قديم'), findsNothing);
      expect(find.textContaining('◷'), findsNothing);
      expect(find.text('11:00'), findsNothing);
      expect(tester.takeException(), isNull);
      await controller.setTimeTrackingEnabled(true);
      await tester.pumpAndSettle();
      expect(find.text('الوقت المسجل'), findsOneWidget);
      expect(find.text('مفتوح'), findsNWidgets(2));
      expect(find.text('11:00'), findsOneWidget);
      expect(find.textContaining('◷'), findsOneWidget);
      expect(
        controller.tasks
            .firstWhere((task) => task.id == 'مهمة عمل')
            .totalMinutes,
        90,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'task mode hides time-only history and handles empty distribution',
    (tester) async {
      await mount(tester, [
        task(
          'وقت قديم',
          8,
          minutes: 90,
          date: DateTime(2026, 1, 1),
        ).copyWith(clearCompletedAt: true),
      ], tracking: false);
      expect(find.text('لا توجد مهام مكتملة خلال هذه الفترة'), findsOneWidget);
      expect(find.textContaining('وقت مسجل'), findsNothing);
      expect(
        tester
            .widget<ListView>(find.byType(ListView))
            .childrenDelegate
            .estimatedChildCount,
        8,
      );
      await tester.scrollUntilVisible(find.text('الأحد، 11 أكتوبر'), 250);
      expect(find.text('عرض أيام سابقة'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('latest two tasks, reveal, collapse and closed previous days', (
    tester,
  ) async {
    await mount(tester, [
      task('الأولى', 11, minutes: 90, tag: 'البرمجة'),
      task('الثانية', 10, minutes: 30, tag: 'شخصي'),
      task('الثالثة', 9),
      task('أمس', 8, date: DateTime(2026, 10, 16, 8)),
    ]);
    expect(find.text('75%'), findsNWidgets(2));
    expect(find.text('25%'), findsNWidgets(2));
    expect(find.text('الأولى'), findsOneWidget);
    expect(find.text('الثانية'), findsOneWidget);
    expect(find.text('الثالثة'), findsNothing);
    expect(find.text('أمس'), findsNothing);
    await tester.ensureVisible(find.text('عرض 1 مهام أخرى'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('عرض 1 مهام أخرى'));
    await tester.pumpAndSettle();
    expect(find.text('الثالثة'), findsOneWidget);
    await tester.ensureVisible(find.text('طي لائحة المهام'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('طي لائحة المهام'));
    await tester.pumpAndSettle();
    expect(find.text('الثالثة'), findsNothing);
    await tester.ensureVisible(find.text('السبت، 17 أكتوبر'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('السبت، 17 أكتوبر'));
    await tester.pumpAndSettle();
    expect(find.text('الأولى'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty history keeps seven days without a load button', (
    tester,
  ) async {
    await mount(tester, [], width: 320);
    expect(find.text('لا يوجد وقت مسجل خلال هذه الفترة'), findsOneWidget);
    expect(find.text('السبت، 17 أكتوبر'), findsOneWidget);
    expect(
      tester
          .widget<ListView>(find.byType(ListView))
          .childrenDelegate
          .estimatedChildCount,
      8,
    );
    await tester.scrollUntilVisible(find.text('الأحد، 11 أكتوبر'), 250);
    expect(find.text('عرض أيام سابقة'), findsNothing);
    expect(find.text('السبت، 10 أكتوبر'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'history loads seven days then stops exactly at oldest activity',
    (tester) async {
      final controller = await mount(tester, [
        task('أقدم إنجاز', 10, date: DateTime(2026, 9, 30, 10)),
      ]);
      int itemCount() => tester
          .widget<ListView>(find.byType(ListView))
          .childrenDelegate
          .estimatedChildCount!;
      expect(itemCount(), 9); // Header, seven days, load button.
      await tester.scrollUntilVisible(find.text('عرض أيام سابقة'), 250);
      await tester.tap(find.text('عرض أيام سابقة'));
      await tester.pumpAndSettle();
      expect(itemCount(), 16); // Header, fourteen days, load button.
      await tester.scrollUntilVisible(find.text('عرض أيام سابقة'), 250);
      expect(find.text('الأحد، 4 أكتوبر'), findsOneWidget);
      await tester.tap(find.text('عرض أيام سابقة'));
      await tester.pumpAndSettle();
      expect(
        itemCount(),
        19,
      ); // Header and eighteen days; final batch has four.
      await tester.scrollUntilVisible(find.text('الأربعاء، 30 سبتمبر'), 250);
      expect(find.text('عرض أيام سابقة'), findsNothing);
      expect(find.text('الثلاثاء، 29 سبتمبر'), findsNothing);

      await controller.reset();
      await tester.pumpAndSettle();
      expect(itemCount(), 8);
      expect(find.text('عرض أيام سابقة'), findsNothing);
      expect(find.text('الأربعاء، 30 سبتمبر'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('completion without time and changed logical boundary refresh', (
    tester,
  ) async {
    final controller = await mount(tester, [task('قبل الفجر', 3)]);
    expect(find.text('قبل الفجر'), findsOneWidget);
    expect(find.text('لا يوجد وقت مسجل خلال هذه الفترة'), findsNWidgets(2));
    await controller.setLogicalDayStart(240);
    await tester.pumpAndSettle();
    expect(find.text('قبل الفجر'), findsNothing);
    await tester.ensureVisible(find.text('الجمعة، 16 أكتوبر'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('الجمعة، 16 أكتوبر'));
    await tester.pumpAndSettle();
    expect(find.text('قبل الفجر'), findsOneWidget);
    expect(find.text('03:00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact phone preview with long category names and large text', (
    tester,
  ) async {
    await (FontLoader('Plex Arabic')
          ..addFont(
            rootBundle.load('assets/fonts/IBMPlexSansArabic-Regular.ttf'),
          )
          ..addFont(rootBundle.load('assets/fonts/IBMPlexSansArabic-Bold.ttf')))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    final controller = await mount(tester, [
      task('إنهاء واجهة الإحصاءات', 11, minutes: 120, tag: 'البرمجة'),
      task(
        'تحضير المحتوى الجديد',
        10,
        minutes: 60,
        tag: 'تصنيف ذو اسم طويل لاختبار التفاف النص',
      ),
      task('المراجعة اليومية', 9, minutes: 30, tag: 'شخصي'),
    ], width: 320);
    expect(tester.takeException(), isNull);
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('preview')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '/tmp/najeez-statistics.png',
      ).writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    await controller.setTimeTrackingEnabled(false);
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '/tmp/najeez-statistics-tasks.png',
      ).writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
