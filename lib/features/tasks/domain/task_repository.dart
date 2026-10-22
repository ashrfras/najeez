import 'task.dart';

abstract class TaskRepository {
  Future<List<Task>> getTasks();
  Future<void> upsertTask(Task task);
  Future<void> reset();
  Future<int> getLogicalDayStartMinutes() async => 0;
  Future<void> setLogicalDayStartMinutes(int minutes) async {}
  Future<bool> getTimeTrackingEnabled() async => true;
  Future<void> setTimeTrackingEnabled(bool enabled) async {}
  Future<Map<String, int>> getCategoryColors() async => {};
  Future<void> setCategoryColor(String tag, int color) async {}
  Future<void> close();
}
