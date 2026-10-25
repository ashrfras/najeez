import 'package:baqi/features/settings/presentation/settings_screen.dart';
import 'package:baqi/features/statistics/presentation/statistics_screen.dart';
import 'package:baqi/features/tasks/domain/task_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test.dart' show MemoryRepository;

void main() {
  for (final statistics in [false, true]) {
    for (final bottomInset in [0.0, 34.0]) {
      final screen = statistics ? 'statistics' : 'settings';
      testWidgets(
        '$screen scrolls edge to edge with $bottomInset bottom inset',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(390, 480);
          tester.view.viewPadding = FakeViewPadding(
            top: 47,
            bottom: bottomInset,
          );
          tester.view.padding = FakeViewPadding(top: 47, bottom: bottomInset);
          addTearDown(tester.view.reset);
          final controller = TaskController(
            MemoryRepository(),
            clock: () => DateTime(2026, 10, 17, 12),
          );
          addTearDown(controller.dispose);
          await controller.load();
          await tester.pumpWidget(
            MaterialApp(
              home: Directionality(
                textDirection: TextDirection.rtl,
                child: statistics
                    ? StatisticsScreen(
                        controller: controller,
                        onActions: (_) {},
                      )
                    : SettingsScreen(controller: controller),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final list = find.byType(ListView);
          final position = tester
              .state<ScrollableState>(
                find.descendant(of: list, matching: find.byType(Scrollable)),
              )
              .position;
          Finder lastContent() => statistics
              ? find.byKey(ValueKey(DateTime(2026, 10, 11)))
              : find.byWidget(
                  (tester.widget<ListView>(list).childrenDelegate
                          as SliverChildListDelegate)
                      .children
                      .last,
                );

          Future<void> checkEnd(
            double viewportBottom,
            double safeBottom,
          ) async {
            expect(tester.getRect(list).top, 47);
            expect(tester.getRect(list).bottom, viewportBottom);
            expect(position.maxScrollExtent, greaterThan(0));
            await tester.drag(list, const Offset(0, -3000));
            await tester.pumpAndSettle();
            expect(position.pixels, closeTo(position.maxScrollExtent, .01));
            // Statistics day cards already have a 10-point bottom margin.
            expect(
              tester.getRect(lastContent()).bottom,
              closeTo(
                viewportBottom - safeBottom - 28 - (statistics ? 10 : 0),
                .01,
              ),
            );
            expect(lastContent().hitTestable(), findsOneWidget);
            expect(tester.takeException(), isNull);
          }

          await checkEnd(480, bottomInset);
          tester.view.viewInsets = const FakeViewPadding(bottom: 200);
          tester.view.padding = const FakeViewPadding(top: 47);
          await tester.pumpAndSettle();
          await checkEnd(280, 0);
          tester.view.viewInsets = FakeViewPadding.zero;
          tester.view.padding = FakeViewPadding(top: 47, bottom: bottomInset);
          await tester.pumpAndSettle();
          await checkEnd(480, bottomInset);
        },
      );
    }
  }
}
