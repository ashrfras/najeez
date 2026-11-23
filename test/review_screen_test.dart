import 'dart:async';
import 'package:najeez/core/activity_page.dart';
import 'package:najeez/core/design.dart';
import 'package:najeez/core/status_bar_fade.dart';
import 'package:najeez/features/review/review_identity.dart';
import 'package:najeez/features/review/review_screen.dart';
import 'package:najeez/features/review/review_model.dart';
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
  Future<SavedDailyReview?> getDailyReview() async => saved;
  @override
  Future<void> clearDailyReview() async => saved = null;
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

class _TestModel implements ReviewModel {
  int calls = 0;
  bool ready = true;
  final output = Completer<String>();

  @override
  Future<bool> isAvailable(String language) async {
    expect(language, 'ar');
    return ready;
  }

  @override
  Future<String> generate(ReviewSnapshot snapshot, String language) async {
    expect(language, 'ar');
    calls++;
    if (calls == 1) return output.future;
    throw StateError('interrupted');
  }
}

void main() {
  testWidgets(
    'a configured local model runs only on tap and a failed refresh preserves the dated review',
    (tester) async {
      final model = _TestModel();
      var now = DateTime(2026, 10, 1, 10);
      final controller = _Controller(_Storage(), clock: () => now);
      await controller.load();
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: ReviewScreen(controller: controller, model: model),
        ),
      );
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
      expect(model.calls, 0);
      await tester.tap(find.text('تحليل إنتاجيتي'));
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      model.output.complete('راجعت المسودة هذا الصباح.');
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
      expect(model.calls, 1);
      model.ready = false;
      await tester.tap(find.text('تحديث المراجعة'));
      await tester.pumpAndSettle();
      expect(find.textContaining('تعذّر إكمال المراجعة'), findsOneWidget);
      expect(find.text('راجعت المسودة هذا الصباح.'), findsOneWidget);
      expect(find.text('النموذج المحلي غير متاح حاليًا.'), findsOneWidget);
      expect(find.text('راجعت المسودة هذا الصباح.'), findsOneWidget);
      expect(model.calls, 2);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
  for (final brightness in Brightness.values) {
    testWidgets(
      'review keeps the statistics viewport and dark palette on a ${brightness.name} device',
      (tester) async {
        const channel = MethodChannel('ma.raqmain.najeez/qwen');
        const events = EventChannel('ma.raqmain.najeez/qwen/state');
        final messenger = tester.binding.defaultBinaryMessenger;
        final state = <String, Object>{
          'phase': 'missing',
          'total': 1282439584,
          'installed': 0,
          'received': 0,
          'error': '',
        };
        late MockStreamHandlerEventSink changes;
        final commands = <String>[];
        messenger.setMockStreamHandler(
          events,
          MockStreamHandler.inline(
            onListen: (_, sink) {
              changes = sink;
            },
          ),
        );
        messenger.setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'status') return state;
          commands.add(call.method);
          return null;
        });
        addTearDown(() {
          messenger.setMockMethodCallHandler(channel, null);
          messenger.setMockStreamHandler(events, null);
        });
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
        expect(commands, isEmpty);
        await tester.ensureVisible(find.text('تنزيل النموذج'));
        await tester.tap(find.text('تنزيل النموذج'));
        await tester.pump();
        expect(commands, ['download']);
        changes.success({
          ...state,
          'phase': 'downloading',
          'received': 641219792,
        });
        await tester.pumpAndSettle();
        expect(find.textContaining('50٪'), findsOneWidget);
        await tester.ensureVisible(find.text('إلغاء التنزيل'));
        await tester.tap(find.text('إلغاء التنزيل'));
        await tester.pump();
        expect(commands.last, 'cancelDownload');
        changes.success({...state, 'error': 'network'});
        await tester.pumpAndSettle();
        expect(find.text('إعادة تنزيل النموذج'), findsOneWidget);
        changes.success({...state, 'phase': 'verifying'});
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));
        expect(find.textContaining('سلامة الملف'), findsOneWidget);
        changes.success({...state, 'phase': 'ready', 'installed': 1282439584});
        await tester.pumpAndSettle();
        expect(find.text('مثبّت وجاهز للاستخدام'), findsOneWidget);
        expect(find.textContaining('غيغابايت'), findsNothing);
        await tester.ensureVisible(find.text('حذف النموذج'));
        await tester.tap(find.text('حذف النموذج'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('حذف النموذج'),
          ),
        );
        await tester.pumpAndSettle();
        expect(commands.last, 'remove');
        changes.success(state);
        await tester.pumpAndSettle();
        repo.saved = SavedDailyReview(
          day: date,
          asOf: date,
          generatedAt: date,
          signature: 'previous',
          text: [
            'تركّز عملك اليوم على إنهاء مسودة العرض.',
            for (var i = 0; i < 20; i++) 'فقرة رقم $i من نص المراجعة المطوّلة.',
          ].join('\n\n'),
        );
        await controller.load();
        await tester.pumpAndSettle();
        expect(find.text('22 نوفمبر 2026'), findsOneWidget);
        expect(
          find.text('تركّز عملك اليوم على إنهاء مسودة العرض.'),
          findsOneWidget,
        );
        expect(find.text('تحديث المراجعة'), findsNothing);
        final inner = find.byKey(const ValueKey('review-text-scroll'));
        await tester.ensureVisible(inner);
        final scroll = tester.widget<SingleChildScrollView>(inner).controller!;
        expect(scroll.position.maxScrollExtent, greaterThan(0));
        await tester.drag(inner, const Offset(0, -180));
        await tester.pumpAndSettle();
        expect(scroll.offset, greaterThan(0));
        expect(
          tester.getTopLeft(find.text('النموذج المحلي · Qwen3 1.7B')).dy,
          greaterThan(tester.getBottomLeft(inner).dy),
        );
        view.physicalSize = const Size(320, 560);
        tester.platformDispatcher.textScaleFactorTestValue = 1.6;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpAndSettle();
        // Drag in the page gutter, outside the article's independent scroll area.
        await tester.dragFrom(const Offset(8, 430), const Offset(0, -1800));
        await tester.pumpAndSettle();
        expect(find.text('خصوصية المراجعة').hitTestable(), findsOneWidget);
        changes.success({...state, 'phase': 'ready', 'installed': 1282439584});
        await tester.pumpAndSettle();
        final commandsBeforeReset = List.of(commands);
        await tester.ensureVisible(find.text('تصفير المراجعة للاختبار'));
        await tester.tap(find.text('تصفير المراجعة للاختبار'));
        await tester.pumpAndSettle();
        expect(repo.saved, isNull);
        expect(find.text('مراجعة يومك'), findsOneWidget);
        expect(commands, commandsBeforeReset);
        expect(find.text('مثبّت وجاهز للاستخدام'), findsOneWidget);
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'تحليل إنتاجيتي'),
              )
              .onPressed,
          isNotNull,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  }
}
