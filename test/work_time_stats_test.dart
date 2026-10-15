import 'package:baqi/features/tasks/domain/task.dart';
import 'package:baqi/features/tasks/domain/work_time_stats.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 15, 12);

  Task task(
    String id,
    List<TimeEntry> entries, {
    DateTime? completedAt,
    bool isDeleted = false,
  }) => Task(
    id: id,
    title: id,
    bucket: TaskBucket.today,
    createdAt: DateTime(2026, 9, 1),
    updatedAt: now,
    completedAt: completedAt,
    isDeleted: isDeleted,
    timeEntries: entries,
  );

  TimeEntry entry(String id, int minutes, DateTime date) =>
      TimeEntry(id: id, minutes: minutes, createdAt: date);

  test(
    'uses entry dates across completed and open tasks and logged days only',
    () {
      final stats = workTimeStats([
        task('open', [
          entry('today-1', 90, DateTime(2026, 10, 15, 9)),
          entry('boundary', 180, DateTime(2026, 10, 8, 18)),
          entry('outside', 500, DateTime(2026, 10, 7, 23)),
        ]),
        task('completed', [
          entry('today-2', 170, DateTime(2026, 10, 15, 11)),
          entry('older-2', 80, DateTime(2026, 10, 9, 8)),
        ], completedAt: DateTime(2026, 10, 10)),
        task('deleted', [entry('deleted', 999, now)], isDeleted: true),
      ], now);

      expect(stats.todayMinutes, 260);
      expect(stats.averageMinutes, 130);
      expect(compactDurationLabel(stats.todayMinutes), '4س 20د');
      expect(compactDurationLabel(180), '3س');
    },
  );

  test('returns no average when the seven days have no entries', () {
    final stats = workTimeStats([
      task('today', [entry('today', 90, now)]),
      task('old', [entry('old', 60, DateTime(2026, 10, 7))]),
    ], now);
    expect(stats.todayMinutes, 90);
    expect(stats.averageMinutes, isNull);
  });
}
