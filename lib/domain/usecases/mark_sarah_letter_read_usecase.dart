import '../repositories/sarah_letter_repository.dart';

class MarkSarahLetterReadUseCase {
  const MarkSarahLetterReadUseCase({
    required this.repository,
  });

  final SarahLetterRepository repository;

  Future<void> call(String id) {
    return repository.markRead(id);
  }
}
