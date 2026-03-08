import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import '../../../domain/entities/record.dart';
import '../../../domain/usecases/create_quick_note_usecase.dart';
import '../../../domain/usecases/get_records_usecase.dart';
import '../../../domain/usecases/update_record_usecase.dart';
import '../../../domain/repositories/record_repository.dart';
import '../../../domain/repositories/ai_repository.dart';
import '../../../core/services/ai_auth_service.dart';
import '../../../core/services/daily_summary_service.dart';
import 'record_event.dart';
import 'record_state.dart';

class RecordBloc extends Bloc<RecordEvent, RecordState> {
  final CreateQuickNoteUseCase createQuickNoteUseCase;
  final GetRecordsUseCase getRecordsUseCase;
  final UpdateRecordUseCase updateRecordUseCase;
  final RecordRepository recordRepository;
  final AIRepository aiRepository;
  final AIAuthService aiAuthService;
  final DailySummaryService dailySummaryService;

  RecordBloc({
    required this.createQuickNoteUseCase,
    required this.getRecordsUseCase,
    required this.updateRecordUseCase,
    required this.recordRepository,
    required this.aiRepository,
    required this.aiAuthService,
    required this.dailySummaryService,
  }) : super(RecordState.initial()) {
    // 注册事件处理器
    on<RecordCreateQuickNote>(_onCreateQuickNote);
    on<RecordLoadList>(_onLoadList);
    on<RecordUpdate>(_onUpdate);
    on<RecordDelete>(_onDelete);
    on<RecordSelect>(_onSelect);
    on<RecordClearSelection>(_onClearSelection);
    on<RecordChangeProcessingMode>(_onChangeProcessingMode);

    // 使用 concurrent 转换器，允许转写和分析/创建并行执行
    // 这对于防止长时间运行的转写阻塞其他操作至关重要
    on<RecordTranscribe>(_onTranscribe, transformer: concurrent());
    on<RecordAnalyzeNVC>(_onAnalyzeNVC, transformer: concurrent());
  }

  /// 分析 NVC
  Future<void> _onAnalyzeNVC(
    RecordAnalyzeNVC event,
    Emitter<RecordState> emit,
  ) async {
    // 1. 首先检查AI授权
    final isAuthorized = await aiAuthService.isAuthorized;
    if (!isAuthorized) {
      debugPrint('RecordBloc: 需要AI授权');
      emit(state.copyWith(
        status: RecordStatus.needsAIAuth,
        transcription: event.text,
        clearError: true,
        clearTranscriptionError: true,
      ));
      return; // 等待UI层处理授权
    }

    // 2. 已授权，继续原有逻辑
    debugPrint('RecordBloc: 开始NVC分析，文本: ${event.text}');
    // 更新状态为 analyzing，并同时更新 transcription，确保 UI 显示的是用于分析的文本
    // 同时清除之前的错误状态，避免错误弹窗误触发
    emit(state.copyWith(
      status: RecordStatus.analyzing,
      clearNVCAnalysis: true,
      clearError: true,
      clearTranscriptionError: true,
      transcription: event.text, // 确保 transcription 与分析内容一致
    ));

    try {
      final nvc = await aiRepository.analyzeWithNVC(event.text);
      debugPrint('RecordBloc: NVC分析完成');
      debugPrint('RecordBloc: 观察: ${nvc.observation}');
      debugPrint('RecordBloc: 感受: ${nvc.feelings}');
      debugPrint('RecordBloc: 需要: ${nvc.needs}');
      debugPrint('RecordBloc: 请求: ${nvc.request}');
      debugPrint('RecordBloc: AI洞察: ${nvc.insight}');
      emit(state.copyWith(
        status: RecordStatus.analyzed,
        nvcAnalysis: nvc,
      ));
    } catch (e) {
      debugPrint('RecordBloc: NVC分析失败: $e');
      emit(state.copyWith(
        status: RecordStatus.error,
        errorMessage: '分析失败: $e',
        clearTranscriptionError: true,
      ));
    }
  }

  /// 转写音频
  Future<void> _onTranscribe(
    RecordTranscribe event,
    Emitter<RecordState> emit,
  ) async {
    debugPrint('RecordBloc: Starting transcription for: ${event.audioPath}');
    // 转写属于局部流程，不再污染全局 error 状态。
    emit(state.copyWith(
      transcription: '正在转写中...',
      clearError: true,
      clearTranscriptionError: true,
    ));

    try {
      final transcription =
          await aiRepository.transcribeAudioFile(event.audioPath);
      debugPrint('RecordBloc: Transcription completed: $transcription');
      // 转写成功，只更新 transcription
      emit(state.copyWith(
        transcription: transcription,
        clearError: true,
        clearTranscriptionError: true,
      ));
      debugPrint('RecordBloc: State updated with transcription');
    } catch (e) {
      debugPrint('RecordBloc: Transcription failed: $e');
      // 转写失败只记录在局部字段中，避免其他页面将其当成全局错误。
      emit(state.copyWith(
        clearTranscription: true,
        clearError: true,
        transcriptionErrorMessage: '转写失败，请重试',
      ));
    }
  }

  /// 创建快速笔记
  Future<void> _onCreateQuickNote(
    RecordCreateQuickNote event,
    Emitter<RecordState> emit,
  ) async {
    debugPrint('RecordBloc: Creating quick note...');
    emit(state.copyWith(
      status: RecordStatus.creating,
      clearError: true,
      clearTranscriptionError: true,
    ));

    try {
      // 转写阶段
      // 注意：如果已经有 transcription，这里不会触发真正的转写
      // 如果正在转写中，createQuickNoteUseCase 会直接使用传入的 transcription

      // 分析阶段（如果需要）
      if (event.mode == ProcessingMode.withNVC) {
        // NVC 分析通常在 _onAnalyzeNVC 中完成，这里只是保存结果
        // 如果是直接传入 nvcAnalysis，则不需要再次分析
      }

      debugPrint('RecordBloc: Calling createQuickNoteUseCase...');
      // 创建记录
      final record = await createQuickNoteUseCase(
        CreateQuickNoteParams(
          audioPath: event.audioPath,
          mode: event.mode,
          selectedMoods: event.selectedMoods,
          transcription: event.transcription,
          nvcAnalysis: event.nvcAnalysis,
        ),
      ).timeout(const Duration(seconds: 10), onTimeout: () {
        throw Exception('创建记录超时');
      });

      debugPrint('RecordBloc: Quick note created: ${record.id}');

      // 将新记录添加到列表开头
      final updatedRecords = [record, ...state.records];

      emit(state.copyWith(
        status: RecordStatus.success,
        records: updatedRecords,
        latestRecord: record,
        clearTranscriptionError: true,
      ));

      unawaited(_refreshDailySummaryAfterSave(record.createdAt));
    } catch (e) {
      debugPrint('RecordBloc: Create quick note failed: $e');
      emit(state.copyWith(
        status: RecordStatus.error,
        errorMessage: '创建记录失败: $e',
        clearTranscriptionError: true,
      ));
    }
  }

  Future<void> _refreshDailySummaryAfterSave(DateTime date) async {
    try {
      final dayRecords = await recordRepository.getRecordsByDate(date);
      if (!dailySummaryService.needsRegeneration(date, dayRecords.length)) {
        return;
      }

      debugPrint(
        'RecordBloc: Auto refresh daily summary for $date, records: ${dayRecords.length}',
      );
      await dailySummaryService.generateDailySummary(date, dayRecords);
    } catch (e) {
      debugPrint('RecordBloc: Auto refresh daily summary failed: $e');
    }
  }

  /// 加载记录列表
  Future<void> _onLoadList(
    RecordLoadList event,
    Emitter<RecordState> emit,
  ) async {
    emit(state.copyWith(
      status: RecordStatus.loading,
      clearError: true,
      clearTranscriptionError: true,
    ));

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
        clearLatest: true,
        clearTranscriptionError: true,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: RecordStatus.error,
        errorMessage: '加载记录失败: $e',
        clearTranscriptionError: true,
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
        clearTranscriptionError: true,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: RecordStatus.error,
        errorMessage: '更新记录失败: $e',
        clearTranscriptionError: true,
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
        clearLatest: true,
        clearTranscriptionError: true,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: RecordStatus.error,
        errorMessage: '删除记录失败: $e',
        clearTranscriptionError: true,
      ));
    }
  }

  /// 选择记录
  void _onSelect(
    RecordSelect event,
    Emitter<RecordState> emit,
  ) {
    emit(state.copyWith(
      selectedRecord: event.record,
      clearTranscriptionError: true,
    ));
  }

  /// 清除选择
  void _onClearSelection(
    RecordClearSelection event,
    Emitter<RecordState> emit,
  ) {
    emit(state.copyWith(
      clearSelection: true,
      clearTranscriptionError: true,
    ));
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
