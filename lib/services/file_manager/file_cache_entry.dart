// file_cache_entry.dart (Оновлена версія)

import 'package:hive/hive.dart';

part 'file_cache_entry.g.dart';

@HiveType(typeId: 0)
class FileCacheEntry extends HiveObject {
  @HiveField(0)
  final String fileId;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String extension;

  @HiveField(3)
  final String modifiedDate;

  @HiveField(4)
  final int? size; // Розмір файлу в байтах

  @HiveField(5)
  final String? mimeType; // MIME тип файлу

  FileCacheEntry({
    required this.fileId,
    required this.name,
    required this.extension,
    required this.modifiedDate,
    this.size,
    this.mimeType,
  });

  String get filename => '$fileId.$extension';

  /// Перевіряє, чи є файл зображенням
  bool get isImage => mimeType?.startsWith('image/') ?? false;

  /// Перевіряє, чи є файл документом
  bool get isDocument => mimeType?.startsWith('application/') ?? false;

  /// Повертає людино-читабельний розмір файлу
  String get humanReadableSize {
    if (size == null) return 'Невідомий розмір';
    
    const units = ['Б', 'КБ', 'МБ', 'ГБ'];
    int unitIndex = 0;
    double fileSize = size!.toDouble();
    
    while (fileSize >= 1024 && unitIndex < units.length - 1) {
      fileSize /= 1024;
      unitIndex++;
    }
    
    return '${fileSize.toStringAsFixed(1)} ${units[unitIndex]}';
  }

  /// Повертає дату модифікації як DateTime
  DateTime? get modifiedDateTime {
    try {
      return DateTime.parse(modifiedDate);
    } catch (e) {
      return null;
    }
  }

  @override
  String toString() {
    return 'FileCacheEntry(fileId: $fileId, name: $name, extension: $extension, modifiedDate: $modifiedDate, size: $size, mimeType: $mimeType)';
  }
}