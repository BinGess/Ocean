/// 更新记录用例
/// 用于更新记录的情绪、需要、NVC 分析等

import '../entities/record.dart';
import '../repositories/record_repository.dart';
import 'base_usecase.dart';

class UpdateRecordParams {
  final Record record;

  UpdateRecordParams({required this.record});
}

class UpdateRecordUseCase extends UseCase<Record, UpdateRecordParams> {
  final RecordRepository recordRepository;

  UpdateRecordUseCase({required this.recordRepository});

  @override
  Future<Record> call(UpdateRecordParams params) async {
    // 更新记录的 updatedAt 时间
    final updatedRecord = params.record.copyWith(
      updatedAt: DateTime.now(),
    );

    return await recordRepository.updateRecord(updatedRecord);
  }
}
