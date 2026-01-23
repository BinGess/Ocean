/// Hive 数据库配置
/// 管理本地数据存储

import 'package:hive_flutter/hive_flutter.dart';
import '../../models/record_model.dart';
import '../../models/weekly_insight_model.dart';

class HiveDatabase {
  // Box 名称常量
  static const String recordsBoxName = 'records';
  static const String weeklyInsightsBoxName = 'weekly_insights';
  static const String settingsBoxName = 'settings';

  // Box 引用
  late Box<RecordModel> recordsBox;
  late Box<WeeklyInsightModel> weeklyInsightsBox;
  late Box<dynamic> settingsBox;

  /// 初始化数据库
  Future<void> init() async {
    // 初始化 Hive
    await Hive.initFlutter();

    // 注册类型适配器
    _registerAdapters();

    // 打开 Boxes
    recordsBox = await Hive.openBox<RecordModel>(recordsBoxName);
    weeklyInsightsBox =
        await Hive.openBox<WeeklyInsightModel>(weeklyInsightsBoxName);
    settingsBox = await Hive.openBox(settingsBoxName);
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

  /// 清空所有数据（用于测试）
  Future<void> clearAll() async {
    await recordsBox.clear();
    await weeklyInsightsBox.clear();
    await settingsBox.clear();
  }

  /// 关闭数据库
  Future<void> close() async {
    await recordsBox.close();
    await weeklyInsightsBox.close();
    await settingsBox.close();
  }

  /// 获取数据库统计信息
  Map<String, dynamic> getStats() {
    return {
      'records_count': recordsBox.length,
      'insights_count': weeklyInsightsBox.length,
      'settings_count': settingsBox.length,
    };
  }
}
