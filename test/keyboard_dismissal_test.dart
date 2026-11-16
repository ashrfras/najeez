import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:najeez/features/tasks/domain/task.dart';
import 'package:najeez/features/tasks/domain/task_controller.dart';
import 'package:najeez/main.dart';

import 'widget_test.dart' show MemoryRepository;

void main() {
  testWidgets(
    'outside touches dismiss the keyboard',
    (tester) async {
      final controller = TaskController(MemoryRepository());
      addTearDown(controller.dispose);
      await controller.load();
      await tester.pumpWidget(
        BaqiApp(controller: controller, splashDuration: Duration.zero),
      );
      await tester.tap(find.text('أضف مهمة ...'));
      await tester.pumpAndSettle();
      final title = find.byType(TextField).first;
      await tester.enterText(title, 'مهمة جديدة');
      await tester.tap(title);
      await tester.pump();
      expect(tester.testTextInput.isVisible, isTrue);

      // A plain heading dismisses without losing the draft.
      await tester.tap(find.text('إضافة مهمة'));
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isFalse);
      expect(tester.widget<TextField>(title).controller!.text, 'مهمة جديدة');

      await tester.tap(title);
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isTrue);
      await tester.tap(find.text('وسم جديد +'));
      await tester.pumpAndSettle();
      final tag = find.byType(TextField).last;
      expect(tester.widget<TextField>(tag).focusNode!.hasFocus, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
      await tester.tap(title);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(tag).focusNode!.hasFocus, isFalse);
      expect(tester.testTextInput.isVisible, isTrue);

      // Outside controls still receive the same touch and perform their action.
      await tester.tap(find.text('غداً'));
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isFalse);
      await tester.tap(find.text('إضافة'));
      await tester.pumpAndSettle();
      expect(controller.tasks.single.title, 'مهمة جديدة');
      expect(controller.tasks.single.bucket, TaskBucket.tomorrow);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.iOS,
      TargetPlatform.android,
    }),
  );
}
