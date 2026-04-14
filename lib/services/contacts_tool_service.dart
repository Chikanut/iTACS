import 'package:cloud_firestore/cloud_firestore.dart';

class ContactEntry {
  final String unit;
  final String rank;
  final String name;
  final String phone;

  const ContactEntry({
    required this.unit,
    required this.rank,
    required this.name,
    required this.phone,
  });

  Map<String, dynamic> toMap() => {
    'unit': unit,
    'rank': rank,
    'name': name,
    'phone': phone,
  };

  factory ContactEntry.fromMap(Map<String, dynamic> map) => ContactEntry(
    unit: map['unit']?.toString() ?? '',
    rank: map['rank']?.toString() ?? '',
    name: map['name']?.toString() ?? '',
    phone: map['phone']?.toString() ?? '',
  );

  ContactEntry copyWith({
    String? unit,
    String? rank,
    String? name,
    String? phone,
  }) => ContactEntry(
    unit: unit ?? this.unit,
    rank: rank ?? this.rank,
    name: name ?? this.name,
    phone: phone ?? this.phone,
  );
}

class DepartmentEntry {
  final String id;
  final String name;
  final int order;
  final List<ContactEntry> contacts;

  const DepartmentEntry({
    required this.id,
    required this.name,
    required this.order,
    required this.contacts,
  });

  Map<String, dynamic> toMap() => {
    'name': name,
    'order': order,
    'contacts': contacts.map((c) => c.toMap()).toList(),
  };

  factory DepartmentEntry.fromDoc(DocumentSnapshot doc) {
    final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
    final rawContacts = data['contacts'];
    List<ContactEntry> contacts = [];
    if (rawContacts is List) {
      contacts = rawContacts
          .map((c) => ContactEntry.fromMap(Map<String, dynamic>.from(c as Map)))
          .toList();
    }
    return DepartmentEntry(
      id: doc.id,
      name: data['name']?.toString() ?? '',
      order: (data['order'] as num?)?.toInt() ?? 0,
      contacts: contacts,
    );
  }

  DepartmentEntry copyWith({
    String? id,
    String? name,
    int? order,
    List<ContactEntry>? contacts,
  }) => DepartmentEntry(
    id: id ?? this.id,
    name: name ?? this.name,
    order: order ?? this.order,
    contacts: contacts ?? this.contacts,
  );
}

class ContactsToolService {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  CollectionReference _deptsRef(String groupId) => _firestore
      .collection('contacts_by_group')
      .doc(groupId)
      .collection('departments');

  Stream<List<DepartmentEntry>> watchDepartments(String groupId) {
    return _deptsRef(groupId)
        .orderBy('order')
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((doc) => DepartmentEntry.fromDoc(doc)).toList(),
        );
  }

  Future<List<DepartmentEntry>> getDepartments(String groupId) async {
    final snap = await _deptsRef(groupId).orderBy('order').get();
    return snap.docs.map((doc) => DepartmentEntry.fromDoc(doc)).toList();
  }

  Future<void> addDepartment(String groupId, String name) async {
    final existing = await getDepartments(groupId);
    final maxOrder = existing.isEmpty
        ? 0
        : existing.map((d) => d.order).reduce((a, b) => a > b ? a : b);
    await _deptsRef(
      groupId,
    ).add({'name': name, 'order': maxOrder + 1, 'contacts': []});
  }

  Future<void> updateDepartmentName(
    String groupId,
    String deptId,
    String name,
  ) async {
    await _deptsRef(groupId).doc(deptId).update({'name': name});
  }

  Future<void> deleteDepartment(String groupId, String deptId) async {
    await _deptsRef(groupId).doc(deptId).delete();
  }

  Future<void> updateContacts(
    String groupId,
    String deptId,
    List<ContactEntry> contacts,
  ) async {
    await _deptsRef(
      groupId,
    ).doc(deptId).update({'contacts': contacts.map((c) => c.toMap()).toList()});
  }
}
