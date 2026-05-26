import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/sarah_letter.dart';
import '../../../domain/usecases/delete_sarah_letter_usecase.dart';
import '../../../domain/usecases/ensure_welcome_letter_usecase.dart';
import '../../../domain/usecases/get_sarah_letters_usecase.dart';
import '../../../domain/usecases/mark_sarah_letter_read_usecase.dart';
import 'sarah_event.dart';
import 'sarah_state.dart';

typedef MigrateLegacyInsightsRunner = Future<List<SarahLetter>> Function();
typedef RefreshLegacyInsightsRunner = Future<void> Function();

// 周报由服务端 cron 任务（每周日 20:00 CST）自动生成，
// 客户端只负责拉取展示，不再主动触发生成。
class SarahBloc extends Bloc<SarahEvent, SarahState> {
  SarahBloc({
    required this.getLettersUseCase,
    required this.ensureWelcomeLetterUseCase,
    required this.refreshLegacyInsightsUseCase,
    required this.migrateLegacyInsightsUseCase,
    required this.markReadUseCase,
    required this.deleteLetterUseCase,
  }) : super(SarahState.initial()) {
    on<SarahLoadRequested>(_onLoadRequested);
    on<SarahLetterRead>(_onLetterRead);
    on<SarahLetterDeleteRequested>(_onLetterDeleteRequested);
  }

  final GetSarahLettersUseCase getLettersUseCase;
  final EnsureWelcomeLetterUseCase ensureWelcomeLetterUseCase;
  final RefreshLegacyInsightsRunner refreshLegacyInsightsUseCase;
  final MigrateLegacyInsightsRunner migrateLegacyInsightsUseCase;
  final MarkSarahLetterReadUseCase markReadUseCase;
  final DeleteSarahLetterUseCase deleteLetterUseCase;

  Future<void> _onLoadRequested(
    SarahLoadRequested event,
    Emitter<SarahState> emit,
  ) async {
    // Only show the loading spinner on the very first load.
    // Subsequent visits silently refresh while keeping the cached letters visible.
    if (state.letters.isEmpty) {
      emit(state.copyWith(status: SarahStatus.loading));
    }

    final errors = <Object>[];
    // 1. 拉取服务端最新信件（包含服务端 cron 已生成的最新周报）
    final initialLetters =
        await _tryRun(getLettersUseCase.call, errors) ?? state.letters;
    // 2. 刷新旧版洞察数据（历史兼容）
    await _tryRun(refreshLegacyInsightsUseCase, errors);
    // 3. 确保欢迎信存在（仅首次，本地已有则跳过）
    final welcomeLetter =
        await _tryRun(ensureWelcomeLetterUseCase.call, errors);
    // 4. 迁移旧版洞察为 Sarah 信件（历史兼容）
    final migratedLetters =
        await _tryRun(migrateLegacyInsightsUseCase, errors) ?? const [];
    // 5. 再次拉取，合并本步骤中可能新增的欢迎信/迁移信
    final letters =
        await _tryRun(getLettersUseCase.call, errors) ?? initialLetters;
    emit(state.copyWith(
      status: SarahStatus.success,
      letters: _mergeLetters(
        letters,
        [
          if (welcomeLetter != null) welcomeLetter,
          ...migratedLetters,
        ],
      ),
      errorMessage: errors.isEmpty ? null : errors.first.toString(),
    ));
  }

  Future<void> _onLetterRead(
    SarahLetterRead event,
    Emitter<SarahState> emit,
  ) async {
    await markReadUseCase(event.letterId);
    final letters = await getLettersUseCase();
    emit(state.copyWith(
      status: SarahStatus.success,
      letters: _sorted(letters),
    ));
  }

  Future<void> _onLetterDeleteRequested(
    SarahLetterDeleteRequested event,
    Emitter<SarahState> emit,
  ) async {
    // Optimistic removal — UI reflects the change immediately
    final updated =
        state.letters.where((l) => l.id != event.letterId).toList();
    emit(state.copyWith(status: SarahStatus.success, letters: updated));

    // Persist: local is synchronous, remote is best-effort
    await _tryRun(() => deleteLetterUseCase(event.letterId), []);
  }

  List<SarahLetter> _mergeLetters(
    List<SarahLetter> primary,
    List<SarahLetter> fallback,
  ) {
    final mergedById = <String, SarahLetter>{
      for (final letter in primary) letter.id: letter,
      for (final letter in fallback) letter.id: letter,
    };
    return _sorted(mergedById.values.toList());
  }

  List<SarahLetter> _sorted(List<SarahLetter> letters) {
    return [...letters]..sort(SarahLetter.newestFirst);
  }

  Future<T?> _tryRun<T>(
    Future<T> Function() action,
    List<Object> errors,
  ) async {
    try {
      return await action();
    } catch (error) {
      errors.add(error);
      return null;
    }
  }
}
