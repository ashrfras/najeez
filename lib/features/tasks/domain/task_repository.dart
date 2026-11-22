import '../../review/daily_review.dart';
import 'task.dart';

abstract class TaskRepository {
  Future<List<Task>> getTasks();
  Future<void> upsertTask(Task task);
  Future<void> reset();
  Future<FocusSession?> getFocusSession() async => null;
  // Persist the time entry and session change together when finishing/switching.
  Future<void> saveFocusSession(FocusSession? session, {Task? task}) async {
    if (task != null) await upsertTask(task);
  }

  Future<List<DailyRepeat>> getDailyRepeats() async => [];
  Future<void> saveDailyRepeat(DailyRepeat repeat, {Task? task}) async {
    throw UnsupportedError('Daily repeats are not supported');
  }

  Future<int> getLogicalDayStartMinutes() async => 0;
  Future<void> setLogicalDayStartMinutes(int minutes) async {}
  Future<bool> getTimeTrackingEnabled() async => true;
  Future<void> setTimeTrackingEnabled(bool enabled) async {}
  Future<Map<String, int>> getCategoryColors() async => {};
  Future<void> setCategoryColor(String tag, int color) async {}
  Future<void> resetForNewUse(DateTime timestamp) => reset();
  Future<DateTime> ensureFirstUse(DateTime earliest) async => earliest;
  Future<SavedDailyReview?> getDailyReview() async => null;
  Future<void> saveDailyReview(SavedDailyReview review) async {
    throw UnsupportedError('Daily review storage unavailable');
  }

  Future<void> close();
}
