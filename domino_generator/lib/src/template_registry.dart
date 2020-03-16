import 'dart:io';
import 'package:path/path.dart' as p;
import 'canonical.dart';

class TemplateRegistry {
  final _location = <String, String>{};
  String basePath;

  registerDirectory(String path, {bool recursive = true}) {
    for (final file in Directory(path).listSync(recursive: recursive)) {
      if (file is File && file.path.endsWith('.html')) {
        registerFile(file.path);
      }
    }
  }

  registerFile(String path) {
    final html = File(path).readAsStringSync();
    final templates = parseToCanonical(html).templates;
    final genPath = path.replaceAll('.html', '.g.dart');
    for (final template in templates) {
      final namespace = template.attributes['d-namespace'];
      final method = template.attributes['*'];
      final method_ = method.replaceAll('-', '_');

      _location[method] = genPath;
      _location[method_] = genPath;
      if (namespace != null) {
        _location['$namespace:$method'] = genPath;
        _location['$namespace:$method_'] = genPath;
      }
    }
  }

  /// Tries to resolve a library path for the element if it is in the registry.
  /// Returns null, if element should be included as it is
  String resolveNamePath(String localName) {
    if (!localName.contains('-') && !localName.contains('.')) {
      return null;
    }
    if (localName.startsWith('d.')) {
      localName = localName.substring(1);
    }
    return _location[localName] != null
        ? p.relative(_location[localName], from: basePath)
        : null;
  }
}