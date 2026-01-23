/// 记录 BLoC
/// 管理记录的创建、查询、更新、删除等操作

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/entities/record.dart';
import '../../../domain/usecases/create_quick_note_usecase.dart';
import '../../../domain/usecases/get_records_usecase.dart';
import '../../../domain/usecases/update_record_usecase.dart';
import '../../../domain/repositories/record_repository.dart';
import '../../../domain/repositories/ai_repository.dart';
import 'record_event.dart';
import 'record_state.dart';

class RecordBloc extends Bloc<RecordEvent, RecordState> {
  final CreateQuickNoteUseCase createQuickNoteUseCase;
  final GetRecordsUseCase getRecordsUseCase;
  final UpdateRecordUseCase updateRecordUseCase;
  final RecordRepository recordRepository;
  final AIRepository aiRepository;

  RecordBloc({
    required this.createQuickNoteUseCase,
    required this.getRecordsUseCase,
    required this.updateRecordUseCase,
    required this.recordRepository,
    required this.aiRepository,
  }) : super(RecordState.initial()) {
    // 注册事件处理器
    on<RecordCreateQuickNote>(_onCreateQuickNote);
    on<RecordLoadList>(_onLoadList);
    on<RecordUpdate>(_onUpdate);
    on<RecordDelete>(_onDelete);
    on<RecordSelect>(_onSelect);
    on<RecordClearSelection>(_onClearSelection);
    on<RecordChangeProcessingMode>(_onChangeProcessingMode);
    on<RecordTranscribe>(_onTranscribe);
  }

  /// 转写音频
  Future<void> _onTranscribe(
    RecordTranscribe event,
    Emitter<RecordState> emit,
  ) async {
    emit(state.copyWith(status: RecordStatus.transcribing, transcription: '正在转写中...'));

    try {
      final transcription = await aiRepository.transcribeAudioFile(event.audioPath);
      emit(state.copyWith(
        status: RecordStatus.success,
        transcription: transcription,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: RecordStatus.error,
        errorMessage: '转写失败: $e',
        transcription: '转写失败',
      ));
    }
  }

  /// 创建快速笔记
  Future<void> _onCreateQuickNote(
    RecordCreateQuickNote event,
    Emitter<RecordState> emit,
  ) async {
    emit(state.copyWith(status: RecordStatus.creating));

    try {
      // 转写阶段
      emit(state.copyWith(status: RecordStatus.transcribing));

      // 分析阶段（如果需要）
      if (event.mode == ProcessingMode.withNVC) {
        emit(state.copyWith(status: RecordStatus.analyzing));
      }

      // 创建记录
      final record = await createQuickNoteUseCase(
        CreateQuickNoteParams(
          audioPath: event.audioPath,
          mode: event.mode,
          selectedMoods: event.selectedMoods,
          transcription: event.transcription,
        ),
      );

      // 将新记录添加到列表开头
      final updatedRecords = [record, ...state.records];

      emit(state.copyWith(
        status: RecordStatus.success,
        records: updatedRecords,
        latestRecord: record,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: RecordStatus.error,
        errorMessage: '创建记录失败: $e',
      ));
    }
  }

  /// 加载记录列表
  Future<void> _onLoadList(
    RecordLoadList event,
    Emitter<RecordState> emit,
  ) async {
    emit(state.copyWith(status: RecordStatus.loading));

    try {
      final records = await getRecordsUseCase(
        GetRecordsParams(
          type: event.type,
          startDate: event.startDate,
          endDate: event.endDate,
          limit: event.limit,
        ),
      );

      final limit = event.limit;
      emit(state.copyWith(
        status: RecordStatus.success,
        records: records,
        hasMore: limit != null && records.length >= limit,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: RecordStatus.error,
        errorMessage: '加载记录失败: $e',
      ));
    }
  }

  /// 更新记录
  Future<void> _onUpdate(
    RecordUpdate event,
    Emitter<RecordState> emit,
  ) async {
    try {
      final updatedRecord = await updateRecordUseCase(
        UpdateRecordParams(record: event.record),
      );

      // 更新列表中的记录
      final updatedRecords = state.records.map((r) {
        return r.id == updatedRecord.id ? updatedRecord : r;
      }).toList();

      emit(state.copyWith(
        status: RecordStatus.success,
        records: updatedRecords,
        selectedRecord: state.selectedRecord?.id == updatedRecord.id
            ? updatedRecord
            : state.selectedRecord,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: RecordStatus.error,
        errorMessage: '更新记录失败: $e',
      ));
    }
  }

  /// 删除记录
  Future<void> _onDelete(
    RecordDelete event,
    Emitter<RecordState> emit,
  ) async {
    try {
      await recordRepository.deleteRecord(event.id);

      // 从列表中移除
      final updatedRecords =
          state.records.where((r) => r.id != event.id).toList();

      emit(state.copyWith(
        status: RecordStatus.success,
        records: updatedRecords,
        clearSelection: state.selectedRecord?.id == event.id,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: RecordStatus.error,
        errorMessage: '删除记录失败: $e',
      ));
    }
  }

  /// 选择记录
  void _onSelect(
    RecordSelect event,
    Emitter<RecordState> emit,
  ) {
    emit(state.copyWith(selectedRecord: event.record));
  }

  /// 清除选择
  void _onClearSelection(
    RecordClearSelection event,
    Emitter<RecordState> emit,
  ) {
    emit(state.copyWith(clearSelection: true));
  }

  /// 改变处理模式（需要重新分析）
  Future<void> _onChangeProcessingMode(
    RecordChangeProcessingMode event,
    Emitter<RecordState> emit,
  ) async {
    // TODO: 实现处理模式改变逻辑
    // 1. 找到记录
    // 2. 根据新模式重新分析
    // 3. 更新记录
  }
}
