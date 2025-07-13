// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'file_cache_entry.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FileCacheEntryAdapter extends TypeAdapter<FileCacheEntry> {
  @override
  final int typeId = 0;

  @override
  FileCacheEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FileCacheEntry(
      fileId: fields[0] as String,
      name: fields[1] as String,
      extension: fields[2] as String,
      modifiedDate: fields[3] as String,
      size: fields[4] as int?,
      mimeType: fields[5] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, FileCacheEntry obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.fileId)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.extension)
      ..writeByte(3)
      ..write(obj.modifiedDate)
      ..writeByte(4)
      ..write(obj.size)
      ..writeByte(5)
      ..write(obj.mimeType);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FileCacheEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
