import 'package:cloud_firestore/cloud_firestore.dart';

class TemplateLineItem {
  final String itemId;
  final String itemName;
  final double quantity;

  const TemplateLineItem({
    required this.itemId,
    required this.itemName,
    required this.quantity,
  });

  factory TemplateLineItem.fromMap(Map<String, dynamic> map) =>
      TemplateLineItem(
        itemId: map['itemId'] as String? ?? '',
        itemName: map['itemName'] as String? ?? '',
        quantity: (map['quantity'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toMap() => {
    'itemId': itemId,
    'itemName': itemName,
    'quantity': quantity,
  };
}

class MaterialTemplate {
  final String id;
  final String name;
  final List<TemplateLineItem> items;
  final DateTime createdAt;
  final String authorEmail;

  const MaterialTemplate({
    required this.id,
    required this.name,
    required this.items,
    required this.createdAt,
    required this.authorEmail,
  });

  factory MaterialTemplate.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final rawItems = data['items'] as List<dynamic>? ?? [];
    return MaterialTemplate(
      id: doc.id,
      name: data['name'] as String? ?? '',
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map(TemplateLineItem.fromMap)
          .toList(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      authorEmail: data['authorEmail'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'items': items.map((i) => i.toMap()).toList(),
    'authorEmail': authorEmail,
  };

  Map<String, dynamic> toCreateMap() => {
    ...toMap(),
    'createdAt': FieldValue.serverTimestamp(),
  };
}
