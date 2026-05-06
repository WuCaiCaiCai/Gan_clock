import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tomato_clock/app_controller.dart';
import 'package:tomato_clock/completion_feedback.dart';
import 'package:tomato_clock/main.dart';
import 'package:tomato_clock/models.dart';
import 'package:tomato_clock/storage.dart';

class MemoryStore implements TomatoStore {
  MemoryStore(this.data);

  TomatoData data;

  @override
  Future<TomatoData> load() async => data;

  @override
  Future<void> save(TomatoData data) async {
    this.data = data;
  }
}

void main() {
  testWidgets('shows tomato timer controls', (WidgetTester tester) async {
    final controller = AppController(
      storage: MemoryStore(TomatoData.initial()),
      completionFeedback: const NoopCompletionFeedback(),
    );

    await tester.pumpWidget(TomatoApp(controller: controller));
    await tester.pump();

    expect(find.text('TomatoClock'), findsOneWidget);
    expect(find.text('25:00'), findsOneWidget);
    expect(find.text('开始'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);

    await tester.scrollUntilVisible(find.text('专注热力图'), 360);
    expect(find.text('专注热力图'), findsOneWidget);

    controller.dispose();
  });
}
