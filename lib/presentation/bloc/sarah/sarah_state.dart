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

  /// 「本周来信」：weekStart 落在当前自然周（本周一 00:00 ～ 下周一 00:00）的 weekly 信件。
  ///
  /// 关键：以 weekStart（信件覆盖的周期起始）判断，而 **不是** createdAt（生成时间）。
  /// 服务端补发或迁移数据时，createdAt 可能是今天，但 weekStart 仍是上周——
  /// 这种情况下该信件应归入往期，而不是「本周来信」。
  SarahLetter? get weeklyLetter {
    final now = DateTime.now();
    // 本周一 00:00（本地时间）
    final thisMonday = DateTime(
      now.year,
      now.month,
      now.day - (now.weekday - 1), // weekday: 1=Mon … 7=Sun
    );
    final nextMonday = thisMonday.add(const Duration(days: 7));

    return letters
        .where((l) => l.type == LetterType.weekly)
        .where((l) {
          final ws = l.weekStart?.toLocal();
          if (ws == null) return false;
          // weekStart ∈ [本周一, 下周一)
          return !ws.isBefore(thisMonday) && ws.isBefore(nextMonday);
        })
        .firstOrNull; // letters 已按 createdAt DESC 排序；多条时取最新生成的
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
