class TemplateRenderer {
  static final RegExp _placeholderRegExp = RegExp(
    r'{{\s*([a-zA-Z0-9_\-]+)\s*}}',
  );

  static String render(String body, Map<String, String> values) {
    return body.replaceAllMapped(_placeholderRegExp, (match) {
      final key = match.group(1) ?? '';
      final value = values[key]?.trim();
      if (value == null || value.isEmpty) {
        return '[${key.toUpperCase()}]';
      }
      return value;
    });
  }

  static List<String> extractPlaceholders(String body) {
    final placeholders = <String>[];
    for (final match in _placeholderRegExp.allMatches(body)) {
      final key = match.group(1);
      if (key == null || placeholders.contains(key)) {
        continue;
      }
      placeholders.add(key);
    }
    return placeholders;
  }
}
