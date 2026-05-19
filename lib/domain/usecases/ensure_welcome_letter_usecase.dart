import '../entities/sarah_letter.dart';
import '../repositories/sarah_letter_repository.dart';

class EnsureWelcomeLetterUseCase {
  const EnsureWelcomeLetterUseCase({
    required this.repository,
  });

  final SarahLetterRepository repository;

  Future<SarahLetter?> call() {
    return repository.ensureWelcomeLetter();
  }
}
