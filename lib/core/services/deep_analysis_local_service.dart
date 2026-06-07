import 'dart:convert';

import '../../data/datasources/local/hive_database.dart';
import '../../domain/entities/deep_analysis_result.dart';

class DeepAnalysisLocalService {
  static const _keyPrefix = 'deep_analysis_v1_';

  final HiveDatabase database;

  const DeepAnalysisLocalService({required this.database});

  List<DeepAnalysisResult> getForRecord(String recordId) {
    final raw = database.settingsBox.get('$_keyPrefix$recordId');
    if (raw is! String || raw.isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map(
              (item) => DeepAnalysisResult.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList();
      }
      // 兼容已发布到本地的单条对象格式。
      if (decoded is Map) {
        return [
          DeepAnalysisResult.fromJson(
            Map<String, dynamic>.from(decoded),
          ),
        ];
      }
      return const [];
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveForRecord(
    String recordId,
    List<DeepAnalysisResult> results,
  ) {
    return database.settingsBox.put(
      '$_keyPrefix$recordId',
      jsonEncode(results.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> deleteForRecord(String recordId) {
    return database.settingsBox.delete('$_keyPrefix$recordId');
  }
}
