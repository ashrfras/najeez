enum TaskBucket { today, tomorrow, later }

class TimeEntry {
  const TimeEntry({
    required this.id,
    required this.minutes,
    required this.createdAt,
  });

  final String id;
  final int minutes;
  final DateTime createdAt;
}

String durationLabel(int minutes) {
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  if (hours == 0) return '$remainder د';
  if (remainder == 0) return '$hours س';
  return '$hours س $remainder د';
}

class Task {
  const Task({
    required this.id,
    required this.title,
    required this.bucket,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
    this.scheduledDate,
    this.tag,
    this.isDeleted = false,
    this.timeEntries = const [],
  });

  final String id;
  final String title;
  final TaskBucket bucket;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;
  final DateTime? scheduledDate;
  final String? tag;
  final bool isDeleted;
  final List<TimeEntry> timeEntries;

  bool get isCompleted => completedAt != null;
  int get totalMinutes =>
      timeEntries.fold(0, (sum, entry) => sum + entry.minutes);

  Task copyWith({
    String? title,
    TaskBucket? bucket,
    DateTime? updatedAt,
    DateTime? completedAt,
    DateTime? scheduledDate,
    String? tag,
    bool clearCompletedAt = false,
    bool clearScheduledDate = false,
    bool clearTag = false,
    bool? isDeleted,
    List<TimeEntry>? timeEntries,
  }) => Task(
    id: id,
    title: title ?? this.title,
    bucket: bucket ?? this.bucket,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    completedAt: clearCompletedAt ? null : completedAt ?? this.completedAt,
    scheduledDate: clearScheduledDate
        ? null
        : scheduledDate ?? this.scheduledDate,
    tag: clearTag ? null : tag ?? this.tag,
    isDeleted: isDeleted ?? this.isDeleted,
    timeEntries: timeEntries ?? this.timeEntries,
  );
}
