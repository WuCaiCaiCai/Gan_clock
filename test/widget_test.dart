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

    expect(find.text('番茄钟'), findsWidgets);
    expect(find.text('25:00'), findsOneWidget);
    expect(find.text('开始'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    expect(find.text('专注热力图'), findsNothing);

    await tester.tap(find.text('开始'));
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.text('暂停'), findsOneWidget);
    expect(find.byIcon(Icons.pause), findsOneWidget);

    await tester.tap(find.text('统计'));
    await tester.pumpAndSettle();
    expect(find.text('专注热力图'), findsOneWidget);

    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    expect(find.text('计时设置'), findsOneWidget);
    expect(find.text('切换提醒'), findsOneWidget);
    expect(find.text('WebDAV 同步'), findsOneWidget);

    await tester.tap(find.text('切换提醒'));
    await tester.pumpAndSettle();
    expect(find.text('切换震动'), findsOneWidget);
    expect(find.text('切换音效'), findsOneWidget);

    controller.dispose();
  });
}
