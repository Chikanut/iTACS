import 'package:cloud_firestore/cloud_firestore.dart';

class MaterialJournal {
  final String id;
  final String name;
  final String? description;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final String authorEmail;

  const MaterialJournal({
    required this.id,
    required this.name,
    this.description,
    required this.createdAt,
    required this.modifiedAt,
    required this.authorEmail,
  });

  factory MaterialJournal.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MaterialJournal(
      id: doc.id,
      name: data['name'] as String? ?? '',
      description: data['description'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      modifiedAt:
          (data['modifiedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      authorEmail: data['authorEmail'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'description': description,
    'modifiedAt': FieldValue.serverTimestamp(),
    'authorEmail': authorEmail,
  };

  Map<String, dynamic> toCreateMap() => {
    ...toMap(),
    'createdAt': FieldValue.serverTimestamp(),
  };

  MaterialJournal copyWith({String? name, String? description}) =>
      MaterialJournal(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        createdAt: createdAt,
        modifiedAt: DateTime.now(),
        authorEmail: authorEmail,
      );
}
