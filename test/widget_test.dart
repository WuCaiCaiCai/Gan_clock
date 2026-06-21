import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tomato_clock/app_controller.dart';
import 'package:tomato_clock/completion_feedback.dart';
import 'package:tomato_clock/heatmap.dart';
import 'package:tomato_clock/main.dart';
import 'package:tomato_clock/models.dart';
import 'package:tomato_clock/pages/settings_page.dart';
import 'package:tomato_clock/storage.dart';
import 'package:tomato_clock/widgets/timer_ring.dart';

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

    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).title, '苷');
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
    expect(find.byIcon(Icons.picture_in_picture_alt), findsOneWidget);

    final stopButton = find.widgetWithText(OutlinedButton, '停止');
    await tester.ensureVisible(stopButton);
    await tester.tap(stopButton);
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.text('开始'), findsOneWidget);
    expect(find.text('25:00'), findsOneWidget);

    await tester.tap(find.text('统计'));
    await tester.pumpAndSettle();
    expect(find.text('专注热力图'), findsOneWidget);
    expect(find.text('今日番茄'), findsNothing);

    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    expect(find.text('计时设置'), findsOneWidget);
    expect(find.text('外观'), findsOneWidget);
    expect(find.text('切换提醒'), findsOneWidget);
    expect(find.text('WebDAV 同步'), findsNothing);

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
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    await tester.tap(find.text('切换提醒'));
    await tester.pumpAndSettle();
    expect(find.text('切换震动'), findsOneWidget);
    expect(find.text('切换音效'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('计时设置'), findsOneWidget);
    expect(find.text('切换震动'), findsNothing);

    await tester.tap(find.text('同步'));
    await tester.pumpAndSettle();
    expect(find.text('本地同步'), findsOneWidget);
    expect(find.text('同步目录'), findsOneWidget);
    expect(find.text('立即同步'), findsOneWidget);
    expect(find.text('自动同步'), findsOneWidget);
    expect(find.text('WebDAV 设置'), findsOneWidget);
    expect(find.text('WebDAV'), findsNothing);

    await tester.tap(find.text('WebDAV 设置'));
    await tester.pumpAndSettle();
    expect(find.text('WebDAV 同步'), findsOneWidget);
    expect(find.text('服务地址'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('同步'), findsWidgets);
    expect(find.text('本地同步'), findsOneWidget);
    expect(find.text('服务地址'), findsNothing);

    controller.dispose();
  });

  testWidgets('number stepper accepts integer input', (
    WidgetTester tester,
  ) async {
    final controller = AppController(
      storage: MemoryStore(TomatoData.initial()),
      completionFeedback: const NoopCompletionFeedback(),
    );
    addTearDown(controller.dispose);

    var minutes = 25;
    await tester.pumpWidget(
      AppScope(
        controller: controller,
        child: MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return NumberStepper(
                  icon: Icons.timer_outlined,
                  label: '专注时长',
                  value: minutes,
                  min: 1,
                  max: 240,
                  suffix: '分钟',
                  onChanged: (value) => setState(() => minutes = value),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), '37');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(minutes, 37);

    var rounds = 4;
    await tester.pumpWidget(
      AppScope(
        controller: controller,
        child: MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return NumberStepper(
                  icon: Icons.repeat,
                  label: '长休间隔',
                  value: rounds,
                  min: 1,
                  max: 12,
                  suffix: '轮',
                  onChanged: (value) => setState(() => rounds = value),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), '8');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(rounds, 8);
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

    expect(find.byType(TimerProgressRing), findsOneWidget);
    expect(hasIgnoringAncestor(tester, find.text('停止')), isTrue);
    expect(hasIgnoringAncestor(tester, find.text('统计')), isTrue);

    await tester.tap(find.byType(TimerProgressRing));
    await tester.pump();

    expect(hasIgnoringAncestor(tester, find.text('停止')), isFalse);
    expect(hasIgnoringAncestor(tester, find.text('统计')), isFalse);

    controller.dispose();
  });

  testWidgets('pip timer uses square progress ring', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 240,
            height: 180,
            child: PipTimerBox(
              snapshot: const TimerSnapshot(
                mode: TimerMode.focus,
                phase: TimerPhase.running,
                totalSeconds: 1500,
                remainingSeconds: 1470,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('24:30'), findsOneWidget);
    expect(find.byType(TimerProgressRing), findsOneWidget);
    expect(find.byIcon(Icons.lightbulb_outline), findsNothing);
    expect(find.byIcon(Icons.lightbulb), findsNothing);

    final surfaceSize = tester.getSize(
      find.byKey(const ValueKey('pip_timer_ring_surface')),
    );
    expect(surfaceSize.width, closeTo(surfaceSize.height, 0.1));
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

  testWidgets('inactive lifecycle does not switch to pip preview layout', (
    WidgetTester tester,
  ) async {
    await usePhoneSurface(tester);
    final controller = AppController(
      storage: MemoryStore(TomatoData.initial()),
      completionFeedback: const NoopCompletionFeedback(),
    );
    await tester.pumpWidget(TomatoApp(controller: controller));
    await tester.pump();

    final startButton = find.widgetWithText(FilledButton, '开始');
    await tester.ensureVisible(startButton);
    await tester.tap(startButton);
    await tester.pump(const Duration(milliseconds: 120));
    final before = tester.getSize(find.byType(TimerProgressRing)).width;

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump(const Duration(milliseconds: 80));
    final after = tester.getSize(find.byType(TimerProgressRing)).width;

    expect((after - before).abs(), lessThan(0.1));

    controller.dispose();
  });

  testWidgets('today stats show minute accumulation without unit toggle', (
    WidgetTester tester,
  ) async {
    await usePhoneSurface(tester);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final data = TomatoData(
      timer: TimerSnapshot.initial(const AppSettings()),
      settings: const AppSettings(),
      focusCycleCount: 0,
      updatedAt: now,
      sessions: [
        FocusSession(
          id: 'today',
          startedAt: today.add(const Duration(hours: 9)),
          endedAt: today.add(const Duration(hours: 9, minutes: 50)),
          focusedSeconds: 3000,
          plannedSeconds: 3000,
          completed: true,
        ),
        FocusSession(
          id: 'yesterday',
          startedAt: yesterday.add(const Duration(hours: 9)),
          endedAt: yesterday.add(const Duration(hours: 9, minutes: 30)),
          focusedSeconds: 1800,
          plannedSeconds: 1800,
          completed: true,
        ),
      ],
    );
    final controller = AppController(
      storage: MemoryStore(data),
      completionFeedback: const NoopCompletionFeedback(),
    );
    await tester.pumpWidget(TomatoApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.text('统计'));
    await tester.pumpAndSettle();

    expect(find.text('今日专注'), findsOneWidget);
    expect(find.text('总专注'), findsOneWidget);
    expect(find.text('50 分钟'), findsOneWidget);
    expect(find.text('1 小时 20 分钟'), findsAtLeastNWidgets(1));
    expect(find.text('分'), findsNothing);
    expect(find.text('时'), findsNothing);
    expect(find.text('日'), findsNothing);

    controller.dispose();
  });
}
