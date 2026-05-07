import '../../domain/entities/record.dart';

class OceanRecordSyncMapper {
  const OceanRecordSyncMapper._();

  static Map<String, dynamic> toServerRecord(Record record) {
    return {
      'id': record.id,
      'type': _recordTypeToApi(record.type),
      'transcription': record.transcription,
      'createdAt': record.createdAt.toUtc().toIso8601String(),
      'updatedAt': record.updatedAt.toUtc().toIso8601String(),
      'audioUrl': null,
      'duration': record.duration,
      'processingMode': record.processingMode != null
          ? _processingModeToApi(record.processingMode!)
          : null,
      'moods': record.moods,
      'needs': record.needs,
      'nvc': record.nvc?.toJson(),
      'title': record.title,
      'summary': record.summary,
      'date': record.date,
      'referencedFragments': record.referencedFragments,
      'weekRange': record.weekRange,
      'referencedRecords': record.referencedRecords,
      'patternFeedback': record.patternFeedback,
    };
  }

  static Record fromServerRecord(Map<String, dynamic> json) {
    final normalized = Map<String, dynamic>.from(json);
    if (normalized.containsKey('patternFeedback')) {
      normalized['pattern_feedback'] = normalized['patternFeedback'];
    }
    normalized['audioUrl'] = null;
    return Record.fromJson(normalized);
  }

  static String _recordTypeToApi(RecordType type) {
    switch (type) {
      case RecordType.quickNote:
        return 'quick_note';
      case RecordType.journal:
        return 'journal';
      case RecordType.weekly:
        return 'weekly';
    }
  }

  static String _processingModeToApi(ProcessingMode mode) {
    switch (mode) {
      case ProcessingMode.onlyRecord:
        return 'only_record';
      case ProcessingMode.withMood:
        return 'with_mood';
      case ProcessingMode.withNVC:
        return 'with_nvc';
    }
  }
}
