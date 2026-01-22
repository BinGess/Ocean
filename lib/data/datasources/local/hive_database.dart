/// Hive 数据库配置
/// 管理本地数据存储

import 'package:hive_flutter/hive_flutter.dart';
import '../../models/record_model.dart';
import '../../models/weekly_insight_model.dart';

class HiveDatabase {
  // Box 名称常量
  static const String recordsBox = 'records';
  static const String weeklyInsightsBox = 'weekly_insights';
  static const String settingsBox = 'settings';

  // Box 引用
  late Box<RecordModel> _recordsBox;
  late Box<WeeklyInsightModel> _weeklyInsightsBox;
  late Box<dynamic> _settingsBox;

  /// 初始化数据库
  Future<void> init() async {
    // 初始化 Hive
    await Hive.initFlutter();

    // 注册类型适配器
    _registerAdapters();

    // 打开 Boxes
    _recordsBox = await Hive.openBox<RecordModel>(recordsBox);
    _weeklyInsightsBox =
        await Hive.openBox<WeeklyInsightModel>(weeklyInsightsBox);
    _settingsBox = await Hive.openBox(settingsBox);
  }

  /// 注册 Hive 类型适配器
  void _registerAdapters() {
    // 注册 RecordModel 适配器
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(RecordModelAdapter());
    }

    // 注册 WeeklyInsightModel 适配器
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(WeeklyInsightModelAdapter());
    }

    // 后续添加更多适配器
    // Hive.registerAdapter(NVCAnalysisModelAdapter());
  }

  /// 获取记录 Box
  Box<RecordModel> get recordsBox => _recordsBox;

  /// 获取周洞察 Box
  Box<WeeklyInsightModel> get weeklyInsightsBox => _weeklyInsightsBox;

  /// 获取设置 Box
  Box<dynamic> get settingsBox => _settingsBox;

  /// 清空所有数据（用于测试）
  Future<void> clearAll() async {
    await _recordsBox.clear();
    await _weeklyInsightsBox.clear();
    await _settingsBox.clear();
  }

  /// 关闭数据库
  Future<void> close() async {
    await _recordsBox.close();
    await _weeklyInsightsBox.close();
    await _settingsBox.close();
  }

  /// 获取数据库统计信息
  Map<String, dynamic> getStats() {
    return {
      'records_count': _recordsBox.length,
      'insights_count': _weeklyInsightsBox.length,
      'settings_count': _settingsBox.length,
    };
  }
}
