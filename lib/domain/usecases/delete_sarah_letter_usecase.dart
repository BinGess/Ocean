import '../repositories/sarah_letter_repository.dart';

class DeleteSarahLetterUseCase {
  const DeleteSarahLetterUseCase({required this.repository});

  final SarahLetterRepository repository;

  Future<void> call(String id) => repository.deleteLetter(id);
}
