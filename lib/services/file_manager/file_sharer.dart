// file_sharer.dart

import 'dart:io' show Platform, File;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

import '../html_stub.dart'
    if (dart.library.html) 'dart:html' as html;

class FileSharer {
  Future<void> shareFile(Uint8List data, String filename) async {
    if (kIsWeb) {
      final blob = html.Blob([data]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..target = '_blank'
        ..download = filename;
      html.document.body!.append(anchor);
      anchor.click();
      anchor.remove();
      html.Url.revokeObjectUrl(url);
    } else {
      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/$filename';
      final file = await File(filePath).writeAsBytes(data);
      await Share.shareXFiles([XFile(file.path)]);
    }
  }
}
