enum LetterType {
  weekly,
  welcome,
  legacy;

  String get value => name;

  static LetterType fromValue(String value) {
    final normalized = value.trim();
    return LetterType.values.firstWhere(
      (type) => type.value == normalized,
      orElse: () => LetterType.weekly,
    );
  }
}

class SarahLetter {
  const SarahLetter({
    required this.id,
    required this.type,
    required this.createdAt,
    this.weekStart,
    this.weekEnd,
    required this.content,
    this.previewText,
    required this.illustrationIndex,
    required this.isRead,
    this.updatedAt,
    this.userId,
    this.accountId,
    this.sourceLegacyReportId,
    this.deletedAt,
  });

  static const int illustrationCount = 20;
  static const String illustrationAssetDirectory = 'assets/images/sarah';

  final String id;
  final LetterType type;
  final DateTime createdAt;
  final DateTime? weekStart;
  final DateTime? weekEnd;
  final String content;
  final String? previewText;
  final int illustrationIndex;
  final bool isRead;
  final DateTime? updatedAt;
  final String? userId;
  final String? accountId;
  final String? sourceLegacyReportId;
  final DateTime? deletedAt;

  String get resolvedPreviewText {
    final explicit = previewText?.trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;

    for (final line in content.split(RegExp(r'\r?\n'))) {
      final normalized = line.trim();
      if (normalized.isEmpty) continue;
      if (normalized == '嗨，' || normalized == '嗨,') continue;
      if (normalized == 'Sarah') continue;
      return normalized;
    }
    return content.trim();
  }

  int get normalizedIllustrationIndex {
    if (illustrationIndex < 1) return 1;
    final zeroBased = (illustrationIndex - 1) % illustrationCount;
    return zeroBased + 1;
  }

  String get illustrationAssetPath {
    final index = normalizedIllustrationIndex.toString().padLeft(2, '0');
    return '$illustrationAssetDirectory/sarah_$index.png';
  }

  SarahLetter copyWith({
    String? id,
    LetterType? type,
    DateTime? createdAt,
    DateTime? weekStart,
    DateTime? weekEnd,
    String? content,
    String? previewText,
    int? illustrationIndex,
    bool? isRead,
    DateTime? updatedAt,
    String? userId,
    String? accountId,
    String? sourceLegacyReportId,
    DateTime? deletedAt,
  }) {
    return SarahLetter(
      id: id ?? this.id,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      weekStart: weekStart ?? this.weekStart,
      weekEnd: weekEnd ?? this.weekEnd,
      content: content ?? this.content,
      previewText: previewText ?? this.previewText,
      illustrationIndex: illustrationIndex ?? this.illustrationIndex,
      isRead: isRead ?? this.isRead,
      updatedAt: updatedAt ?? this.updatedAt,
      userId: userId ?? this.userId,
      accountId: accountId ?? this.accountId,
      sourceLegacyReportId: sourceLegacyReportId ?? this.sourceLegacyReportId,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.value,
      'createdAt': createdAt.toIso8601String(),
      if (weekStart != null) 'weekStart': weekStart!.toIso8601String(),
      if (weekEnd != null) 'weekEnd': weekEnd!.toIso8601String(),
      'content': content,
      if (previewText != null) 'previewText': previewText,
      'illustrationIndex': illustrationIndex,
      'isRead': isRead,
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      if (userId != null) 'userId': userId,
      if (accountId != null) 'accountId': accountId,
      if (sourceLegacyReportId != null)
        'sourceLegacyReportId': sourceLegacyReportId,
      if (deletedAt != null) 'deletedAt': deletedAt!.toIso8601String(),
    };
  }

  factory SarahLetter.fromJson(Map<String, dynamic> json) {
    return SarahLetter(
      id: json['id']?.toString() ?? '',
      type: LetterType.fromValue(
        _readString(json, const ['type', 'letterType', 'letter_type']) ?? '',
      ),
      createdAt: _parseDate(
            _read(json, const ['createdAt', 'created_at']),
          ) ??
          DateTime.now(),
      weekStart: _parseDate(_read(json, const ['weekStart', 'week_start'])),
      weekEnd: _parseDate(_read(json, const ['weekEnd', 'week_end'])),
      content: json['content']?.toString() ?? '',
      previewText: _readString(json, const ['previewText', 'preview_text']),
      illustrationIndex: int.tryParse(
              _read(json, const ['illustrationIndex', 'illustration_index'])
                      ?.toString() ??
                  '') ??
          1,
      isRead: _readBool(json, const ['isRead', 'is_read']),
      updatedAt: _parseDate(_read(json, const ['updatedAt', 'updated_at'])),
      userId: _readString(json, const ['userId', 'user_id']),
      accountId: _readString(json, const ['accountId', 'account_id']),
      sourceLegacyReportId: _readString(
        json,
        const ['sourceLegacyReportId', 'source_legacy_report_id'],
      ),
      deletedAt: _parseDate(_read(json, const ['deletedAt', 'deleted_at'])),
    );
  }

  static int newestFirst(SarahLetter a, SarahLetter b) {
    return b.createdAt.compareTo(a.createdAt);
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is DateTime) return value;
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  static dynamic _read(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      if (json.containsKey(key)) return json[key];
    }
    return null;
  }

  static String? _readString(Map<String, dynamic> json, List<String> keys) {
    final value = _read(json, keys);
    return value?.toString();
  }

  static bool _readBool(Map<String, dynamic> json, List<String> keys) {
    final value = _read(json, keys);
    if (value is bool) return value;
    return value?.toString().toLowerCase() == 'true';
  }
}
