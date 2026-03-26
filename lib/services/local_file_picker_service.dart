import 'package:file_selector/file_selector.dart';

class LocalFilePickerService {
  Future<XFile?> pickSingleFile() {
    return openFile(acceptedTypeGroups: const [XTypeGroup(label: 'files')]);
  }

  String inferMimeType(String fileName) {
    final extension = extensionFromFileName(fileName);
    switch (extension) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'txt':
        return 'text/plain';
      case 'html':
        return 'text/html';
      case 'csv':
        return 'text/csv';
      case 'zip':
        return 'application/zip';
      case 'json':
        return 'application/json';
      default:
        return 'application/octet-stream';
    }
  }

  String extensionFromFileName(String fileName) {
    final trimmed = fileName.trim().toLowerCase();
    final dotIndex = trimmed.lastIndexOf('.');
    if (dotIndex <= 0 || dotIndex == trimmed.length - 1) {
      return '';
    }

    return trimmed.substring(dotIndex + 1);
  }

  String titleFromFileName(String fileName) {
    final trimmed = fileName.trim();
    final dotIndex = trimmed.lastIndexOf('.');
    if (dotIndex <= 0) {
      return trimmed;
    }

    return trimmed.substring(0, dotIndex);
  }
}
