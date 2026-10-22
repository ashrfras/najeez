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

  testWidgets('new categories can choose a color and existing badges edit it', (
    tester,
  ) async {
    final repository = MemoryRepository();
    final controller = TaskController(repository);
    addTearDown(controller.dispose);
    await controller.load();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => TaskComposerScreen(controller: controller),
              ),
            ),
            child: const Text('فتح'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('فتح'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'مهمة ملونة');
    await tester.tap(find.text('وسم جديد +'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'عمل');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('أحمر'));
    await tester.tap(find.byTooltip('أحمر'));
    await tester.tap(find.text('إضافة'));
    await tester.pumpAndSettle();
    expect(controller.categoryColor('عمل'), AppColors.red);
    final reloaded = TaskController(repository);
    addTearDown(reloaded.dispose);
    await reloaded.load();
    expect(reloaded.categoryColor('عمل'), AppColors.red);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListenableBuilder(
            listenable: reloaded,
            builder: (context, _) => TaskRow(
              task: reloaded.tasks.single,
              controller: reloaded,
              onToggle: () {},
              onActions: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.longPress(find.text('عمل'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('أخضر'));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.text('عمل')).style?.color, AppColors.green);
    expect(repository.categoryColors['عمل'], AppColors.green.toARGB32());
    await reloaded.reset();
    expect(reloaded.categoryColor('عمل'), AppColors.category('عمل'));
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
      await controller.setCategoryColor('عمل', AppColors.orange);
      final task = controller.tasks.single;
      final color = controller.categoryColor(task.tag);

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
          body: TaskRow(
            task: task,
            controller: controller,
            onToggle: () {},
            onActions: () {},
          ),
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
