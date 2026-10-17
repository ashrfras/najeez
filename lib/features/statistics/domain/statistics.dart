import '../../tasks/domain/task.dart';
import '../../tasks/domain/task_dates.dart';

/// A read model built from task events, independent of storage and presentation.
/// Time belongs to its entry's logical day; completions to their completion day.
class DayStatistics {
  DayStatistics({required this.day});

  final DateTime day;
  final List<Task> completedTasks = [];
  final Map<String?, int> minutesByTag = {};
  Map<String?, int> get completedByTag {
    final counts = <String?, int>{};
    for (final task in completedTasks) {
      final tag = task.tag?.trim();
      final category = tag == null || tag.isEmpty ? null : tag;
      counts.update(category, (count) => count + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  int get totalMinutes => minutesByTag.values.fold(0, (a, b) => a + b);
}

class StatisticsIndex {
  StatisticsIndex(
    Iterable<Task> tasks,
    LogicalDay logicalDay, {
    bool includeTime = true,
  }) {
    for (final task in tasks) {
      if (task.isDeleted) continue;
      if (task.completedAt case final completedAt?) {
        day(logicalDay.dayOf(completedAt)).completedTasks.add(task);
      }
      final tag = task.tag?.trim();
      final category = tag == null || tag.isEmpty ? null : tag;
      if (!includeTime) continue;
      for (final entry in task.timeEntries) {
        if (entry.minutes <= 0) continue;
        day(logicalDay.dayOf(entry.createdAt)).minutesByTag.update(
          category,
          (minutes) => minutes + entry.minutes,
          ifAbsent: () => entry.minutes,
        );
      }
    }
    _oldestActivityDay = _days.keys.fold<DateTime?>(
      null,
      (oldest, date) => oldest == null || date.isBefore(oldest) ? date : oldest,
    );
    for (final value in _days.values) {
      value.completedTasks.sort((a, b) {
        final order = b.completedAt!.compareTo(a.completedAt!);
        return order == 0 ? a.id.compareTo(b.id) : order;
      });
    }
  }

  final Map<DateTime, DayStatistics> _days = {};
  late final DateTime? _oldestActivityDay;

  /// Always show the latest week, then stop at the oldest recorded activity.
  /// UTC calendar labels avoid daylight-saving changes affecting the day count.
  int availableDayCount(DateTime today) {
    final oldest = _oldestActivityDay;
    if (oldest == null) return 7;
    final end = DateTime.utc(today.year, today.month, today.day);
    final start = DateTime.utc(oldest.year, oldest.month, oldest.day);
    final count = end.difference(start).inDays + 1;
    return count < 7 ? 7 : count;
  }

  DayStatistics day(DateTime date) =>
      _days.putIfAbsent(date, () => DayStatistics(day: date));

  DayStatistics lastSevenDays(DateTime today) {
    final summary = DayStatistics(day: today);
    for (var offset = 0; offset < 7; offset++) {
      final value = day(DateTime(today.year, today.month, today.day - offset));
      summary.completedTasks.addAll(value.completedTasks);
      for (final entry in value.minutesByTag.entries) {
        summary.minutesByTag.update(
          entry.key,
          (minutes) => minutes + entry.value,
          ifAbsent: () => entry.value,
        );
      }
    }
    return summary;
  }
}
