import 'dart:ui' as ui;

import 'package:baqi/core/status_bar_fade.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final topInset in [0.0, 24.0, 59.0]) {
    testWidgets('status bar fades only its $topInset safe inset', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 600);
      tester.view.padding = FakeViewPadding(top: topInset);
      tester.view.viewPadding = FakeViewPadding(top: topInset);
      addTearDown(tester.view.reset);
      const previewKey = ValueKey('preview');
      const headerKey = ValueKey('header');
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(scaffoldBackgroundColor: Colors.black),
          home: RepaintBoundary(
            key: previewKey,
            child: Scaffold(
              body: StatusBarFade(
                child: ListView(
                  controller: controller,
                  padding: EdgeInsets.only(top: topInset + 12),
                  children: const [
                    ColoredBox(
                      key: headerKey,
                      color: Color(0xFFFF0000),
                      child: SizedBox(height: 120),
                    ),
                    SizedBox(height: 900),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(previewKey),
      );

      Future<List<int>> redSamples(List<int> rows) async {
        return tester
            .runAsync(() async {
              final image = await boundary.toImage();
              try {
                final bytes = (await image.toByteData(
                  format: ui.ImageByteFormat.rawRgba,
                ))!;
                return [
                  for (final y in rows) bytes.getUint8((y * 390 + 100) * 4),
                ];
              } finally {
                image.dispose();
              }
            })
            .then((value) => value!);
      }

      // The header starts fully below the overlay and retains its original color.
      expect(tester.getRect(find.byKey(headerKey)).top, topInset + 12);
      expect(await redSamples([(topInset + 20).toInt()]), [255]);
      controller.jumpTo(topInset + 12);
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byKey(headerKey)).top, 0);
      if (topInset > 0) {
        final samples = await redSamples([
          0,
          (topInset * .5).toInt(),
          (topInset * .8).toInt(),
          topInset.toInt() + 1,
        ]);
        expect(samples.first, 0);
        expect(samples[1], inExclusiveRange(0, samples[2]));
        expect(samples[2], lessThan(255));
        expect(samples.last, 255);
        // Gestures starting over the fade still reach the scroll view.
        final before = controller.offset;
        await tester.dragFrom(const Offset(100, 20), const Offset(0, -60));
        await tester.pumpAndSettle();
        expect(controller.offset, greaterThan(before));
      } else {
        expect(await redSamples([0, 20]), [255, 255]);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
