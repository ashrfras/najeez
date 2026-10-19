import 'package:baqi/core/design.dart';
import 'package:baqi/features/statistics/presentation/statistics_screen.dart';
import 'package:baqi/features/tasks/domain/task_controller.dart';
import 'package:baqi/features/tasks/presentation/task_composer_screen.dart';
import 'package:baqi/features/tasks/presentation/task_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test.dart' show MemoryRepository;

void main() {
  test('categories automatically use all twelve distinct accent colors', () {
    expect(AppColors.categoryPalette, hasLength(12));
    expect(AppColors.categoryPalette.toSet(), hasLength(12));
    final colors = [
      for (var rune = 97; rune < 109; rune++)
        AppColors.category(String.fromCharCode(rune)),
    ];
    expect(colors.toSet(), AppColors.categoryPalette.toSet());
    expect(AppColors.category('a'), AppColors.purple);
    expect(AppColors.category('  عمل  '), AppColors.category('عمل'));
    for (final tag in [null, '', '   ']) {
      expect(AppColors.category(tag), AppColors.muted);
    }
  });

  testWidgets(
    'tasks, category selection and statistics share category colors',
    (tester) async {
      final now = DateTime(2026, 10, 19, 12);
      final repository = MemoryRepository();
      final controller = TaskController(repository, clock: () => now);
      addTearDown(controller.dispose);
      await controller.load();
      await controller.create('مهمة', tag: 'عمل');
      final task = controller.tasks.single;
      final color = AppColors.category(task.tag);

      Future<void> mount(Widget home) async {
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('ar'),
            supportedLocales: const [Locale('ar')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: home,
          ),
        );
        await tester.pumpAndSettle();
      }

      await mount(
        Scaffold(
          body: TaskRow(task: task, onToggle: () {}, onActions: () {}),
        ),
      );
      expect(tester.widget<Text>(find.text('عمل')).style?.color, color);
      final badge = tester.widget<Container>(
        find
            .ancestor(of: find.text('عمل'), matching: find.byType(Container))
            .first,
      );
      expect(
        (badge.decoration! as BoxDecoration).color,
        color.withValues(alpha: .15),
      );

      await mount(TaskComposerScreen(controller: controller, task: task));
      expect(tester.widget<Text>(find.text('عمل')).style?.color, color);
      await tester.tap(find.text('عمل'));
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.text('عمل')).style?.color, color);

      await controller.complete(task);
      await controller.setTimeTrackingEnabled(false);
      await mount(StatisticsScreen(controller: controller, onActions: (_) {}));
      final markers = tester.widgetList<Icon>(find.byIcon(Icons.circle));
      expect(markers, isNotEmpty);
      expect(markers.map((icon) => icon.color), everyElement(color));
    },
  );
}
