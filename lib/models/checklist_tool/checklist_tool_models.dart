import 'dart:convert';

enum FieldType {
  text('text', 'Текст'),
  date('date', 'Дата'),
  number('number', 'Число'),
  textarea('textarea', 'Багаторядковий текст');

  const FieldType(this.id, this.displayName);

  final String id;
  final String displayName;

  static FieldType fromId(String? id) {
    return values.firstWhere(
      (value) => value.id == id,
      orElse: () => FieldType.text,
    );
  }
}

enum TemplateColor {
  blue('blue', 'Синя'),
  red('red', 'Червона'),
  green('green', 'Зелена'),
  orange('orange', 'Помаранчева');

  const TemplateColor(this.id, this.displayName);

  final String id;
  final String displayName;

  static TemplateColor fromId(String? id) {
    return values.firstWhere(
      (value) => value.id == id,
      orElse: () => TemplateColor.blue,
    );
  }
}

class ChecklistToolConfig {
  const ChecklistToolConfig({
    required this.id,
    required this.title,
    this.emoji,
    this.userFields = const [],
    this.sections = const [],
    this.infoCards = const [],
    this.templates = const [],
  });

  final String id;
  final String title;
  final String? emoji;
  final List<UserField> userFields;
  final List<ChecklistSection> sections;
  final List<InfoCard> infoCards;
  final List<MessageTemplate> templates;

  factory ChecklistToolConfig.fromJson(Map<String, dynamic> json) {
    return ChecklistToolConfig(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      emoji: _nullableString(json['emoji']),
      userFields: _mapList(json['userFields'], UserField.fromJson),
      sections: _mapList(json['sections'], ChecklistSection.fromJson),
      infoCards: _mapList(json['infoCards'], InfoCard.fromJson),
      templates: _mapList(json['templates'], MessageTemplate.fromJson),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    if (emoji != null && emoji!.trim().isNotEmpty) 'emoji': emoji,
    'userFields': userFields.map((item) => item.toJson()).toList(),
    'sections': sections.map((item) => item.toJson()).toList(),
    'infoCards': infoCards.map((item) => item.toJson()).toList(),
    'templates': templates.map((item) => item.toJson()).toList(),
  };

  ChecklistToolConfig copyWith({
    String? id,
    String? title,
    Object? emoji = _sentinelValue,
    List<UserField>? userFields,
    List<ChecklistSection>? sections,
    List<InfoCard>? infoCards,
    List<MessageTemplate>? templates,
  }) {
    return ChecklistToolConfig(
      id: id ?? this.id,
      title: title ?? this.title,
      emoji: identical(emoji, _sentinelValue) ? this.emoji : emoji as String?,
      userFields: userFields ?? this.userFields,
      sections: sections ?? this.sections,
      infoCards: infoCards ?? this.infoCards,
      templates: templates ?? this.templates,
    );
  }

  int get totalChecklistItems =>
      sections.fold<int>(0, (sum, section) => sum + section.items.length);

  String encode() => jsonEncode(toJson());
}

class UserField {
  const UserField({
    required this.id,
    required this.label,
    required this.fieldType,
    this.placeholder,
    this.isGlobal = true,
  });

  final String id;
  final String label;
  final FieldType fieldType;
  final String? placeholder;
  final bool isGlobal;

  factory UserField.fromJson(Map<String, dynamic> json) {
    return UserField(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      fieldType: FieldType.fromId(json['fieldType']?.toString()),
      placeholder: _nullableString(json['placeholder']),
      isGlobal: json['isGlobal'] == null ? true : json['isGlobal'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'fieldType': fieldType.id,
    if (placeholder != null && placeholder!.trim().isNotEmpty)
      'placeholder': placeholder,
    'isGlobal': isGlobal,
  };

  UserField copyWith({
    String? id,
    String? label,
    FieldType? fieldType,
    Object? placeholder = _sentinelValue,
    bool? isGlobal,
  }) {
    return UserField(
      id: id ?? this.id,
      label: label ?? this.label,
      fieldType: fieldType ?? this.fieldType,
      placeholder: identical(placeholder, _sentinelValue)
          ? this.placeholder
          : placeholder as String?,
      isGlobal: isGlobal ?? this.isGlobal,
    );
  }

  TemplateField toTemplateField() {
    return TemplateField(
      id: id,
      label: label,
      fieldType: fieldType,
      placeholder: placeholder,
    );
  }
}

class ChecklistSection {
  const ChecklistSection({
    required this.id,
    required this.title,
    this.emoji,
    this.items = const [],
  });

  final String id;
  final String title;
  final String? emoji;
  final List<ChecklistItem> items;

  factory ChecklistSection.fromJson(Map<String, dynamic> json) {
    return ChecklistSection(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      emoji: _nullableString(json['emoji']),
      items: _mapList(json['items'], ChecklistItem.fromJson),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    if (emoji != null && emoji!.trim().isNotEmpty) 'emoji': emoji,
    'items': items.map((item) => item.toJson()).toList(),
  };

  ChecklistSection copyWith({
    String? id,
    String? title,
    Object? emoji = _sentinelValue,
    List<ChecklistItem>? items,
  }) {
    return ChecklistSection(
      id: id ?? this.id,
      title: title ?? this.title,
      emoji: identical(emoji, _sentinelValue) ? this.emoji : emoji as String?,
      items: items ?? this.items,
    );
  }
}

class ChecklistItem {
  const ChecklistItem({required this.id, required this.text});

  final String id;
  final String text;

  factory ChecklistItem.fromJson(Map<String, dynamic> json) {
    return ChecklistItem(
      id: json['id']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'text': text};

  ChecklistItem copyWith({String? id, String? text}) {
    return ChecklistItem(id: id ?? this.id, text: text ?? this.text);
  }
}

class InfoCard {
  const InfoCard({
    required this.id,
    required this.title,
    required this.content,
    this.accentColor,
  });

  final String id;
  final String title;
  final String content;
  final int? accentColor;

  factory InfoCard.fromJson(Map<String, dynamic> json) {
    return InfoCard(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      accentColor: (json['accentColor'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    if (accentColor != null) 'accentColor': accentColor,
  };

  InfoCard copyWith({
    String? id,
    String? title,
    String? content,
    Object? accentColor = _sentinelValue,
  }) {
    return InfoCard(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      accentColor: identical(accentColor, _sentinelValue)
          ? this.accentColor
          : accentColor as int?,
    );
  }
}

class MessageTemplate {
  const MessageTemplate({
    required this.id,
    required this.title,
    required this.buttonColor,
    this.fields = const [],
    required this.body,
  });

  final String id;
  final String title;
  final TemplateColor buttonColor;
  final List<TemplateField> fields;
  final String body;

  factory MessageTemplate.fromJson(Map<String, dynamic> json) {
    return MessageTemplate(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      buttonColor: TemplateColor.fromId(json['buttonColor']?.toString()),
      fields: _mapList(json['fields'], TemplateField.fromJson),
      body: json['body']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'buttonColor': buttonColor.id,
    'fields': fields.map((item) => item.toJson()).toList(),
    'body': body,
  };

  MessageTemplate copyWith({
    String? id,
    String? title,
    TemplateColor? buttonColor,
    List<TemplateField>? fields,
    String? body,
  }) {
    return MessageTemplate(
      id: id ?? this.id,
      title: title ?? this.title,
      buttonColor: buttonColor ?? this.buttonColor,
      fields: fields ?? this.fields,
      body: body ?? this.body,
    );
  }
}

class TemplateField {
  const TemplateField({
    required this.id,
    required this.label,
    required this.fieldType,
    this.placeholder,
  });

  final String id;
  final String label;
  final FieldType fieldType;
  final String? placeholder;

  factory TemplateField.fromJson(Map<String, dynamic> json) {
    return TemplateField(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      fieldType: FieldType.fromId(json['fieldType']?.toString()),
      placeholder: _nullableString(json['placeholder']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'fieldType': fieldType.id,
    if (placeholder != null && placeholder!.trim().isNotEmpty)
      'placeholder': placeholder,
  };

  TemplateField copyWith({
    String? id,
    String? label,
    FieldType? fieldType,
    Object? placeholder = _sentinelValue,
  }) {
    return TemplateField(
      id: id ?? this.id,
      label: label ?? this.label,
      fieldType: fieldType ?? this.fieldType,
      placeholder: identical(placeholder, _sentinelValue)
          ? this.placeholder
          : placeholder as String?,
    );
  }
}

class ChecklistSessionState {
  const ChecklistSessionState({
    required this.configId,
    required this.sessionKey,
    this.checkedItems = const <String>{},
  });

  final String configId;
  final String sessionKey;
  final Set<String> checkedItems;

  factory ChecklistSessionState.fromJson(Map<String, dynamic> json) {
    return ChecklistSessionState(
      configId: json['configId']?.toString() ?? '',
      sessionKey: json['sessionKey']?.toString() ?? '',
      checkedItems: ((json['checkedItems'] as List?) ?? const [])
          .map((item) => item.toString())
          .toSet(),
    );
  }

  Map<String, dynamic> toJson() => {
    'configId': configId,
    'sessionKey': sessionKey,
    'checkedItems': checkedItems.toList()..sort(),
  };

  ChecklistSessionState copyWith({
    String? configId,
    String? sessionKey,
    Set<String>? checkedItems,
  }) {
    return ChecklistSessionState(
      configId: configId ?? this.configId,
      sessionKey: sessionKey ?? this.sessionKey,
      checkedItems: checkedItems ?? this.checkedItems,
    );
  }
}

String? _nullableString(Object? value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) {
    return null;
  }
  return text;
}

List<T> _mapList<T>(
  Object? source,
  T Function(Map<String, dynamic> json) parser,
) {
  if (source is! List) {
    return const [];
  }

  return source
      .whereType<Map>()
      .map((item) => parser(Map<String, dynamic>.from(item)))
      .toList(growable: false);
}

const _sentinelValue = Object();
