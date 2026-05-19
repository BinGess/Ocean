import 'package:equatable/equatable.dart';

abstract class SarahEvent extends Equatable {
  const SarahEvent();

  @override
  List<Object?> get props => [];
}

class SarahLoadRequested extends SarahEvent {
  const SarahLoadRequested();
}

class SarahLetterRead extends SarahEvent {
  const SarahLetterRead({
    required this.letterId,
  });

  final String letterId;

  @override
  List<Object?> get props => [letterId];
}
