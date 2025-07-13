import 'dart:io';

void main() {
  final indexFile = File('web/index.html');
  final target = File('build/web/index.html');

  if (indexFile.existsSync() && target.existsSync()) {
    target.writeAsStringSync(indexFile.readAsStringSync());
    print('✅ index.html замінено в build/web/');
  } else {
    print('⚠️ index.html не знайдено');
  }
}
