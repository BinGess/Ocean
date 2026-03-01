/// 首页背景主题服务
/// 管理首页 A/B 背景方案的读取、持久化和状态通知
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/datasources/local/hive_database.dart';

/// 首页背景方案
enum HomeBackgroundScheme {
  coolBlendB('home_bg_cool_blend_b'),
  warmApricotA('home_bg_warm_apricot_a');

  final String storageValue;

  const HomeBackgroundScheme(this.storageValue);

  static HomeBackgroundScheme fromStorageValue(String? value) {
    return HomeBackgroundScheme.values.firstWhere(
      (scheme) => scheme.storageValue == value,
      orElse: () => HomeBackgroundScheme.coolBlendB,
    );
  }
}

class HomeBackgroundThemeService {
  static const String _storageKey = 'home_background_scheme';

  final HiveDatabase _hiveDatabase;
  final _schemeController = StreamController<HomeBackgroundScheme>.broadcast();

  HomeBackgroundScheme _currentScheme = HomeBackgroundScheme.coolBlendB;

  HomeBackgroundThemeService({
    required HiveDatabase hiveDatabase,
  }) : _hiveDatabase = hiveDatabase;

  Stream<HomeBackgroundScheme> get schemeStream => _schemeController.stream;

  HomeBackgroundScheme get currentScheme => _currentScheme;

  Future<void> init() async {
    try {
      final raw = _hiveDatabase.settingsBox.get(_storageKey) as String?;
      _currentScheme = HomeBackgroundScheme.fromStorageValue(raw);
    } catch (e) {
      debugPrint('HomeBackgroundThemeService: 初始化失败: $e');
      _currentScheme = HomeBackgroundScheme.coolBlendB;
    }
  }

  Future<void> setScheme(HomeBackgroundScheme scheme) async {
    if (_currentScheme == scheme) return;

    try {
      _currentScheme = scheme;
      await _hiveDatabase.settingsBox.put(_storageKey, scheme.storageValue);
      _schemeController.add(_currentScheme);
    } catch (e) {
      debugPrint('HomeBackgroundThemeService: 保存失败: $e');
    }
  }

  Future<void> setWarmApricotEnabled(bool enabled) async {
    final target = enabled
        ? HomeBackgroundScheme.warmApricotA
        : HomeBackgroundScheme.coolBlendB;
    await setScheme(target);
  }

  void dispose() {
    _schemeController.close();
  }
}
