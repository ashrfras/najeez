import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:najeez/features/review/daily_review.dart';
import 'package:najeez/features/review/review_evidence.dart';
import 'package:najeez/features/review/review_language.dart';
import 'package:najeez/features/tasks/data/sqlite_task_repository.dart';
import 'package:najeez/features/tasks/domain/task.dart';
import 'package:najeez/features/tasks/domain/task_controller.dart';
import 'package:najeez/features/tasks/domain/task_dates.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  final now = DateTime(2026, 11, 30, 2);
  final firstUse = DateTime(2026, 10);
  Task task(
    String id,
    DateTime created, {
    String? tag,
    DateTime? done,
    List<TimeEntry> entries = const [],
    List<TaskNote> notes = const [],
  }) => Task(
    id: id,
    title: id,
    tag: tag,
    bucket: TaskBucket.today,
    createdAt: created,
    updatedAt: created,
    completedAt: done,
    timeEntries: entries,
    notes: notes,
  );
  ReviewSnapshot capture(
    List<Task> tasks, {
    DateTime? first,
    DateTime? at,
    int boundary = 240,
  }) => ReviewSnapshot.capture(
    tasks: tasks,
    logicalDay: LogicalDay(boundary),
    firstUse: first ?? firstUse,
    now: at ?? now,
    timeTrackingEnabled: true,
  );
  SavedDailyReview saved(ReviewSnapshot s) => SavedDailyReview(
    day: s.day,
    asOf: s.asOf,
    generatedAt: s.asOf,
    signature: s.signature,
    text: 'مراجعة محفوظة',
  );

  test(
    'Qwen receives verified focus outcomes, same-time comparisons and limited morning evidence',
    () {
      final prior = now.subtract(const Duration(days: 4));
      final sameTitle = task(
        'مفتوحة',
        now,
        entries: [TimeEntry(id: 'focus:open', minutes: 10, createdAt: now)],
      ).copyWith(title: 'التدقيق');
      final completed = task(
        'منتهية',
        prior,
        done: now,
        entries: [
          TimeEntry(id: 'focus:done', minutes: 60, createdAt: now),
          TimeEntry(id: 'focus:prior', minutes: 27, createdAt: prior),
        ],
      ).copyWith(title: 'التدقيق');
      final evidence = jsonDecode(
        qwenEvidence(capture([sameTitle, completed])),
      );
      expect(evidence['حصيلة اليوم'], [1, 1, 2, 70, 0, 0]);
      expect(evidence['السجل السابق'].length, 27);
      expect(evidence['المهام المنجزة اليوم'].single['task'], 'التدقيق');
      final article = evidence['sections'].toString();
      expect(article, contains('قبل أربعة أيام'));
      expect(article, contains('معظم هذا الوقت إلى مهام أغلقتها'));
      expect(
        article,
        contains('عشر دقائق لمهمة «التدقيق» التي ما زالت مفتوحة'),
      );
      expect(article, isNot(contains('عادةً')));
      final scarce = jsonDecode(qwenEvidence(capture([task('التخطيط', now)])));
      expect(scarce['sections'].length, 1);
      expect(
        scarce['sections'].single['readings'],
        contains('السجل محدود للحكم على سير التنفيذ حتى الآن.'),
      );
    },
  );

  test(
    'completion names survive a day crowded with more recent focus sessions and notes',
    () {
      final earlier = now.subtract(const Duration(hours: 2));
      final records = [
        for (var i = 0; i < 10; i++) task('مهمة $i', firstUse, done: earlier),
        task(
          'مغلقة سابقًا',
          firstUse,
          done: earlier.subtract(const Duration(days: 2)),
        ),
        task('محذوفة', firstUse, done: earlier).copyWith(isDeleted: true),
        task(
          'عمل جارٍ',
          firstUse,
          notes: [
            for (var i = 0; i < 14; i++)
              TaskNote(id: 'n$i', text: 'تحديث', createdAt: now),
          ],
        ),
      ];
      final data = jsonDecode(qwenEvidence(capture(records)));
      expect(data['حصيلة اليوم'][1], 10);
      expect(
        (data['المهام المنجزة اليوم'] as List).map((r) => r['task']),
        unorderedEquals([for (var i = 0; i < 10; i++) 'مهمة $i']),
      );
      expect(data['أمثلة من إنجازات سابقة'].single['task'], 'مغلقة سابقًا');
    },
  );

  test(
    'review durations and dates are relative to the captured logical day',
    () {
      expect(reviewDuration(74), 'حوالي ساعة وربع');
      expect(reviewDuration(75), 'ساعة وربع');
      expect(reviewDuration(90), 'ساعة ونصف');
      expect(reviewDuration(121), 'حوالي ساعتين');
      expect(reviewDuration(15), 'ربع ساعة');
      expect(reviewDuration(0.5), 'أقل من دقيقة');
      final day = DateTime(2026, 1, 3);
      expect(reviewRelativeDay(reviewDaysAgo('2026-01-02', day)), 'أمس');
      expect(
        reviewRelativeDay(reviewDaysAgo('2025-12-30', day)),
        'قبل أربعة أيام',
      );
      expect(
        reviewRelativeDay(reviewDaysAgo('2025-12-26', day)),
        'قبل حوالي أسبوع',
      );
      final prior = now.subtract(const Duration(days: 8));
      final evidence = jsonDecode(
        qwenEvidence(
          capture([
            task(
              'المسودة',
              prior,
              tag: 'التوثيق',
              done: now,
              entries: [
                TimeEntry(id: 'focus:prior', minutes: 20, createdAt: prior),
                TimeEntry(id: 'focus:today', minutes: 74, createdAt: now),
              ],
            ),
          ]),
        ),
      );
      expect(evidence['حصيلة اليوم'][3], 74);
      final prose = evidence['sections'].toString();
      expect(prose, contains('حوالي ساعة وربع'));
      expect(prose, contains('قبل حوالي أسبوع'));
      expect(prose, isNot(matches(RegExp(r'\d{4}-\d{2}-\d{2}'))));
    },
  );

  test(
    'only material differences from comparable active days reach the review',
    () {
      List sections(int today, List<int> previous) {
        final entries = [
          for (var i = 0; i < previous.length; i++)
            TimeEntry(
              id: 'focus:$i',
              minutes: previous[i],
              createdAt: now.subtract(Duration(days: i + 1)),
            ),
          TimeEntry(id: 'focus:today', minutes: today, createdAt: now),
        ];
        return jsonDecode(
          qwenEvidence(capture([task('المسودة', firstUse, entries: entries)])),
        )['sections'];
      }

      expect(sections(74, [58, 60, 60, 62]).first['context'], isNull);
      expect(sections(74, [20, 30]).first['context'], isNull);
      expect(
        sections(74, [30, 30, 30, 30]).first['context'],
        contains('تركيز أكثر'),
      );
      expect(
        sections(15, [60, 60, 60, 60]).first['context'],
        contains('تركيز أقل'),
      );
    },
  );

  test(
    'follow-up uses the current task’s own note despite duplicate titles',
    () {
      final first = task(
        'one',
        firstUse,
        notes: [
          TaskNote(id: 'note', text: 'بقيت مراجعة الأمثلة', createdAt: now),
        ],
      ).copyWith(title: 'الدليل');
      final closed = task(
        'two',
        firstUse,
        done: now,
        notes: [TaskNote(id: 'old', text: 'أرسلت النسخة', createdAt: now)],
      ).copyWith(title: 'الدليل');
      final evidence = jsonDecode(qwenEvidence(capture([first, closed])));
      final next = (evidence['sections'] as List).singleWhere(
        (s) => s['next'] == true,
      );
      expect(next['opening'], contains('بقيت مراجعة الأمثلة'));
      expect(next['opening'], isNot(contains('أرسلت النسخة')));
    },
  );

  test('window, partial logical day, precise totals and as-of status', () {
    final atStart = DateTime(2026, 11, 2, 4);
    final yesterday = DateTime(2026, 11, 29, 3, 59);
    final recent = task(
      'تطوير',
      firstUse,
      tag: 'مشروع',
      done: now,
      entries: [
        TimeEntry(id: 'focus:1', minutes: 12, createdAt: now),
        TimeEntry(id: 'focus:2', minutes: 24, createdAt: yesterday),
        TimeEntry(id: 'manual', minutes: 9, createdAt: now),
      ],
    );
    final snapshot = capture([
      recent,
      task(
        'خارج الفترة',
        firstUse,
        done: atStart.subtract(const Duration(seconds: 1)),
      ),
      task('الحد', atStart, done: atStart),
      task('لاحقة', now.add(const Duration(minutes: 1))),
      task('محذوفة', now).copyWith(isDeleted: true),
      task('مفتوحة', firstUse, done: now.add(const Duration(minutes: 1))),
    ]);
    expect(snapshot.day, DateTime(2026, 11, 29));
    final data = jsonDecode(snapshot.prompt(compact: false)) as Map;
    expect(data['windowStart'], '2026-11-02');
    expect(data['dailyTotals'], hasLength(28));
    expect(data['dailyTotals']['2026-11-29'], [0, 1, 1, 12, 9, 0]);
    expect(data['dailyTotals']['2026-11-28'], [0, 0, 1, 24, 0, 0]);
    expect(data['dailyTotals']['2026-11-02'], [1, 1, 0, 0, 0, 0]);
    expect(data['openNow'], {'today': 1});
    expect(data['pendingExamples'].single['task'], 'مفتوحة');
    expect(
      data['priorWorkForActiveTags'].single['lastWorkDayInWindow'],
      '2026-11-28',
    );
    expect(
      capture([
        recent,
      ], first: DateTime(2026, 11, 22, 4)).payload['dailyTotals'],
      hasLength(8),
    );
    expect(capture([recent], boundary: 0).day, DateTime(2026, 11, 30));
  });

  test(
    'material evidence is stable across cosmetic edits, and scoped to active projects',
    () {
      final active = task(
        'عمل',
        firstUse,
        tag: 'مشروع',
        entries: [TimeEntry(id: 'focus:1', minutes: 20, createdAt: now)],
      );
      final base = saved(capture([active]));
      final past = DateTime(2026, 11, 22);
      expect(
        capture([
          active.copyWith(title: 'صياغة', updatedAt: now, pinnedAt: now),
        ]).changedSince(base),
        isFalse,
      );
      expect(
        capture([
          active,
        ], at: now.add(const Duration(minutes: 25))).changedSince(base),
        isFalse,
      );
      expect(
        capture([
          active,
          task('قديم', past, tag: 'آخر', done: past),
        ]).changedSince(base),
        isFalse,
      );
      expect(
        capture([
          active,
          task('قديم', past, tag: 'مشروع', done: past),
        ]).changedSince(base),
        isTrue,
      );
      expect(
        capture([
          active.copyWith(
            timeEntries: [
              ...active.timeEntries,
              TimeEntry(id: 'focus:2', minutes: 15, createdAt: now),
            ],
          ),
        ]).changedSince(base),
        isTrue,
      );
      expect(
        capture([
          active.copyWith(
            notes: [TaskNote(id: 'n', text: 'سُلّمت المسودة', createdAt: now)],
          ),
        ]).changedSince(base),
        isTrue,
      );
      expect(capture([active, task('تخطيط', now)]).changedSince(base), isTrue);
      expect(
        capture([active.copyWith(completedAt: now)]).changedSince(base),
        isTrue,
      );
      final tomorrow = DateTime(2026, 11, 30, 5);
      final auto = task('daily:x:date', tomorrow).copyWith(repeatId: 'x');
      expect(capture([active, auto], at: tomorrow).changedSince(base), isFalse);
      expect(
        capture([
          active,
          task('بدء العمل', tomorrow),
        ], at: tomorrow).changedSince(base),
        isTrue,
      );
      expect(capture([active.copyWith(isDeleted: true)]).hasActivity, isFalse);
    },
  );

  test(
    'large histories retain exact numbers and bounded representative content',
    () {
      final many = [
        for (var i = 0; i < 1200; i++)
          task('مهمة طويلة $i ${'م' * 200}', now, done: now),
      ];
      final snapshot = capture(many);
      for (final compact in [true, false]) {
        final prompt = snapshot.prompt(compact: compact);
        expect(prompt.length, lessThan(6200));
        final data = jsonDecode(prompt);
        expect(data['dailyTotals']['2026-11-29'], [1200, 1200, 0, 0, 0, 0]);
        expect(data['todayExamples'], isNotEmpty);
      }
    },
  );

  test(
    'legacy history establishes first use and a restore supersedes an in-flight review',
    () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final repo = await SqliteTaskRepository.open(
        databasePath: inMemoryDatabasePath,
      );
      addTearDown(repo.close);
      await repo.upsertTask(task('محذوفة', firstUse).copyWith(isDeleted: true));
      await repo.upsertTask(task('عمل قديم', now));
      final c = TaskController(repo, clock: () => now);
      addTearDown(c.dispose);
      await c.load();
      expect(c.reviewUnlockAt, firstUse.toUtc().add(const Duration(days: 7)));
      await c.generateReview((_) async => 'قبل الاستعادة');
      final backup = await repo.exportBackup();
      await c.addTimeEntry(c.tasks.single, hours: 0, minutes: 15);
      final started = Completer<void>(), answer = Completer<String>();
      final waiting = c.generateReview((_) {
        started.complete();
        return answer.future;
      });
      await started.future;
      await c.restoreData(() => repo.importBackup(backup, now));
      answer.complete('نتيجة طلب قديم');
      await waiting;
      expect(c.dailyReview!.text, 'قبل الاستعادة');
      expect((await repo.getDailyReview())!.text, 'قبل الاستعادة');
      expect((await c.captureReview()).changedSince(c.dailyReview), isFalse);
    },
  );

  test(
    'first launch, seven full days, atomic replacement, duplicate requests and reopen',
    () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final dir = await Directory.systemTemp.createTemp('najeez_review_');
      addTearDown(() => dir.delete(recursive: true));
      final path = '${dir.path}/tasks.db';
      var time = DateTime(2026, 10, 1, 14);
      final repo = await SqliteTaskRepository.open(databasePath: path);
      final c = TaskController(repo, clock: () => time);
      await c.load();
      final unlock = time.add(const Duration(days: 7));
      time = unlock.subtract(const Duration(seconds: 1));
      await c.create('مهمة اليوم');
      await c.generateReview((_) => throw StateError('too early'));
      expect(c.dailyReview, isNull);
      time = unlock;
      final started = Completer<void>(), result = Completer<String>();
      final first = c.generateReview((s) {
        started.complete();
        return result.future;
      });
      await started.future;
      await c.generateReview((_) => throw StateError('concurrent'));
      expect(c.reviewBusy, isTrue);
      result.complete('مراجعة الصباح');
      await first;
      await c.generateReview((_) => throw StateError('duplicate'));
      await c.addTimeEntry(c.tasks.single, hours: 0, minutes: 30);
      await expectLater(
        c.generateReview((_) async => '   '),
        throwsFormatException,
      );
      await expectLater(
        c.generateReview((_) => throw StateError('interrupted')),
        throwsStateError,
      );
      expect((await repo.getDailyReview())!.text, 'مراجعة الصباح');
      final cancelled = Completer<String>(), running = Completer<void>();
      final cancelledRequest = c.generateReview((_) {
        running.complete();
        return cancelled.future;
      });
      await running.future;
      c.cancelReview();
      cancelled.complete('نص متأخر');
      await cancelledRequest;
      expect(c.dailyReview!.text, 'مراجعة الصباح');
      expect((await repo.getDailyReview())!.text, 'مراجعة الصباح');
      final old = c.dailyReview!;
      await repo.close();
      c.dispose();
      final reopened = await SqliteTaskRepository.open(databasePath: path);
      final fresh = TaskController(reopened, clock: () => time);
      await fresh.load();
      expect(fresh.reviewUnlockAt, unlock.toUtc());
      expect(fresh.dailyReview!.encode(), old.encode());
      expect(
        (await fresh.captureReview()).changedSince(fresh.dailyReview),
        isTrue,
      );
      await fresh.generateReview((_) async => 'مراجعة محدثة');
      expect((await reopened.getDailyReview())!.text, 'مراجعة محدثة');
      final tasksBefore = fresh.tasks.length;
      await fresh.resetReviewForTesting();
      await fresh.load();
      expect(fresh.dailyReview, isNull);
      expect(await reopened.getDailyReview(), isNull);
      expect(fresh.tasks.length, tasksBefore);
      expect(fresh.reviewUnlockAt, unlock.toUtc());
      await fresh.generateReview((_) async => 'إعادة اختبار نفس اليوم');
      expect((await reopened.getDailyReview())!.text, 'إعادة اختبار نفس اليوم');
      time = time.add(const Duration(days: 1));
      await fresh.refreshDay();
      await fresh.generateReview((_) => throw StateError('new day only'));
      expect(fresh.dailyReview!.day, old.day);
      await fresh.create('نشاط جديد');
      final pending = Completer<String>(), generating = Completer<void>();
      final stale = fresh.generateReview((_) {
        generating.complete();
        return pending.future;
      });
      await generating.future;
      await fresh.reset();
      pending.complete('مراجعة قديمة');
      await stale;
      expect(await reopened.getDailyReview(), isNull);
      expect(fresh.reviewAgeEligible, isFalse);
      await reopened.close();
      fresh.dispose();
    },
  );
}
