import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tomato_clock/app_controller.dart';
import 'package:tomato_clock/completion_feedback.dart';
import 'package:tomato_clock/heatmap.dart';
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

Future<void> usePhoneSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(400, 900));
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
  });
}

bool hasIgnoringAncestor(WidgetTester tester, Finder finder) {
  return find
      .ancestor(of: finder, matching: find.byType(IgnorePointer))
      .evaluate()
      .map((element) => element.widget)
      .whereType<IgnorePointer>()
      .any((widget) => widget.ignoring);
}

void main() {
  const focusHitokotoLines = [
    '只处理眼前这一件事。',
    '把注意力收回来，时间会变清楚。',
    '慢一点，但不要停在原地。',
    '先完成一小段，再判断下一步。',
  ];

  testWidgets('shows tomato timer controls', (WidgetTester tester) async {
    await usePhoneSurface(tester);
    final controller = AppController(
      storage: MemoryStore(TomatoData.initial()),
      completionFeedback: const NoopCompletionFeedback(),
    );

    await tester.pumpWidget(TomatoApp(controller: controller));
    await tester.pump();

    expect(find.text('番茄钟'), findsWidgets);
    expect(find.text('25:00'), findsOneWidget);
    expect(find.text('开始'), findsOneWidget);
    expect(find.text('停止'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    expect(
      focusHitokotoLines.any((line) => find.text(line).evaluate().isNotEmpty),
      isTrue,
    );
    expect(find.text('专注热力图'), findsNothing);

    final startButton = find.widgetWithText(FilledButton, '开始');
    await tester.ensureVisible(startButton);
    await tester.tap(startButton);
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.text('暂停'), findsOneWidget);
    expect(find.byIcon(Icons.pause), findsOneWidget);
    expect(find.text('停止'), findsOneWidget);

    final stopButton = find.widgetWithText(OutlinedButton, '停止');
    await tester.ensureVisible(stopButton);
    await tester.tap(stopButton);
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.text('开始'), findsOneWidget);
    expect(find.text('25:00'), findsOneWidget);

    await tester.tap(find.text('统计'));
    await tester.pumpAndSettle();
    expect(find.text('专注热力图'), findsOneWidget);

    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    expect(find.text('计时设置'), findsOneWidget);
    expect(find.text('外观'), findsOneWidget);
    expect(find.text('切换提醒'), findsOneWidget);
    expect(find.text('WebDAV 同步'), findsOneWidget);

    await tester.tap(find.text('外观'));
    await tester.pumpAndSettle();
    expect(find.text('跟随系统'), findsWidgets);
    expect(find.text('浅色'), findsWidgets);
    expect(find.text('夜间'), findsWidgets);
    await tester.tap(find.text('夜间').last);
    await tester.pumpAndSettle();
    expect(controller.data.settings.themeMode, AppThemeMode.dark);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
    Navigator.of(tester.element(find.text('跟随系统').last)).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('切换提醒'));
    await tester.pumpAndSettle();
    expect(find.text('切换震动'), findsOneWidget);
    expect(find.text('切换音效'), findsOneWidget);

    controller.dispose();
  });

  testWidgets('hides chrome after timer page sits idle', (
    WidgetTester tester,
  ) async {
    await usePhoneSurface(tester);
    final data = TomatoData.initial().copyWith(
      settings: const AppSettings(idleFocusSeconds: 5),
    );
    final controller = AppController(
      storage: MemoryStore(data),
      completionFeedback: const NoopCompletionFeedback(),
    );

    await tester.pumpWidget(TomatoApp(controller: controller));
    await tester.pump();
    final startButton = find.widgetWithText(FilledButton, '开始');
    await tester.ensureVisible(startButton);
    await tester.tap(startButton);
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.text('停止'), findsOneWidget);
    expect(find.text('统计'), findsOneWidget);

    await tester.tapAt(const Offset(24, 240));
    await tester.pumpAndSettle();

    expect(hasIgnoringAncestor(tester, find.text('停止')), isTrue);
    expect(hasIgnoringAncestor(tester, find.text('统计')), isTrue);

    await tester.pump(const Duration(seconds: 5));
    await tester.pump();

    expect(find.byType(TimerNumberDisplay), findsOneWidget);
    expect(hasIgnoringAncestor(tester, find.text('停止')), isTrue);
    expect(hasIgnoringAncestor(tester, find.text('统计')), isTrue);

    await tester.tap(find.byType(TimerNumberDisplay));
    await tester.pump();

    expect(hasIgnoringAncestor(tester, find.text('停止')), isFalse);
    expect(hasIgnoringAncestor(tester, find.text('统计')), isFalse);

    controller.dispose();
  });

  testWidgets('heatmap selects a day and shows its focus duration', (
    WidgetTester tester,
  ) async {
    await usePhoneSurface(tester);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FocusHeatmap(
            now: DateTime(2026, 1, 2),
            focusSecondsByDay: const {'2026-01-01': 120},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('2026-01-02 · 专注 0 分钟'), findsOneWidget);

    await tester.tap(find.text('1'));
    await tester.pumpAndSettle();

    expect(find.text('2026-01-01 · 专注 2 分钟'), findsOneWidget);
  });
}
