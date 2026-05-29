import '../entities/sarah_letter.dart';
import '../repositories/sarah_letter_repository.dart';

class GetSarahLettersUseCase {
  const GetSarahLettersUseCase({
    required this.repository,
  });

  final SarahLetterRepository repository;

  Future<List<SarahLetter>> call() {
    return repository.syncRemoteLetters();
  }
}
