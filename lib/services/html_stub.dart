// html_stub.dart
// Заглушка для dart:html для мобільних платформ

import 'dart:typed_data';

class Blob {
  Blob(List<dynamic> blobParts, [String? type]);
}

class Url {
  static String createObjectUrlFromBlob(Blob blob) {
    throw UnsupportedError('createObjectUrlFromBlob не підтримується на мобільних платформах');
  }
  
  static void revokeObjectUrl(String url) {
    throw UnsupportedError('revokeObjectUrl не підтримується на мобільних платформах');
  }
}

class Window {
  void open(String url, String target) {
    throw UnsupportedError('window.open не підтримується на мобільних платформах');
  }
}

class AnchorElement {
  String? href;
  String? target;
  String? download;
  
  AnchorElement({this.href});
  
  void click() {
    throw UnsupportedError('anchor.click не підтримується на мобільних платформах');
  }
  
  void remove() {
    throw UnsupportedError('anchor.remove не підтримується на мобільних платформах');
  }
}

class Body {
  void append(AnchorElement element) {
    throw UnsupportedError('body.append не підтримується на мобільних платформах');
  }
}

class Document {
  Body? body = Body();
}

// Глобальні об'єкти
final window = Window();
final document = Document();