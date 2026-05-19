import '../entities/sarah_letter.dart';
import '../repositories/sarah_letter_repository.dart';

class RequestSarahWeeklyLetterUseCase {
  const RequestSarahWeeklyLetterUseCase({
    required this.repository,
  });

  final SarahLetterRepository repository;

  Future<SarahLetter?> call({
    required DateTime weekStart,
    required DateTime weekEnd,
  }) {
    return repository.requestWeeklyGeneration(
      weekStart: weekStart,
      weekEnd: weekEnd,
    );
  }
}
