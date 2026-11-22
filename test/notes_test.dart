import 'dart:async';

import 'package:najeez/main.dart';
import 'package:najeez/core/arabic_dates.dart';
import 'package:najeez/core/design.dart';
import 'package:najeez/features/tasks/data/sqlite_task_repository.dart';
import 'package:najeez/features/tasks/domain/task.dart';
import 'package:najeez/features/tasks/domain/task_controller.dart';
import 'package:najeez/features/tasks/presentation/notes_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'widget_test.dart' show MemoryRepository;

class _DelayedNoteRepository extends MemoryRepository {
  Completer<void>? gate;
  bool fail = false;

  @override
  Future<void> upsertTask(Task task) async {
    if (fail) throw StateError('Save failed');
    if (gate != null) await gate!.future;
    await super.upsertTask(task);
  }
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test(
    'notes persist, survive backup, and stay linked after task changes',
    () async {
      final repository = await SqliteTaskRepository.open(
        databasePath: inMemoryDatabasePath,
      );
      addTearDown(repository.close);
      var now = DateTime(2026, 11, 15, 10);
      final controller = TaskController(repository, clock: () => now);
      addTearDown(controller.dispose);
      await controller.load();
      await controller.create('مراجعة المشروع');
      final task = controller.tasks.single;
      await controller.addNote(
        task,
        '  تفاصيل أولى\nسطر ثان  ',
        title: 'عنوان اختياري',
      );
      now = now.add(const Duration(minutes: 1));
      await controller.addNote(task, 'ملاحظة أخرى');
      await controller.addNote(task, '   ');
      await controller.complete(task);
      await controller.load();
      expect(controller.searchNotes().length, 2);
      expect(controller.searchNotes().first.note.text, 'ملاحظة أخرى');
      expect(
        controller.searchNotes('تفاصيل').single.note.text,
        'تفاصيل أولى\nسطر ثان',
      );
      expect(
        controller.searchNotes('عنوان اختياري').single.note.title,
        'عنوان اختياري',
      );
      expect(controller.searchNotes('لا يوجد'), isEmpty);
      expect(controller.searchNotes().first.task.id, task.id);
      final backup = await repository.exportBackup();
      await controller.reset();
      expect(controller.searchNotes(), isEmpty);
      await repository.importBackup(backup, now);
      await controller.load();
      expect(controller.searchNotes().length, 2);
      expect(controller.searchNotes('عنوان اختياري'), hasLength(1));
      await controller.delete(controller.tasks.single);
      expect(controller.searchNotes().first.task.title, 'مراجعة المشروع');
    },
  );

  testWidgets('add from task menu then open all notes and search', (
    tester,
  ) async {
    final controller = TaskController(MemoryRepository());
    addTearDown(controller.dispose);
    await controller.load();
    await controller.create('مهمة الملاحظات');
    await tester.pumpWidget(
      BaqiApp(controller: controller, splashDuration: Duration.zero),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('مهمة الملاحظات'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byIcon(Icons.gps_fixed),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byIcon(Icons.notes_outlined),
      ),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(find.text('إضافة ملاحظة')).dy,
      lessThan(tester.getTopLeft(find.text('تعديل المهمة')).dy),
    );
    await tester.tap(find.text('إضافة ملاحظة'));
    await tester.pumpAndSettle();
    expect(find.byType(NoteComposerScreen), findsOneWidget);
    expect(find.text('مهمة مرتبطة'), findsNothing);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    await tester.tap(find.text('مهمة الملاحظات'));
    await tester.pumpAndSettle();
    expect(find.text('تعديل المهمة'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(NoteComposerScreen), findsOneWidget);
    final save = find.widgetWithText(TextButton, 'حفظ');
    expect(save, findsOneWidget);
    expect(
      tester.widget<TextButton>(save).style!.textStyle!.resolve({})!.fontFamily,
      'Plex Arabic',
    );
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('إغلاق دون حفظ'), findsOneWidget);
    expect(find.text('حذف'), findsNothing);
    await tester.tapAt(const Offset(10, 100));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'نص بلا عنوان\nمع سطر جديد');
    await tester.pump();
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();
    expect(
      controller.searchNotes().single.note.text,
      'نص بلا عنوان\nمع سطر جديد',
    );
    await tester.scrollUntilVisible(
      find.byType(RecentNotesSection),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(
      find.widgetWithText(TextButton, 'عرض الكل').last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('آخر الملاحظات'));
    await tester.pumpAndSettle();
    expect(find.byType(NotesScreen), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'بلا عنوان');
    await tester.pumpAndSettle();
    expect(find.text('نص بلا عنوان\nمع سطر جديد'), findsOneWidget);
    expect(find.text('مهمة الملاحظات'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'مهمة الملاحظات');
    await tester.pumpAndSettle();
    expect(find.text('نص بلا عنوان\nمع سطر جديد'), findsOneWidget);
    await tester.tap(find.text('نص بلا عنوان\nمع سطر جديد'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('مهمة الملاحظات'));
    await tester.pumpAndSettle();
    expect(find.text('تعديل المهمة'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('إغلاق'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'غير موجود');
    await tester.pumpAndSettle();
    expect(find.text('لا توجد ملاحظات مطابقة'), findsOneWidget);
  });
  test(
    'editing and deleting notes persist without changing their task or date',
    () async {
      final repository = await SqliteTaskRepository.open(
        databasePath: inMemoryDatabasePath,
      );
      addTearDown(repository.close);
      final controller = TaskController(repository);
      addTearDown(controller.dispose);
      await controller.load();
      await controller.create('مهمة مرتبطة');
      final task = controller.tasks.single;
      await controller.addNote(task, 'نص قديم');
      final original = controller.searchNotes().single.note;
      await controller.addNote(task, 'ملاحظة ثانية');
      await controller.updateNote(task, original, '  نص معدل\nسطر جديد  ');
      await controller.load();
      final edited = controller.searchNotes('نص معدل').single;
      expect(edited.note.id, original.id);
      expect(edited.note.createdAt, original.createdAt);
      expect(edited.task.id, task.id);
      expect(edited.note.text, 'نص معدل\nسطر جديد');
      expect(controller.searchNotes('نص قديم'), isEmpty);
      await controller.updateNote(task, edited.note, '   ');
      expect(controller.searchNotes('نص معدل'), hasLength(1));
      await controller.deleteNote(task, edited.note);
      await controller.load();
      expect(controller.searchNotes().single.note.text, 'ملاحظة ثانية');
      expect(controller.tasks.single.title, 'مهمة مرتبطة');
    },
  );

  testWidgets(
    'notes scroll through the bottom fade with a fixed header and search',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 480);
      tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
      tester.view.viewPadding = const FakeViewPadding(top: 47, bottom: 34);
      addTearDown(tester.view.reset);
      final controller = TaskController(MemoryRepository());
      addTearDown(controller.dispose);
      await controller.load();
      await controller.create('مهمة');
      for (var i = 0; i < 20; i++) {
        await controller.addNote(controller.tasks.single, 'ملاحظة $i');
      }
      await tester.pumpWidget(
        MaterialApp(home: NotesScreen(controller: controller)),
      );
      await tester.pumpAndSettle();

      final scroll = find.byType(SingleChildScrollView);
      final title = find.text('جميع الملاحظات');
      final search = find.byType(TextField);
      final titleRect = tester.getRect(title);
      final searchRect = tester.getRect(search);
      expect(titleRect.top, greaterThan(47));
      expect(tester.getRect(scroll).top, greaterThan(searchRect.bottom));
      expect(tester.getRect(scroll).bottom, 480);

      final bottomFade = find.byWidgetPredicate((widget) {
        if (widget is! DecoratedBox || widget.decoration is! BoxDecoration) {
          return false;
        }
        final gradient = (widget.decoration as BoxDecoration).gradient;
        return gradient is LinearGradient &&
            gradient.begin == Alignment.topCenter &&
            gradient.end == Alignment.bottomCenter &&
            gradient.colors.first.a == 0 &&
            gradient.colors.last.a == 1;
      });
      expect(tester.getRect(bottomFade).bottom, 480);
      final position = Scrollable.of(
        tester.element(find.byType(NoteCard).first),
      ).position;
      await tester.dragFrom(
        tester.getCenter(bottomFade),
        const Offset(0, -100),
      );
      await tester.pumpAndSettle();
      expect(position.pixels, greaterThan(0));
      expect(tester.getRect(title), titleRect);
      expect(tester.getRect(search), searchRect);

      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
      final lastCard = find
          .byType(NoteCard)
          .hitTestable()
          .evaluate()
          .map(
            (element) => tester.getRect(find.byWidget(element.widget)).bottom,
          )
          .reduce((a, b) => a > b ? a : b);
      expect(lastCard, closeTo(480 - 34 - 28 - 10, .01));
    },
  );

  testWidgets(
    'all notes keep cards, with editing and confirmed deletion inside the note',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      final controller = TaskController(MemoryRepository());
      addTearDown(controller.dispose);
      await controller.load();
      await controller.create('المهمة المرتبطة');
      final task = controller.tasks.single;
      await controller.addNote(task, 'ملاحظة قصيرة');
      await controller.addNote(task, List.filled(8, 'تفاصيل طويلة').join('\n'));
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: NotesScreen(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final cards = find.byType(NoteCard);
      expect(cards, findsNWidgets(2));
      final first = tester.getRect(cards.at(0));
      final second = tester.getRect(cards.at(1));
      expect(first.top, second.top);
      expect(first.left, isNot(second.left));
      expect(first.height, isNot(second.height));
      expect(first.width, lessThan(190));
      expect(find.byType(PopupMenuButton<String>), findsNothing);
      final date = arabicDate(controller.searchNotes().first.note.createdAt);
      expect(find.text(date), findsNothing);

      await tester.tap(find.text('ملاحظة قصيرة'));
      await tester.pumpAndSettle();
      expect(find.text('تعديل الملاحظة'), findsNothing);
      expect(find.text(date), findsOneWidget);
      final editor = find.byType(TextField).last;
      expect(
        tester.getRect(find.text('المهمة المرتبطة').last).top,
        greaterThan(tester.getRect(editor).bottom),
      );
      final closeButton = find.widgetWithText(TextButton, 'إغلاق');
      final menu = find.byType(PopupMenuButton<String>);
      expect(find.widgetWithText(TextButton, 'حفظ'), findsNothing);
      expect(
        tester
            .widget<TextButton>(closeButton)
            .style!
            .foregroundColor!
            .resolve({}),
        AppColors.text,
      );
      expect(find.byTooltip('إغلاق'), findsNothing);
      expect(find.byIcon(Icons.close), findsNothing);
      expect(
        tester.getRect(find.byTooltip('رجوع')).top,
        greaterThanOrEqualTo(16),
      );
      expect(tester.getRect(editor).top, 72);
      final input = tester.widget<TextField>(editor).decoration!;
      expect(input.filled, isFalse);
      expect(input.border, InputBorder.none);
      expect(tester.getRect(menu).left, 18);
      final linkedTask = find
          .ancestor(
            of: find.text('المهمة المرتبطة').last,
            matching: find.byType(Material),
          )
          .first;
      expect(
        tester.getRect(linkedTask).left,
        greaterThan(tester.getRect(closeButton).left),
      );
      expect(
        tester.widget<Text>(find.text('المهمة المرتبطة').last).style!.color,
        AppColors.muted,
      );
      expect(tester.getRect(menu).width, 36);
      expect(tester.getRect(closeButton).left, tester.getRect(menu).right);
      expect(tester.getRect(closeButton).width, inInclusiveRange(48, 100));
      expect(
        tester.getRect(find.text('المهمة المرتبطة').last).bottom,
        lessThan(tester.getRect(find.text(date)).top),
      );
      expect(
        tester.getRect(find.text('المهمة المرتبطة').last).top -
            tester.getRect(editor).bottom,
        greaterThanOrEqualTo(24),
      );
      expect(
        tester.getRect(closeButton).center.dy,
        tester.getRect(find.text(date)).center.dy,
      );
      expect(
        tester
            .widget<TextButton>(closeButton)
            .style!
            .textStyle!
            .resolve({})!
            .fontSize,
        14,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField).last).controller!.text,
        'ملاحظة قصيرة',
      );
      await tester.enterText(
        find.byType(TextField).last,
        'الملاحظة بعد التعديل',
      );
      await tester.pump();
      await tester.tap(find.text('إغلاق'));
      await tester.pumpAndSettle();
      expect(find.text('الملاحظة بعد التعديل'), findsOneWidget);
      expect(controller.searchNotes('قصيرة'), isEmpty);

      await tester.tap(find.text('الملاحظة بعد التعديل'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'تعديل لن يُحفظ');
      await tester.pump();
      Future<void> requestDiscard() async {
        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();
        await tester.tap(find.text('إغلاق دون حفظ'));
        await tester.pumpAndSettle();
        expect(find.text('إغلاق دون حفظ؟'), findsOneWidget);
      }

      await requestDiscard();
      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField).last).controller!.text,
        'تعديل لن يُحفظ',
      );
      await requestDiscard();
      await tester.tap(find.widgetWithText(FilledButton, 'إغلاق دون حفظ'));
      await tester.pumpAndSettle();
      expect(controller.searchNotes('تعديل لن'), isEmpty);
      expect(find.text('الملاحظة بعد التعديل'), findsOneWidget);
      await tester.tap(find.text('الملاحظة بعد التعديل'));
      await tester.pumpAndSettle();
      Future<void> requestDelete() async {
        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();
        await tester.tap(find.text('حذف'));
        await tester.pumpAndSettle();
        expect(find.text('حذف الملاحظة؟'), findsOneWidget);
        expect(controller.searchNotes(), hasLength(2));
      }

      await requestDelete();
      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();
      expect(controller.searchNotes(), hasLength(2));
      await requestDelete();
      await tester.tap(find.widgetWithText(FilledButton, 'حذف'));
      await tester.pumpAndSettle();
      expect(controller.searchNotes(), hasLength(1));
      expect(find.text('الملاحظة بعد التعديل'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('recent notes show compact rows without card actions or dates', (
    tester,
  ) async {
    final controller = TaskController(MemoryRepository());
    addTearDown(controller.dispose);
    await controller.load();
    await controller.create('مهمة المعاينة');
    final task = controller.tasks.single;
    for (var i = 0; i < 4; i++) {
      await controller.addNote(
        task,
        '$i بداية الملاحظة\n${List.filled(30, 'تفاصيل').join(' ')}',
      );
    }
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Directionality(
            textDirection: TextDirection.rtl,
            child: RecentNotesSection(controller: controller),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final rows = find.byType(NotePreviewRow);
    expect(rows, findsNWidgets(3));
    expect(find.byType(NoteCard), findsNothing);
    expect(find.byType(PopupMenuButton<String>), findsNothing);
    expect(
      find.text(arabicDate(controller.searchNotes().first.note.createdAt)),
      findsNothing,
    );
    final first = tester.getRect(rows.at(0));
    final second = tester.getRect(rows.at(1));
    expect(first.left, second.left);
    expect(first.width, second.width);
    expect(second.top, greaterThanOrEqualTo(first.bottom));
    for (final text in tester.widgetList<Text>(
      find.descendant(of: rows, matching: find.byType(Text)),
    )) {
      expect(text.maxLines, lessThanOrEqualTo(2));
      expect(text.overflow, TextOverflow.ellipsis);
    }
    await tester.tap(rows.first);
    await tester.pumpAndSettle();
    expect(find.byType(NoteComposerScreen), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'إغلاق'), findsOneWidget);
    expect(find.byIcon(Icons.more_vert), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'system back waits for persistence and saves edited and new notes',
    (tester) async {
      final repository = _DelayedNoteRepository();
      final controller = TaskController(repository);
      addTearDown(controller.dispose);
      await controller.load();
      await controller.create('مهمة الرجوع');
      final task = controller.tasks.single;
      await controller.addNote(task, 'النص الأصلي');
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(navigatorKey: navigator, home: const Scaffold()),
      );
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => NoteComposerScreen(
            controller: controller,
            task: task,
            note: controller.searchNotes().single.note,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'محفوظ بالرجوع');
      repository.gate = Completer<void>();
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(NoteComposerScreen), findsOneWidget);
      repository.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(NoteComposerScreen), findsNothing);
      expect(repository.tasks.single.notes.single.text, 'محفوظ بالرجوع');
      repository.gate = null;
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) =>
              NoteComposerScreen(controller: controller, task: task),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'ملاحظة جديدة بالرجوع');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(NoteComposerScreen), findsNothing);
      expect(repository.tasks.single.notes.length, 2);
    },
  );

  testWidgets('failed back save keeps the note open for retry', (tester) async {
    final repository = _DelayedNoteRepository();
    final controller = TaskController(repository);
    addTearDown(controller.dispose);
    await controller.load();
    await controller.create('مهمة الحفظ');
    final task = controller.tasks.single;
    await controller.addNote(task, 'نص محفوظ');
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(navigatorKey: navigator, home: const Scaffold()),
    );
    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => NoteComposerScreen(
          controller: controller,
          task: task,
          note: controller.searchNotes().single.note,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'تعديل جديد');
    repository.fail = true;
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(NoteComposerScreen), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'تعديل جديد',
    );
    expect(repository.tasks.single.notes.single.text, 'نص محفوظ');
    repository.fail = false;
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(NoteComposerScreen), findsNothing);
    expect(repository.tasks.single.notes.single.text, 'تعديل جديد');
  });
  for (final direction in [TextDirection.rtl, TextDirection.ltr]) {
    testWidgets('iPhone edge swipe saves before closing in $direction', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      final repository = _DelayedNoteRepository();
      final controller = TaskController(repository);
      addTearDown(controller.dispose);
      await controller.load();
      await controller.create('مهمة الآيفون');
      final task = controller.tasks.single;
      await controller.addNote(task, 'نص محفوظ');
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          theme: ThemeData(platform: TargetPlatform.iOS),
          builder: (_, child) =>
              Directionality(textDirection: direction, child: child!),
          home: const Scaffold(),
        ),
      );
      void open() => navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => NoteComposerScreen(
            controller: controller,
            task: task,
            note: controller.searchNotes().single.note,
          ),
        ),
      );
      open();
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'محفوظ بالسحب');
      final edge = Offset(direction == TextDirection.rtl ? 389 : 1, 200);
      final sign = direction == TextDirection.rtl ? -1.0 : 1.0;
      await tester.timedDragFrom(
        edge,
        Offset(sign * 20, 0),
        const Duration(milliseconds: 500),
      );
      await tester.pumpAndSettle();
      expect(find.byType(NoteComposerScreen), findsOneWidget);
      expect(repository.tasks.single.notes.single.text, 'نص محفوظ');
      repository.gate = Completer<void>();
      await tester.timedDragFrom(
        edge,
        Offset(sign * 180, 0),
        const Duration(milliseconds: 400),
      );
      await tester.pump();
      expect(find.byType(NoteComposerScreen), findsOneWidget);
      expect(repository.tasks.single.notes.single.text, 'نص محفوظ');
      repository.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(NoteComposerScreen), findsNothing);
      expect(repository.tasks.single.notes.single.text, 'محفوظ بالسحب');
      repository.gate = null;
      open();
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'محفوظ بسهم الرجوع');
      await tester.tap(find.byTooltip('رجوع'));
      await tester.pumpAndSettle();
      expect(find.byType(NoteComposerScreen), findsNothing);
      expect(repository.tasks.single.notes.single.text, 'محفوظ بسهم الرجوع');
    });
  }
  testWidgets(
    'optional bold title can be added from header, searched and removed',
    (tester) async {
      final controller = TaskController(MemoryRepository());
      addTearDown(controller.dispose);
      await controller.load();
      await controller.create('مهمة العنوان');
      final task = controller.tasks.single;
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(navigatorKey: navigator, home: const Scaffold()),
      );
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) =>
              NoteComposerScreen(controller: controller, task: task),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'محتوى الملاحظة');
      await tester.tap(find.byKey(const ValueKey('note-title-area')));
      await tester.pumpAndSettle();
      final title = find.byKey(const ValueKey('note-title'));
      expect(
        tester.widget<TextField>(title).style!.fontWeight,
        FontWeight.w700,
      );
      await tester.enterText(title, 'عنوان جديد');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text('عنوان جديد'), findsOneWidget);
      await tester.tap(find.text('حفظ'));
      await tester.pumpAndSettle();
      expect(
        controller.searchNotes('عنوان جديد').single.note.text,
        'محتوى الملاحظة',
      );
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => NoteComposerScreen(
            controller: controller,
            task: task,
            note: controller.searchNotes().single.note,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('عنوان جديد'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('note-title-area')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('note-title')), '');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(controller.searchNotes().single.note.title, isEmpty);
      expect(controller.searchNotes().single.note.text, 'محتوى الملاحظة');
    },
  );
}
