import 'dart:ui';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';
import '../../../core/services/locale_service.dart';

// Events
abstract class LocaleEvent extends Equatable {
  const LocaleEvent();

  @override
  List<Object?> get props => [];
}

class LocaleLoad extends LocaleEvent {
  const LocaleLoad();
}

class LocaleChange extends LocaleEvent {
  final Locale? locale; // null means follow system

  const LocaleChange(this.locale);

  @override
  List<Object?> get props => [locale];
}

// State
class LocaleState extends Equatable {
  final Locale effectiveLocale;
  final Locale? savedLocale; // null means following system
  final bool isFollowingSystem;

  const LocaleState({
    required this.effectiveLocale,
    this.savedLocale,
    required this.isFollowingSystem,
  });

  factory LocaleState.initial() {
    return const LocaleState(
      effectiveLocale: Locale('zh'),
      savedLocale: null,
      isFollowingSystem: true,
    );
  }

  LocaleState copyWith({
    Locale? effectiveLocale,
    Locale? savedLocale,
    bool? isFollowingSystem,
    bool clearSavedLocale = false,
  }) {
    return LocaleState(
      effectiveLocale: effectiveLocale ?? this.effectiveLocale,
      savedLocale: clearSavedLocale ? null : (savedLocale ?? this.savedLocale),
      isFollowingSystem: isFollowingSystem ?? this.isFollowingSystem,
    );
  }

  @override
  List<Object?> get props => [effectiveLocale, savedLocale, isFollowingSystem];
}

// BLoC
@injectable
class LocaleBloc extends Bloc<LocaleEvent, LocaleState> {
  final LocaleService _localeService;

  LocaleBloc(this._localeService) : super(LocaleState.initial()) {
    on<LocaleLoad>(_onLoad);
    on<LocaleChange>(_onChange);
  }

  void _onLoad(LocaleLoad event, Emitter<LocaleState> emit) {
    final savedLocale = _localeService.getSavedLocale();
    final effectiveLocale = _localeService.getEffectiveLocale();
    final isFollowingSystem = _localeService.isFollowingSystem();

    emit(LocaleState(
      effectiveLocale: effectiveLocale,
      savedLocale: savedLocale,
      isFollowingSystem: isFollowingSystem,
    ));
  }

  Future<void> _onChange(LocaleChange event, Emitter<LocaleState> emit) async {
    await _localeService.setLocale(event.locale);

    final effectiveLocale = _localeService.getEffectiveLocale();
    final isFollowingSystem = event.locale == null;

    emit(LocaleState(
      effectiveLocale: effectiveLocale,
      savedLocale: event.locale,
      isFollowingSystem: isFollowingSystem,
    ));
  }
}
