import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/design.dart';
import 'task.dart';
import 'task_dates.dart';
import 'task_repository.dart';

class TaskController extends ChangeNotifier {
  TaskController(this._repository, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final TaskRepository _repository;
  final DateTime Function() _clock;
  final Random _random = Random.secure();
  List<Task> _tasks = [];
  List<DailyRepeat> _repeats = [];
  Future<void> _repeatQueue = Future.value();

  Future<void> _serializeRepeat(Future<void> Function() action) {
    final result = _repeatQueue.then((_) => action());
    _repeatQueue = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace stackTrace) {},
    );
    return result;
  }

  DailyRepeat? repeatFor(Task task) {
    for (final repeat in _repeats) {
      if (repeat.id == task.repeatId) return repeat;
    }
    return null;
  }

  bool repeatsDaily(Task task) => repeatFor(task)?.enabled ?? false;

  Future<void> _saveRepeat(DailyRepeat repeat, {Task? task}) async {
    if (task != null && task.isPinned && !canPin(task)) {
      task = task.copyWith(clearPinnedAt: true);
    }
    await _repository.saveDailyRepeat(repeat, task: task);
    _repeats = [repeat, ..._repeats.where((item) => item.id != repeat.id)];
    final savedTask = task;
    if (savedTask != null) {
      _tasks = [savedTask, ..._tasks.where((item) => item.id != savedTask.id)];
    }
    error = null;
    notifyListeners();
  }

  Future<void> setDailyRepeat(
    Task task,
    bool enabled,
  ) => _serializeRepeat(() async {
    task = _current(task);
    final previous = repeatFor(task);
    if (previous?.enabled == enabled || (!enabled && previous == null)) return;
    final timestamp = now;
    final today = logicalDay.dayOf(timestamp);
    final repeat = DailyRepeat(
      id: previous?.id ?? task.id,
      title: previous?.title ?? task.title,
      tag: previous == null ? task.tag : previous.tag,
      enabled: enabled,
    );
    // Activating an unfinished task uses it as today's occurrence. Completed
    // tasks keep their original day and their complete history.
    final occurrence = task.repeatId != null
        ? task
        : task.copyWith(
            repeatId: repeat.id,
            repeatDay: task.completedAt == null
                ? today
                : logicalDay.dayOf(task.completedAt!),
            bucket: task.isCompleted ? task.bucket : TaskBucket.today,
            clearScheduledDate: !task.isCompleted,
            updatedAt: timestamp,
          );
    await _saveRepeat(repeat, task: occurrence);
    if (enabled) await _generateToday();
  });

  Future<void> _generateToday() async {
    final timestamp = now;
    final day = logicalDay.dayOf(timestamp);
    for (final repeat in _repeats.where((item) => item.enabled).toList()) {
      // Include deleted and moved occurrences: neither action should recreate
      // an occurrence that already belonged to this logical date.
      if (_tasks.any(
        (task) => task.repeatId == repeat.id && task.repeatDay == day,
      )) {
        continue;
      }
      await _save(
        Task(
          id: 'daily:${repeat.id}:${day.toIso8601String().substring(0, 10)}',
          title: repeat.title,
          tag: repeat.tag,
          bucket: TaskBucket.today,
          createdAt: timestamp,
          updatedAt: timestamp,
          repeatId: repeat.id,
          repeatDay: day,
        ),
      );
    }
  }

  Map<String, int> _categoryColors = {};

  Color categoryColor(String? tag) {
    final value = _categoryColors[tag?.trim()];
    return value == null ? AppColors.category(tag) : Color(value);
  }

  Future<void> setCategoryColor(String tag, Color color) async {
    final label = tag.trim();
    if (label.isEmpty || !AppColors.categoryPalette.contains(color)) return;
    await _repository.setCategoryColor(label, color.toARGB32());
    _categoryColors[label] = color.toARGB32();
    notifyListeners();
  }

  LogicalDay _logicalDay = const LogicalDay(0);
  bool _timeTrackingEnabled = true;
  bool get timeTrackingEnabled => _timeTrackingEnabled;
  bool isLoading = true;
  Object? error;
  DateTime get now => _clock();
  LogicalDay get logicalDay => _logicalDay;
  List<Task> get tasks =>
      List.unmodifiable(_tasks.where((task) => !task.isDeleted));
  List<String> get availableTags => _tasks
      .map((task) => task.tag)
      .whereType<String>()
      .where((tag) => tag.isNotEmpty)
      .toSet()
      .toList();

  Future<void> load() => _serializeRepeat(() async {
    try {
      _tasks = await _repository.getTasks();
      _repeats = await _repository.getDailyRepeats();
      _categoryColors = await _repository.getCategoryColors();
      _logicalDay = LogicalDay(await _repository.getLogicalDayStartMinutes());
      _timeTrackingEnabled = await _repository.getTimeTrackingEnabled();
      await _generateToday();
      error = null;
    } catch (exception) {
      error = exception;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  });

  Future<void> setLogicalDayStart(int minutes) async {
    if (minutes < 0 || minutes >= 24 * 60) {
      throw ArgumentError.value(minutes, 'minutes');
    }
    await _repository.setLogicalDayStartMinutes(minutes);
    _logicalDay = LogicalDay(minutes);
    await refreshDay();
  }

  Future<void> setTimeTrackingEnabled(bool enabled) async {
    await _repository.setTimeTrackingEnabled(enabled);
    _timeTrackingEnabled = enabled;
    notifyListeners();
  }

  Future<void> reset() => _serializeRepeat(() async {
    await _repository.reset();
    _tasks = [];
    _repeats = [];
    _categoryColors = {};
    _timeTrackingEnabled = true;
    _logicalDay = const LogicalDay(0);
    error = null;
    isLoading = false;
    notifyListeners();
  });

  Future<void> create(
    String title, {
    TaskBucket bucket = TaskBucket.today,
    String? tag,
  }) async {
    final clean = title.trim();
    if (clean.isEmpty) return;
    final cleanTag = tag?.trim();
    final timestamp = now;
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    final id = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    await _save(
      Task(
        id: id,
        title: clean,
        bucket: bucket,
        createdAt: timestamp,
        updatedAt: timestamp,
        scheduledDate: scheduleFor(bucket, timestamp, logicalDay),
        tag: cleanTag == null || cleanTag.isEmpty ? null : cleanTag,
      ),
    );
  }

  Task _current(Task task) => _tasks.firstWhere((item) => item.id == task.id);

  bool canPin(Task task) =>
      !task.isDeleted &&
      !task.isCompleted &&
      visibleBucket(task, now, logicalDay) == TaskBucket.today;

  Future<void> setPinned(Task task, bool pinned) async {
    task = _current(task);
    if (pinned && !canPin(task)) return;
    if (task.isPinned == pinned) return;
    var timestamp = now;
    if (pinned) {
      // Preserve pin order even when the clock has not advanced or moves back.
      for (final item in _tasks) {
        final previous = item.pinnedAt;
        if (previous != null && !timestamp.isAfter(previous)) {
          timestamp = previous.add(const Duration(microseconds: 1));
        }
      }
    }
    await _save(
      task.copyWith(
        pinnedAt: pinned ? timestamp : null,
        clearPinnedAt: !pinned,
        updatedAt: now,
        bucket: pinned ? TaskBucket.today : null,
        clearScheduledDate: pinned,
      ),
    );
  }

  Future<void> complete(Task task) =>
      _save(_current(task).copyWith(completedAt: now, updatedAt: now));

  Future<void> restore(Task task) {
    task = _current(task);
    final bucket = visibleBucket(task, now, logicalDay);
    return _save(
      task.copyWith(
        clearCompletedAt: true,
        clearPinnedAt: true,
        updatedAt: now,
        bucket: bucket,
        scheduledDate: scheduleFor(bucket, now, logicalDay),
        clearScheduledDate: bucket != TaskBucket.tomorrow,
      ),
    );
  }

  Future<void> move(Task task, TaskBucket bucket) => _save(
    _current(task).copyWith(
      bucket: bucket,
      updatedAt: now,
      scheduledDate: scheduleFor(bucket, now, logicalDay),
      clearScheduledDate: bucket != TaskBucket.tomorrow,
    ),
  );

  Future<void> update(
    Task task,
    String title, {
    required TaskBucket bucket,
    String? tag,
  }) => _serializeRepeat(() async {
    final clean = title.trim();
    if (clean.isEmpty) return;
    task = _tasks.firstWhere((item) => item.id == task.id);
    final cleanTag = tag?.trim();
    final timestamp = now;
    final bucketChanged = bucket != visibleBucket(task, timestamp, logicalDay);
    final repeat = repeatFor(task);
    final edited = task.copyWith(
      // A repeat's title describes future occurrences; recorded titles stay intact.
      title: repeat == null ? clean : task.title,
      updatedAt: timestamp,
      bucket: bucketChanged ? bucket : task.bucket,
      scheduledDate: bucketChanged
          ? scheduleFor(bucket, timestamp, logicalDay)
          : null,
      clearScheduledDate: bucketChanged && bucket != TaskBucket.tomorrow,
      tag: cleanTag,
      clearTag: cleanTag == null || cleanTag.isEmpty,
    );
    if (repeat == null) {
      await _save(edited);
    } else {
      await _saveRepeat(
        DailyRepeat(
          id: repeat.id,
          title: clean,
          tag: cleanTag == null || cleanTag.isEmpty ? null : cleanTag,
          enabled: repeat.enabled,
        ),
        task: edited,
      );
    }
  });

  Future<void> delete(Task task, {bool stopRepeating = false}) =>
      _serializeRepeat(() async {
        task = _current(task);
        final deleted = task.copyWith(isDeleted: true, updatedAt: now);
        final repeat = repeatFor(task);
        if (stopRepeating && repeat != null) {
          await _saveRepeat(
            DailyRepeat(
              id: repeat.id,
              title: repeat.title,
              tag: repeat.tag,
              enabled: false,
            ),
            task: deleted,
          );
        } else {
          await _save(deleted);
        }
      });

  Future<void> addTimeEntry(
    Task task, {
    required int hours,
    required int minutes,
  }) async {
    if (hours < 0 || minutes < 0 || minutes > 59 || hours * 60 + minutes <= 0) {
      throw ArgumentError('Invalid duration');
    }
    final current = _tasks.firstWhere((item) => item.id == task.id);
    final timestamp = now;
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    final id = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    await _save(
      current.copyWith(
        updatedAt: timestamp,
        timeEntries: [
          ...current.timeEntries,
          TimeEntry(
            id: id,
            minutes: hours * 60 + minutes,
            createdAt: timestamp,
          ),
        ],
      ),
    );
  }

  Future<void> removeTimeEntry(Task task, String entryId) async {
    final current = _tasks.firstWhere((item) => item.id == task.id);
    await _save(
      current.copyWith(
        updatedAt: now,
        timeEntries: current.timeEntries
            .where((entry) => entry.id != entryId)
            .toList(),
      ),
    );
  }

  Future<void> _save(Task task) async {
    if (task.isPinned && !canPin(task)) {
      task = task.copyWith(clearPinnedAt: true);
    }
    final previous = _tasks;
    _tasks = [task, ..._tasks.where((item) => item.id != task.id)];
    error = null;
    notifyListeners();
    try {
      await _repository.upsertTask(task);
    } catch (exception) {
      _tasks = previous;
      error = exception;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> refreshDay() => _serializeRepeat(() async {
    try {
      await _generateToday();
      error = null;
    } catch (exception) {
      error = exception;
    } finally {
      notifyListeners();
    }
  });
}
