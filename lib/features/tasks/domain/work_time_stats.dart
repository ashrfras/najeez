import 'task.dart';
import 'task_dates.dart';

class WorkTimeStats {
  const WorkTimeStats({
    required this.todayMinutes,
    required this.averageMinutes,
  });

  final int todayMinutes;
  final int? averageMinutes;
}

/// Today's total and the average of the seven preceding calendar days.
WorkTimeStats workTimeStats(Iterable<Task> tasks, DateTime now) {
  final today = calendarDay(now);
  final firstDay = DateTime(today.year, today.month, today.day - 7);
  final minutesByDay = <DateTime, int>{};
  var todayMinutes = 0;

  for (final task in tasks) {
    if (task.isDeleted) continue;
    for (final entry in task.timeEntries) {
      final day = calendarDay(entry.createdAt);
      if (day == today) {
        todayMinutes += entry.minutes;
        continue;
      }
      if (day.isBefore(firstDay) || !day.isBefore(today)) continue;
      minutesByDay.update(
        day,
        (minutes) => minutes + entry.minutes,
        ifAbsent: () => entry.minutes,
      );
    }
  }

  final loggedDays = minutesByDay.values
      .where((minutes) => minutes > 0)
      .toList();
  return WorkTimeStats(
    todayMinutes: todayMinutes,
    averageMinutes: loggedDays.isEmpty
        ? null
        : (loggedDays.reduce((sum, minutes) => sum + minutes) /
                  loggedDays.length)
              .round(),
  );
}

String compactDurationLabel(int minutes) {
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  if (hours == 0) return '$remainderد';
  if (remainder == 0) return '$hoursس';
  return '$hoursس $remainderد';
}
