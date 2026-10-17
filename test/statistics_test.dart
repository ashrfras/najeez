import 'package:baqi/features/statistics/domain/statistics.dart';
import 'package:baqi/features/tasks/domain/task.dart';
import 'package:baqi/features/tasks/domain/task_dates.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime(2026, 10, 17);
  Task task(
    String id, {
    String? tag,
    DateTime? completed,
    bool deleted = false,
    List<TimeEntry> entries = const [],
  }) => Task(
    id: id,
    title: id,
    bucket: TaskBucket.today,
    createdAt: today,
    updatedAt: today,
    completedAt: completed,
    tag: tag,
    isDeleted: deleted,
    timeEntries: entries,
  );
  TimeEntry entry(int minutes, DateTime date) =>
      TimeEntry(id: '$date', minutes: minutes, createdAt: date);

  test(
    'history bound ignores empty lookups and deleted tasks after logical grouping',
    () {
      final stats = StatisticsIndex([
        task('first-completion', completed: DateTime(2026, 10, 12)),
        task(
          'open-with-time',
          entries: [entry(20, DateTime(2026, 10, 8, 3, 59))],
        ),
        task('deleted', deleted: true, completed: DateTime(2026, 1, 1)),
        task('no-activity'),
      ], const LogicalDay(240));
      stats.day(DateTime(2020));
      stats.lastSevenDays(today);
      expect(stats.availableDayCount(today), 11); // October 7 through 17.
      expect(
        StatisticsIndex([], const LogicalDay(0)).availableDayCount(today),
        7,
      );
      expect(
        StatisticsIndex([
          task('recent', completed: today),
        ], const LogicalDay(0)).availableDayCount(today),
        7,
      );
    },
  );

  test(
    'time uses entry dates, includes open tasks and excludes deleted tasks',
    () {
      final stats = StatisticsIndex([
        task('open', tag: 'برمجة', entries: [entry(90, today)]),
        task(
          'done',
          tag: 'شخصي',
          completed: today,
          entries: [entry(30, today), entry(200, DateTime(2026, 10, 9))],
        ),
        task('no-time', tag: 'محتوى', completed: today),
        task(
          'deleted',
          completed: today,
          deleted: true,
          entries: [entry(999, today)],
        ),
      ], const LogicalDay(0));
      final summary = stats.lastSevenDays(today);
      expect(summary.totalMinutes, 120);
      expect(summary.completedTasks.length, 2);
      expect(summary.minutesByTag, {'برمجة': 90, 'شخصي': 30});
      expect(stats.day(today).totalMinutes, 120);
      expect(stats.day(DateTime(2026, 10, 9)).totalMinutes, 200);
    },
  );

  test(
    'seven calendar days include gaps and cross year and month boundaries',
    () {
      final now = DateTime(2027, 1, 3);
      final stats = StatisticsIndex([
        task(
          'first',
          completed: DateTime(2026, 12, 28),
          entries: [entry(10, DateTime(2026, 12, 28))],
        ),
        task(
          'outside',
          completed: DateTime(2026, 12, 27),
          entries: [entry(70, DateTime(2026, 12, 27))],
        ),
        task(
          'future',
          completed: DateTime(2027, 1, 4),
          entries: [entry(70, DateTime(2027, 1, 4))],
        ),
      ], const LogicalDay(0));
      expect(stats.lastSevenDays(now).totalMinutes, 10);
      expect(stats.lastSevenDays(now).completedTasks.single.id, 'first');
      expect(stats.day(now).completedTasks, isEmpty);
    },
  );

  test('logical boundary independently applies to completions and entries', () {
    const logicalDay = LogicalDay(270);
    final stats = StatisticsIndex([
      task(
        'before',
        completed: DateTime(2026, 10, 17, 4, 29),
        entries: [
          entry(30, DateTime(2026, 10, 17, 4, 29)),
          entry(60, DateTime(2026, 10, 17, 4, 30)),
        ],
      ),
      task('after', completed: DateTime(2026, 10, 17, 4, 30)),
      task('later', completed: DateTime(2026, 10, 17, 5)),
    ], logicalDay);
    expect(stats.day(DateTime(2026, 10, 16)).totalMinutes, 30);
    expect(stats.day(today).totalMinutes, 60);
    expect(
      stats.day(DateTime(2026, 10, 16)).completedTasks.single.id,
      'before',
    );
    expect(stats.day(today).completedTasks.map((task) => task.id), [
      'later',
      'after',
    ]);
  });

  test('untagged time is grouped and zero-time completions remain counted', () {
    final stats = StatisticsIndex([
      task('none', entries: [entry(10, today)]),
      task('blank', tag: '  ', entries: [entry(20, today)]),
      task('zero', tag: 'zero', completed: today, entries: [entry(0, today)]),
    ], const LogicalDay(0));
    expect(stats.day(today).minutesByTag, {null: 30});
    expect(stats.day(today).completedTasks.length, 1);
    expect(
      StatisticsIndex(
        [],
        const LogicalDay(0),
      ).lastSevenDays(today).totalMinutes,
      0,
    );
  });
}
