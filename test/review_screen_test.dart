import 'dart:async';
import 'package:najeez/core/activity_page.dart';
import 'package:najeez/core/design.dart';
import 'package:najeez/core/status_bar_fade.dart';
import 'package:najeez/features/review/review_identity.dart';
import 'package:najeez/features/review/review_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:najeez/features/review/daily_review.dart';
import 'package:najeez/features/statistics/presentation/statistics_screen.dart';
import 'package:najeez/features/tasks/domain/task_controller.dart';
import 'widget_test.dart' show MemoryRepository;

class _Storage extends MemoryRepository {
  SavedDailyReview? saved;
  @override
  Future<void> saveDailyReview(SavedDailyReview review) async => saved = review;
}

class _Controller extends TaskController {
  _Controller(super.repository, {required super.clock});
  // Widget tests use a fake event loop. Snapshot computation is tested with
  // the production isolate and SQLite in daily_review_test.dart.
  @override
  Future<ReviewSnapshot> captureReview() async => ReviewSnapshot.capture(
    tasks: tasks,
    logicalDay: logicalDay,
    firstUse: DateTime(2026, 10, 1),
    now: now,
    timeTrackingEnabled: timeTrackingEnabled,
  );
}

void main() {
  testWidgets(
    'statistics opens the reviewer, generates only on tap and retains dated text on failed refresh',
    (tester) async {
      const channel = MethodChannel('ma.raqmain.najeez/daily_review');
      final messenger = tester.binding.defaultBinaryMessenger;
      var calls = 0;
      var status = 'available';
      final output = Completer<String>();
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.arguments['language'], 'ar');
        if (call.method == 'availability') return status;
        calls++;
        if (calls == 1) return output.future;
        throw PlatformException(code: 'interrupted');
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      var now = DateTime(2026, 10, 1, 10);
      final controller = _Controller(_Storage(), clock: () => now);
      await controller.load();
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: StatisticsScreen(controller: controller, onActions: (_) {}),
        ),
      );
      await tester.tap(find.text('المراجع الذكي'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'تحليل إنتاجيتي'),
            )
            .onPressed,
        isNull,
      );
      expect(find.textContaining('سبعة أيام كاملة'), findsOneWidget);
      now = DateTime(2026, 10, 9, 10);
      await controller.create('كتابة المسودة');
      await tester.pumpAndSettle();
      expect(calls, 0);
      await tester.tap(find.text('تحليل إنتاجيتي'));
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      output.complete('راجعت المسودة هذا الصباح.');
      await tester.pumpAndSettle();
      expect(find.text('مراجعة الجمعة'), findsOneWidget);
      expect(find.text('9 أكتوبر 2026'), findsOneWidget);
      expect(find.textContaining('10:00'), findsOneWidget);
      expect(find.text('تحديث المراجعة'), findsNothing);
      now = DateTime(2026, 10, 10, 8);
      await controller.refreshDay();
      await tester.pumpAndSettle();
      expect(find.text('مراجعة الجمعة'), findsOneWidget);
      expect(find.text('9 أكتوبر 2026'), findsOneWidget);
      expect(find.text('تحديث المراجعة'), findsNothing);
      await controller.complete(controller.tasks.single);
      await tester.pumpAndSettle();
      expect(calls, 1);
      await tester.tap(find.text('تحديث المراجعة'));
      await tester.pumpAndSettle();
      expect(find.textContaining('توقف التحليل'), findsOneWidget);
      expect(find.text('راجعت المسودة هذا الصباح.'), findsOneWidget);
      status = 'language';
      await tester.tap(
        find.byTooltip(
          MaterialLocalizations.of(
            tester.element(find.text('المراجع الذكي')),
          ).backButtonTooltip,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('المراجع الذكي'));
      await tester.pumpAndSettle();
      expect(find.textContaining('لا يدعم لغة واجهة'), findsOneWidget);
      expect(find.text('راجعت المسودة هذا الصباح.'), findsOneWidget);
      expect(calls, 2);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
  for (final brightness in Brightness.values) {
    testWidgets(
      'review keeps the statistics viewport and dark palette on a ${brightness.name} device',
      (tester) async {
        final view = tester.view;
        view.devicePixelRatio = 1;
        view.physicalSize = const Size(390, 844);
        view.padding = const FakeViewPadding(top: 47, bottom: 34);
        addTearDown(view.reset);
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        await (FontLoader('Plex Arabic')
              ..addFont(
                rootBundle.load('assets/fonts/IBMPlexSansArabic-Regular.ttf'),
              )
              ..addFont(
                rootBundle.load('assets/fonts/IBMPlexSansArabic-Bold.ttf'),
              ))
            .load();
        await (FontLoader(
          'MaterialIcons',
        )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
        final date = DateTime(2026, 11, 22, 16, 40);
        final repo = _Storage();
        var clock = date.subtract(const Duration(days: 14));
        final controller = _Controller(repo, clock: () => clock);
        await controller.load();
        await controller.create('إعداد العرض');
        clock = date;
        await controller.complete(controller.tasks.single);
        const channel = MethodChannel('ma.raqmain.najeez/daily_review');
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          (call) async => 'available',
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            null,
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            locale: const Locale('ar'),
            supportedLocales: const [Locale('ar')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            theme: ThemeData(
              brightness: Brightness.dark,
              fontFamily: 'Plex Arabic',
              scaffoldBackgroundColor: AppColors.background,
            ),
            home: StatisticsScreen(controller: controller, onActions: (_) {}),
          ),
        );
        await tester.pumpAndSettle();
        final heading = tester.getRect(find.byType(ActivityPageHeader));
        expect(
          tester.getRect(find.byType(ReviewEntryCard)).top,
          greaterThan(tester.getRect(find.text('آخر 7 أيام')).bottom),
        );
        expect(
          tester.getRect(find.byType(ReviewEntryCard)).bottom,
          lessThan(tester.getRect(find.text('سجل الأيام')).top),
        );
        final cardMaterial = find.descendant(
          of: find.byType(ReviewEntryCard),
          matching: find.byType(Material),
        );
        expect(tester.widget<Material>(cardMaterial).color, AppColors.surface);
        await tester.tap(find.byType(ReviewEntryCard));
        await tester.pumpAndSettle();
        expect(tester.getRect(find.byType(ActivityPageHeader)), heading);
        expect(
          find.descendant(
            of: find.byType(ReviewScreen),
            matching: find.byType(StatusBarFade),
          ),
          findsOneWidget,
        );
        expect(
          tester.getRect(find.byType(SingleChildScrollView)),
          const Rect.fromLTWH(0, 0, 390, 844),
        );
        expect(
          Theme.of(tester.element(find.byType(ActivityPageHeader))).brightness,
          Brightness.dark,
        );
        expect(find.text('تحليل خاص على جهازك'), findsOneWidget);
        await controller.generateReview(
          (_) async =>
              'تركّز عملك اليوم على إنهاء مسودة العرض. خصّصت لها جلستين صباحًا، ثم عدت إليها بعد الظهر لإتمام التعديلات.\n\nبقيت مراجعة الميزانية ضمن مهام اليوم. لم يُسجّل لها وقت عمل حتى لحظة إعداد هذه المراجعة.',
        );
        await tester.pumpAndSettle();
        expect(find.text('22 نوفمبر 2026'), findsOneWidget);
        view.physicalSize = const Size(320, 560);
        tester.platformDispatcher.textScaleFactorTestValue = 1.6;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpAndSettle();
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -3000),
        );
        await tester.pumpAndSettle();
        expect(find.text('تحليل خاص على جهازك').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  }
}
