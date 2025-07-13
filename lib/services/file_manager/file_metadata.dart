class FileMetadata {
  final String fileId;
  final String title;
  final String type;
  final String? modifiedTime;

  FileMetadata({
    required this.fileId,
    required this.title,
    required this.type,
    this.modifiedTime,
  });

  factory FileMetadata.fromJson(String fileId, Map<String, dynamic> json) {
    final fullName = json['name'] as String;
    final ext = fullName.split('.').last;
    return FileMetadata(
      fileId: fileId,
      title: fullName.replaceAll(RegExp(r'\.$ext\$'), ''),
      type: ext,
      modifiedTime: json['modifiedTime'] as String?,
    );
  }
}