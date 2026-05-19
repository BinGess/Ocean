import 'package:equatable/equatable.dart';

import '../../../domain/entities/sarah_letter.dart';

enum SarahStatus {
  initial,
  loading,
  success,
  error,
}

class SarahState extends Equatable {
  const SarahState({
    required this.status,
    required this.letters,
    this.errorMessage,
  });

  factory SarahState.initial() {
    return const SarahState(
      status: SarahStatus.initial,
      letters: [],
    );
  }

  final SarahStatus status;
  final List<SarahLetter> letters;
  final String? errorMessage;

  SarahLetter? get weeklyLetter {
    return letters
        .where((letter) => letter.type == LetterType.weekly)
        .firstOrNull;
  }

  List<SarahLetter> get pastLetters {
    final currentWeeklyId = weeklyLetter?.id;
    return letters.where((letter) => letter.id != currentWeeklyId).toList();
  }

  int get totalCount => letters.length;

  int get unreadCount => letters.where((letter) => !letter.isRead).length;

  SarahState copyWith({
    SarahStatus? status,
    List<SarahLetter>? letters,
    String? errorMessage,
  }) {
    return SarahState(
      status: status ?? this.status,
      letters: letters ?? this.letters,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, letters, errorMessage];
}
