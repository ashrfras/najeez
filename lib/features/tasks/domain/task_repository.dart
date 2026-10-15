import 'task.dart';

abstract class TaskRepository {
  Future<List<Task>> getTasks();
  Future<void> upsertTask(Task task);
  Future<int> getLogicalDayStartMinutes() async => 0;
  Future<void> setLogicalDayStartMinutes(int minutes) async {}
  Future<void> close();
}
