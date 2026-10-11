import 'package:baqi/features/tasks/domain/task.dart';
import 'package:baqi/features/tasks/domain/task_controller.dart';
import 'package:baqi/features/tasks/domain/task_repository.dart';
import 'package:baqi/main.dart';
import 'package:flutter_test/flutter_test.dart';

class _EmptyRepository implements TaskRepository {
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

    expect(find.text('خلّيك نَجِيز.'), findsOneWidget);
    expect(find.text('سجّل مهامك بسرعة، وأنجزها ببساطة.'), findsOneWidget);
    expect(find.text('أضف مهمة بسرعة ...'), findsNothing);

    await tester.pump(const Duration(milliseconds: 2700));
    expect(find.text('خلّيك نَجِيز.'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(find.text('أضف مهمة بسرعة ...'), findsOneWidget);
    expect(find.text('خلّيك نَجِيز.'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
