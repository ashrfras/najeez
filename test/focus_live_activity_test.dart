import 'package:najeez/features/tasks/domain/task_controller.dart';
import 'package:najeez/features/tasks/platform/focus_live_activity.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'focus_test.dart' show FocusRepository;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'mirrors committed sessions, deduplicates and preserves failed saves',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final calls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(FocusLiveActivity.channel, (
        call,
      ) async {
        calls.add(call);
        return null;
      });
      final repository = FocusRepository();
      final start = DateTime.utc(2026, 11, 13, 10);
      var now = start;
      final controller = TaskController(repository, clock: () => now);
      final activity = FocusLiveActivity(controller);
      addTearDown(() {
        activity.dispose();
        controller.dispose();
        messenger.setMockMethodCallHandler(FocusLiveActivity.channel, null);
        debugDefaultTargetPlatformOverride = null;
      });
      await controller.load();
      await controller.create('قراءة');
      activity.start();
      await activity.sync();
      expect(calls.single.arguments['taskId'], isNull);
      await controller.startFocus(controller.tasks.single);
      await activity.sync();
      expect(calls.last.arguments['title'], 'قراءة');
      expect(calls.last.arguments['startedAt'], start.millisecondsSinceEpoch);
      final count = calls.length;
      now = now.add(const Duration(minutes: 20));
      await activity.sync();
      expect(calls.length, count); // No ticks are sent to native code.
      repository.fail = true;
      await expectLater(controller.finishFocus(), throwsStateError);
      await activity.sync();
      expect(calls.length, count);
      repository.fail = false;
      await controller.finishFocus();
      await activity.sync();
      expect(calls.last.arguments['taskId'], isNull);
      expect(controller.tasks.single.timeEntries.single.minutes, 20);
    },
  );

  test(
    'restores original start and retries bridge errors on foreground sync',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      var attempts = 0;
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(FocusLiveActivity.channel, (
        call,
      ) async {
        attempts++;
        if (attempts == 1) {
          throw PlatformException(code: 'activity_request_failed');
        }
        calls.add(call);
        return null;
      });
      final repository = FocusRepository();
      final start = DateTime.utc(2026, 11, 13, 10);
      final original = TaskController(repository, clock: () => start);
      await original.load();
      await original.create('تقرير');
      await original.startFocus(original.tasks.single);
      original.dispose();
      final controller = TaskController(repository);
      await controller.load();
      final activity = FocusLiveActivity(controller);
      addTearDown(() {
        activity.dispose();
        controller.dispose();
        messenger.setMockMethodCallHandler(FocusLiveActivity.channel, null);
        debugDefaultTargetPlatformOverride = null;
      });
      activity.start();
      await activity.sync(force: true);
      expect(attempts, 2);
      expect(calls.single.arguments['startedAt'], start.millisecondsSinceEpoch);
    },
  );
}
