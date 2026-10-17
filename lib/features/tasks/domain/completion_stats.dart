import 'task.dart';
import 'task_dates.dart';

/// Completion counts for today and the seven preceding completed logical days.
class CompletionStats {
  CompletionStats(
    Iterable<Task> tasks,
    DateTime now, [
    LogicalDay logicalDay = const LogicalDay(0),
  ]) {
    final today = logicalDay.dayOf(now);
    final firstDay = DateTime(today.year, today.month, today.day - 7);
    var previousCount = 0;
    for (final task in tasks) {
      if (task.isDeleted || task.completedAt == null) continue;
      final day = logicalDay.dayOf(task.completedAt!);
      if (day == today) {
        todayCount++;
      } else if (!day.isBefore(firstDay) && day.isBefore(today)) {
        previousCount++;
      }
    }
    averageCount = previousCount / 7;
  }

  int todayCount = 0;
  late final double averageCount;
  String get averageLabel =>
      averageCount.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '');
}
