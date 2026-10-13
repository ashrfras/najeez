import 'dart:math';
import 'package:flutter/foundation.dart';
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
  bool isLoading = true;
  Object? error;
  DateTime get now => _clock();
  List<Task> get tasks =>
      List.unmodifiable(_tasks.where((task) => !task.isDeleted));
  List<String> get availableTags => _tasks
      .map((task) => task.tag)
      .whereType<String>()
      .where((tag) => tag.isNotEmpty)
      .toSet()
      .toList();

  Future<void> load() async {
    try {
      _tasks = await _repository.getTasks();
      error = null;
    } catch (exception) {
      error = exception;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

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
        scheduledDate: scheduleFor(bucket, timestamp),
        tag: cleanTag == null || cleanTag.isEmpty ? null : cleanTag,
      ),
    );
  }

  Future<void> complete(Task task) =>
      _save(task.copyWith(completedAt: now, updatedAt: now));

  Future<void> restore(Task task) {
    final bucket = visibleBucket(task, now);
    return _save(
      task.copyWith(
        clearCompletedAt: true,
        updatedAt: now,
        bucket: bucket,
        scheduledDate: scheduleFor(bucket, now),
        clearScheduledDate: bucket != TaskBucket.tomorrow,
      ),
    );
  }

  Future<void> move(Task task, TaskBucket bucket) => _save(
    task.copyWith(
      bucket: bucket,
      updatedAt: now,
      scheduledDate: scheduleFor(bucket, now),
      clearScheduledDate: bucket != TaskBucket.tomorrow,
    ),
  );

  Future<void> update(
    Task task,
    String title, {
    required TaskBucket bucket,
    String? tag,
  }) async {
    final clean = title.trim();
    if (clean.isEmpty) return;
    task = _tasks.firstWhere((item) => item.id == task.id);
    final cleanTag = tag?.trim();
    final timestamp = now;
    final bucketChanged = bucket != visibleBucket(task, timestamp);
    await _save(
      task.copyWith(
        title: clean,
        updatedAt: timestamp,
        bucket: bucketChanged ? bucket : task.bucket,
        scheduledDate: bucketChanged ? scheduleFor(bucket, timestamp) : null,
        clearScheduledDate: bucketChanged && bucket != TaskBucket.tomorrow,
        tag: cleanTag,
        clearTag: cleanTag == null || cleanTag.isEmpty,
      ),
    );
  }

  Future<void> delete(Task task) =>
      _save(task.copyWith(isDeleted: true, updatedAt: now));

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

  void refreshDay() => notifyListeners();
}
