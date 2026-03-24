/// NVC 引导页 Widget 测试
///
/// 覆盖范围：
///
///   NVCOnboardingScreen
///     ├── [★★★] 渲染 — 页面初始化时四个 NVC 维度标题可见 (静态内容)
///     ├── [★★★] 跳过 — 点击「跳过」按钮触发 onComplete
///     ├── [★★★] CTA  — 点击「现在换你来试试」触发 onComplete
///     ├── [★★★] 单次调用 — onComplete 只被调用一次（跳过+CTA 不重复）
///     └── [★★  ] 内容完整 — 示范文案出现在页面上

library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mindflow/data/datasources/local/hive_database.dart';
import 'package:mindflow/core/di/injection.dart';
import 'package:mindflow/presentation/screens/onboarding/nvc_onboarding_screen.dart';

// ── 测试用 HiveDatabase stub ───────────────────────────────────────────────────

class _FakeSettingsBox extends Fake implements Box<dynamic> {
  final Map<String, dynamic> _store = {};

  @override
  dynamic get(dynamic key, {dynamic defaultValue}) {
    return _store.containsKey(key) ? _store[key] : defaultValue;
  }

  @override
  Future<void> put(dynamic key, dynamic value) async {
    _store[key as String] = value;
  }
}

class _FakeHiveDatabase extends Fake implements HiveDatabase {
  final _FakeSettingsBox _settingsBox = _FakeSettingsBox();

  @override
  Box<dynamic> get settingsBox => _settingsBox;
}

// ── 辅助 ────────────────────────────────────────────────────────────────────────

Widget _buildTestable({required VoidCallback onComplete}) {
  return MaterialApp(
    home: NVCOnboardingScreen(onComplete: onComplete),
  );
}

void main() {
  late _FakeHiveDatabase fakeDb;

  setUp(() {
    fakeDb = _FakeHiveDatabase();
    // 注册 fake 到 getIt；若已注册则先取消注册
    if (getIt.isRegistered<HiveDatabase>()) {
      getIt.unregister<HiveDatabase>();
    }
    getIt.registerSingleton<HiveDatabase>(fakeDb);
  });

  tearDown(() {
    if (getIt.isRegistered<HiveDatabase>()) {
      getIt.unregister<HiveDatabase>();
    }
  });

  group('NVCOnboardingScreen — 渲染', () {
    testWidgets('页面包含四个 NVC 维度标题', (tester) async {
      await tester.pumpWidget(_buildTestable(onComplete: () {}));
      // pumpAndSettle 不能用于无限动画；pump(0) 后检查静态内容
      await tester.pump();

      expect(find.text('事实观察'), findsOneWidget);
      expect(find.text('我现在的感受'), findsOneWidget);
      expect(find.text('我需要'), findsOneWidget);
      expect(find.text('行动 Tips'), findsOneWidget);
    });

    testWidgets('页面包含示范原始文案（打字机动画完成后）', (tester) async {
      await tester.pumpWidget(_buildTestable(onComplete: () {}));
      // 推进时间跳过打字机延迟(300ms)+打字时长(880ms)+余量
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('今天开会被打断，很烦。'), findsOneWidget);
    });

    testWidgets('页面包含「跳过」按钮', (tester) async {
      await tester.pumpWidget(_buildTestable(onComplete: () {}));
      await tester.pump();

      expect(find.text('跳过'), findsOneWidget);
    });

    testWidgets('页面包含 CTA 按钮文案', (tester) async {
      await tester.pumpWidget(_buildTestable(onComplete: () {}));
      await tester.pump();

      expect(find.text('现在换你来试试'), findsOneWidget);
    });
  });

  group('NVCOnboardingScreen — 交互', () {
    testWidgets('点击「跳过」调用 onComplete', (tester) async {
      int callCount = 0;
      await tester.pumpWidget(
          _buildTestable(onComplete: () => callCount++));
      await tester.pump();

      await tester.tap(find.text('跳过'));
      await tester.pump();

      expect(callCount, 1);
    });

    testWidgets('点击 CTA 调用 onComplete', (tester) async {
      int callCount = 0;
      await tester.pumpWidget(
          _buildTestable(onComplete: () => callCount++));
      await tester.pump();

      await tester.tap(find.text('现在换你来试试'));
      await tester.pump();

      expect(callCount, 1);
    });

    testWidgets('onComplete 只被调用一次（防止重复触发）', (tester) async {
      int callCount = 0;
      await tester.pumpWidget(
          _buildTestable(onComplete: () => callCount++));
      await tester.pump();

      // 连续点击跳过两次
      await tester.tap(find.text('跳过'));
      await tester.pump();
      await tester.tap(find.text('跳过'));
      await tester.pump();

      expect(callCount, 1,
          reason: '_completed flag 应阻止第二次调用');
    });

    testWidgets('点击跳过后写入 onboarding_completed = true',
        (tester) async {
      await tester.pumpWidget(_buildTestable(onComplete: () {}));
      await tester.pump();

      await tester.tap(find.text('跳过'));
      // pump 两次：第一次处理 tap，第二次处理 _complete 内的 async microtask
      await tester.pump();
      await tester.pump();

      expect(
        fakeDb.settingsBox.get('onboarding_completed', defaultValue: false),
        isTrue,
      );
    });
  });
}
