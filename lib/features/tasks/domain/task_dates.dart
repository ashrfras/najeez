import 'task.dart';

/// Interprets stored event instants using the user's local day boundary.
class LogicalDay {
  const LogicalDay(this.startMinutes)
    : assert(startMinutes >= 0 && startMinutes < 24 * 60);

  final int startMinutes;

  int get hour => startMinutes ~/ 60;
  int get minute => startMinutes % 60;

  DateTime dayOf(DateTime instant) {
    final local = instant.toLocal();
    final day = DateTime(local.year, local.month, local.day);
    return local.hour * 60 + local.minute < startMinutes
        ? DateTime(day.year, day.month, day.day - 1)
        : day;
  }

  DateTime nextStart(DateTime instant) {
    final day = dayOf(instant);
    return DateTime(day.year, day.month, day.day + 1, hour, minute);
  }

  bool same(DateTime a, DateTime b) => dayOf(a) == dayOf(b);
}

DateTime? scheduleFor(
  TaskBucket bucket,
  DateTime now, [
  LogicalDay logicalDay = const LogicalDay(0),
]) => switch (bucket) {
  TaskBucket.today => null,
  TaskBucket.tomorrow => (() {
    final today = logicalDay.dayOf(now);
    return DateTime(today.year, today.month, today.day + 1);
  })(),
  TaskBucket.later => null,
};

/// Later tasks stay later until they are moved manually.
TaskBucket visibleBucket(
  Task task,
  DateTime now, [
  LogicalDay logicalDay = const LogicalDay(0),
]) {
  if (task.bucket != TaskBucket.tomorrow) return task.bucket;
  final scheduled = task.scheduledDate;
  if (scheduled != null && !logicalDay.dayOf(now).isBefore(scheduled)) {
    return TaskBucket.today;
  }
  return task.bucket;
}

Map<DateTime, List<Task>> completedByDay(
  Iterable<Task> tasks, [
  LogicalDay logicalDay = const LogicalDay(0),
]) {
  final grouped = <DateTime, List<Task>>{};
  for (final task in tasks) {
    if (task.isDeleted || task.completedAt == null) continue;
    grouped
        .putIfAbsent(logicalDay.dayOf(task.completedAt!), () => [])
        .add(task);
  }
  for (final dayTasks in grouped.values) {
    dayTasks.sort((a, b) => b.completedAt!.compareTo(a.completedAt!));
  }
  return grouped;
}
