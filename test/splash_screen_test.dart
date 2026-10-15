import 'package:baqi/features/tasks/domain/task.dart';
import 'package:baqi/features/tasks/domain/task_controller.dart';
import 'package:baqi/features/tasks/domain/task_repository.dart';
import 'package:baqi/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _EmptyRepository extends TaskRepository {
  @override
  Future<List<Task>> getTasks() async => [];

  @override
  Future<void> upsertTask(Task task) async {}

  @override
  Future<void> close() async {}
}

void main() {
  testWidgets('splash shows the brand copy before opening the home screen', (
    tester,
  ) async {
    final controller = TaskController(_EmptyRepository());
    await controller.load();
    await tester.pumpWidget(BaqiApp(controller: controller));

    expect(find.text('خلّيك'), findsOneWidget);
    expect(find.text('سجّل مهامك بسرعة، وأنجزها ببساطة.'), findsOneWidget);
    final logo = find.byWidgetPredicate(
      (widget) =>
          widget is Image &&
          widget.image is AssetImage &&
          (widget.image as AssetImage).assetName == 'assets/logo_mark.png',
    );
    expect(logo, findsOneWidget);
    expect(
      tester.getTopLeft(find.text('خلّيك')).dy,
      lessThan(tester.getTopLeft(logo).dy),
    );
    expect(
      tester.getTopLeft(logo).dy,
      lessThan(
        tester.getTopLeft(find.text('سجّل مهامك بسرعة، وأنجزها ببساطة.')).dy,
      ),
    );
    expect(find.text('أضف مهمة بسرعة ...'), findsNothing);

    await tester.pump(const Duration(milliseconds: 2700));
    expect(find.text('خلّيك'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(find.text('أضف مهمة بسرعة ...'), findsOneWidget);
    expect(find.text('خلّيك'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
