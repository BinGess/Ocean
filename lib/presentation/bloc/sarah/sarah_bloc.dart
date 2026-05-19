import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/sarah_letter.dart';
import '../../../domain/usecases/ensure_welcome_letter_usecase.dart';
import '../../../domain/usecases/get_sarah_letters_usecase.dart';
import '../../../domain/usecases/mark_sarah_letter_read_usecase.dart';
import '../../../domain/usecases/request_sarah_weekly_letter_usecase.dart';
import 'sarah_event.dart';
import 'sarah_state.dart';

typedef MigrateLegacyInsightsRunner = Future<List<SarahLetter>> Function();
typedef RefreshLegacyInsightsRunner = Future<void> Function();
typedef SarahNowProvider = DateTime Function();

class SarahBloc extends Bloc<SarahEvent, SarahState> {
  SarahBloc({
    required this.getLettersUseCase,
    required this.ensureWelcomeLetterUseCase,
    required this.refreshLegacyInsightsUseCase,
    required this.migrateLegacyInsightsUseCase,
    required this.requestWeeklyLetterUseCase,
    required this.markReadUseCase,
    SarahNowProvider? now,
  })  : now = now ?? DateTime.now,
        super(SarahState.initial()) {
    on<SarahLoadRequested>(_onLoadRequested);
    on<SarahLetterRead>(_onLetterRead);
  }

  final GetSarahLettersUseCase getLettersUseCase;
  final EnsureWelcomeLetterUseCase ensureWelcomeLetterUseCase;
  final RefreshLegacyInsightsRunner refreshLegacyInsightsUseCase;
  final MigrateLegacyInsightsRunner migrateLegacyInsightsUseCase;
  final RequestSarahWeeklyLetterUseCase requestWeeklyLetterUseCase;
  final MarkSarahLetterReadUseCase markReadUseCase;
  final SarahNowProvider now;

  Future<void> _onLoadRequested(
    SarahLoadRequested event,
    Emitter<SarahState> emit,
  ) async {
    emit(state.copyWith(status: SarahStatus.loading));

    final errors = <Object>[];
    await _tryRun(getLettersUseCase.call, errors);
    await _tryRun(refreshLegacyInsightsUseCase, errors);
    await _tryRun(ensureWelcomeLetterUseCase.call, errors);
    await _tryRun(migrateLegacyInsightsUseCase, errors);
    await _tryRun(_requestWeeklyLetterIfUseful, errors);

    final letters =
        await _tryRun(getLettersUseCase.call, errors) ?? state.letters;
    emit(state.copyWith(
      status: SarahStatus.success,
      letters: _sorted(letters),
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

  Future<void> _requestWeeklyLetterIfUseful() async {
    final current = now();
    final weekStart = DateTime(
      current.year,
      current.month,
      current.day,
    ).subtract(Duration(days: current.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));

    await requestWeeklyLetterUseCase(
      weekStart: weekStart,
      weekEnd: weekEnd,
    );
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
