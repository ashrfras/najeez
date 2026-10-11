enum TaskBucket { today, tomorrow, later }

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

  bool get isCompleted => completedAt != null;

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
  );
}
