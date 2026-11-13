import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/task_controller.dart';

/// Mirrors committed local state. SQLite remains the source of truth.
class FocusLiveActivity {
  FocusLiveActivity(this.controller);

  static const channel = MethodChannel('ma.raqmain.najeez/focus_activity');
  final TaskController controller;
  Future<void> _queue = Future.value();
  ({String? taskId, String? title, int? startedAt})? _last;
  bool _disposed = false;

  void start() {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    controller.addListener(_changed);
    sync();
  }

  void _changed() => unawaited(sync());

  Future<void> sync({bool force = false}) {
    if (_disposed ||
        kIsWeb ||
        defaultTargetPlatform != TargetPlatform.iOS ||
        controller.isLoading ||
        controller.error != null) {
      return Future.value();
    }
    final session = controller.focusSession;
    final task = controller.focusedTask;
    final snapshot = (
      taskId: task?.id,
      title: task?.title,
      startedAt: session?.startedAt.millisecondsSinceEpoch,
    );
    _queue = _queue.then((_) async {
      if (_disposed || (!force && snapshot == _last)) return;
      try {
        await channel.invokeMethod<void>('sync', {
          'taskId': snapshot.taskId,
          'title': snapshot.title,
          'startedAt': snapshot.startedAt,
        });
        _last = snapshot;
      } on PlatformException catch (error) {
        debugPrint('Focus Live Activity: ${error.code}');
      } on MissingPluginException {
        debugPrint('Focus Live Activity bridge is unavailable');
      }
    });
    return _queue;
  }

  void dispose() {
    _disposed = true;
    controller.removeListener(_changed);
  }
}
