import 'task.dart';

DateTime calendarDay(DateTime value) =>
    DateTime(value.year, value.month, value.day);

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

DateTime? scheduleFor(TaskBucket bucket, DateTime now) => switch (bucket) {
  TaskBucket.today => null,
  TaskBucket.tomorrow => DateTime(now.year, now.month, now.day + 1),
  TaskBucket.later => null,
};

/// Tomorrow tasks appear today from 5:00 AM on their scheduled day.
/// Later tasks stay later until they are moved manually.
TaskBucket visibleBucket(Task task, DateTime now) {
  if (task.bucket != TaskBucket.tomorrow) return task.bucket;
  final scheduled = task.scheduledDate;
  if (scheduled != null &&
      !now.isBefore(
        DateTime(scheduled.year, scheduled.month, scheduled.day, 5),
      )) {
    return TaskBucket.today;
  }
  return task.bucket;
}

Map<DateTime, List<Task>> completedByDay(Iterable<Task> tasks) {
  final grouped = <DateTime, List<Task>>{};
  for (final task in tasks) {
    if (task.isDeleted || task.completedAt == null) continue;
    grouped.putIfAbsent(calendarDay(task.completedAt!), () => []).add(task);
  }
  for (final dayTasks in grouped.values) {
    dayTasks.sort((a, b) => b.completedAt!.compareTo(a.completedAt!));
  }
  return grouped;
}
