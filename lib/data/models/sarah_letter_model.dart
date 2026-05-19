import 'package:hive/hive.dart';

import '../../domain/entities/sarah_letter.dart';

class SarahLetterModel extends HiveObject {
  SarahLetterModel({
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

  static const int hiveTypeId = 2;

  final String id;
  final String type;
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

  factory SarahLetterModel.fromEntity(SarahLetter entity) {
    return SarahLetterModel(
      id: entity.id,
      type: entity.type.value,
      createdAt: entity.createdAt,
      weekStart: entity.weekStart,
      weekEnd: entity.weekEnd,
      content: entity.content,
      previewText: entity.previewText,
      illustrationIndex: entity.illustrationIndex,
      isRead: entity.isRead,
      updatedAt: entity.updatedAt,
      userId: entity.userId,
      accountId: entity.accountId,
      sourceLegacyReportId: entity.sourceLegacyReportId,
      deletedAt: entity.deletedAt,
    );
  }

  SarahLetter toEntity() {
    return SarahLetter(
      id: id,
      type: LetterType.fromValue(type),
      createdAt: createdAt,
      weekStart: weekStart,
      weekEnd: weekEnd,
      content: content,
      previewText: previewText,
      illustrationIndex: illustrationIndex,
      isRead: isRead,
      updatedAt: updatedAt,
      userId: userId,
      accountId: accountId,
      sourceLegacyReportId: sourceLegacyReportId,
      deletedAt: deletedAt,
    );
  }
}

class SarahLetterModelAdapter extends TypeAdapter<SarahLetterModel> {
  @override
  final int typeId = SarahLetterModel.hiveTypeId;

  @override
  SarahLetterModel read(BinaryReader reader) {
    final fields = <int, dynamic>{};
    final count = reader.readByte();
    for (var i = 0; i < count; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return SarahLetterModel(
      id: fields[0] as String,
      type: fields[1] as String,
      createdAt: fields[2] as DateTime,
      weekStart: fields[3] as DateTime?,
      weekEnd: fields[4] as DateTime?,
      content: fields[5] as String,
      previewText: fields[6] as String?,
      illustrationIndex: fields[7] as int,
      isRead: fields[8] as bool,
      updatedAt: fields[9] as DateTime?,
      userId: fields[10] as String?,
      accountId: fields[11] as String?,
      sourceLegacyReportId: fields[12] as String?,
      deletedAt: fields[13] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, SarahLetterModel obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.type)
      ..writeByte(2)
      ..write(obj.createdAt)
      ..writeByte(3)
      ..write(obj.weekStart)
      ..writeByte(4)
      ..write(obj.weekEnd)
      ..writeByte(5)
      ..write(obj.content)
      ..writeByte(6)
      ..write(obj.previewText)
      ..writeByte(7)
      ..write(obj.illustrationIndex)
      ..writeByte(8)
      ..write(obj.isRead)
      ..writeByte(9)
      ..write(obj.updatedAt)
      ..writeByte(10)
      ..write(obj.userId)
      ..writeByte(11)
      ..write(obj.accountId)
      ..writeByte(12)
      ..write(obj.sourceLegacyReportId)
      ..writeByte(13)
      ..write(obj.deletedAt);
  }
}
