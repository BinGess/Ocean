/// 获取记录列表用例
/// 支持按类型、日期范围筛选

import '../entities/record.dart';
import '../repositories/record_repository.dart';
import 'base_usecase.dart';

class GetRecordsParams {
  final RecordType? type;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? limit;

  GetRecordsParams({
    this.type,
    this.startDate,
    this.endDate,
    this.limit,
  });
}

class GetRecordsUseCase extends UseCase<List<Record>, GetRecordsParams> {
  final RecordRepository recordRepository;

  GetRecordsUseCase({required this.recordRepository});

  @override
  Future<List<Record>> call(GetRecordsParams params) async {
    // 获取所有记录
    var records = await recordRepository.getAllRecords();

    // 按类型筛选
    if (params.type != null) {
      records = records.where((r) => r.type == params.type).toList();
    }

    // 按日期范围筛选
    if (params.startDate != null) {
      records = records
          .where((r) => r.createdAt.isAfter(params.startDate!))
          .toList();
    }

    if (params.endDate != null) {
      records = records
          .where((r) => r.createdAt.isBefore(params.endDate!))
          .toList();
    }

    // 按创建时间降序排序
    records.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // 限制数量
    if (params.limit != null && params.limit! > 0) {
      records = records.take(params.limit!).toList();
    }

    return records;
  }
}
