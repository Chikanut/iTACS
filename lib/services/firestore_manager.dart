import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../globals.dart';

class FirestoreManager {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Отримати список груп, до яких належить email
  Future<List<String>> getUserGroups(String email) async {
  final normalizedEmail = email.toLowerCase();
  final snapshot = await _firestore.collection('allowed_users').get();
  final List<String> groups = [];

  for (final doc in snapshot.docs) {
    final data = doc.data();
    final members = Map<String, dynamic>.from(data['members'] ?? {});
    if (members.containsKey(normalizedEmail)) {
      groups.add(doc.id);
    }
  }

  return groups;
}

  /// Перевірити чи користувач має доступ хоч до однієї групи
  Future<bool> isUserAllowed(String email) async {
    final groups = await getUserGroups(email);
    return groups.isNotEmpty;
  }

Future<List<DocumentSnapshot>> getDocumentsForGroup({
  required String groupId,
  required String collection,
  String? orderBy,
  bool descending = true,
  Map<String, dynamic>? whereEqual,
}) async {
  debugPrint('[firestore] getDocumentsForGroup:');
  debugPrint('  groupId: $groupId');
  debugPrint('  collection: $collection');
  debugPrint('  orderBy: $orderBy, descending: $descending');
  debugPrint('  whereEqual: $whereEqual');

  CollectionReference ref = _firestore
      .collection(collection)
      .doc(groupId)
      .collection('items');

  Query query = ref;

  if (whereEqual != null) {
    for (final entry in whereEqual.entries) {
      query = query.where(entry.key, isEqualTo: entry.value);
    }
  }

  if (orderBy != null) {
    query = query.orderBy(orderBy, descending: descending);
  }

  final snapshot = await query.get();
  debugPrint('[firestore] Fetched ${snapshot.docs.length} documents');

  return snapshot.docs;
}

  Future<void> createDocument({
    required String groupId,
    required String collection,
    required Map<String, dynamic> data,
  }) async {
    final ref = FirebaseFirestore.instance
      .collection(collection)
      .doc(groupId)
      .collection('items');

    await ref.add(data);
  }

  Future<void> updateDocument({
    required String groupId,
    required String collection,
    required String docId,
    required Map<String, dynamic> data,
  }) async {
    final ref = FirebaseFirestore.instance
      .collection(collection)
      .doc(groupId)
      .collection('items')
      .doc(docId);

    await ref.update(data);
  }

Future<Map<String, dynamic>> deleteDocumentWhereAllowed({
  required String docId,
  required String groupId,
  required String userRole,
  required String collection,
}) async {
  final deleted = <String>[];
  final skipped = <String>[];

  if (userRole == 'admin') {
    final ref = _firestore.collection(collection).doc(groupId).collection('items').doc(docId);
    final doc = await ref.get();
    if (doc.exists) {
      await ref.delete();
      deleted.add(groupId);
    }
  } else {
    skipped.add(groupId);
  }

  return {
    'deleted': deleted,
    'skipped': skipped,
  };
}

  Future<void> saveUserProfile({required String uid, required String email}) async {
    final groups = await getUserGroups(email);
    final userDocRef = _firestore.collection('users').doc(uid);
    final existingDoc = await userDocRef.get();

    Map<String, dynamic> updates = {
      'groups': groups,
      'lastLogin': FieldValue.serverTimestamp(),
    };

    // Додати email лише якщо новий або документу ще не існує
    if (!existingDoc.exists || existingDoc.data()?['email'] != email) {
      updates['email'] = email;
    }

    await userDocRef.set(updates, SetOptions(merge: true));
  }

  Future<void> updateEditableProfileFields({
    required String uid,
    String? firstName,
    String? lastName,
    String? position,
    String? rank,
    String? phone, // 👈 додано
    }) async {
    Map<String, dynamic> updates = {};

    if (firstName != null) updates['firstName'] = firstName;
    if (lastName != null) updates['lastName'] = lastName;
    if (position != null) updates['position'] = position;
    if (rank != null) updates['rank'] = rank;
    if (phone != null) updates['phone'] = phone;

    if (updates.isNotEmpty) {
      await FirebaseFirestore.instance.collection('users').doc(uid).update(updates);
    }
  }

Future<Map<String, String>> getUserRolesPerGroup(String email) async {
  final normalizedEmail = email.toLowerCase();
  debugPrint('📥 Перевірка ролей для: $normalizedEmail');

  final snapshot = await _firestore.collection('allowed_users').get();
  final Map<String, String> rolesByGroup = {};

  debugPrint('📄 Знайдено ${snapshot.docs.length} груп(и) у allowed_users');

  for (final doc in snapshot.docs) {
    final groupId = doc.id;
    final data = doc.data();

    debugPrint('🔍 Обробка групи: $groupId');
    debugPrint('📦 Вміст документа: $data');

    final membersRaw = data['members'];
    if (membersRaw == null) {
      debugPrint('⚠️ Поле members відсутнє у $groupId');
      continue;
    }

    final members = Map<String, dynamic>.from(membersRaw);

    debugPrint('👥 Members у $groupId: ${members.keys.join(', ')}');

    if (members.containsKey(normalizedEmail)) {
      final role = members[normalizedEmail]?.toString() ?? 'viewer';
      rolesByGroup[groupId] = role;
      debugPrint('✅ Користувач знайдений у $groupId з роллю: $role');
    } else {
      debugPrint('🚫 Користувача $normalizedEmail немає у $groupId');
    }
  }

  debugPrint('🎯 Результат ролей: $rolesByGroup');
  return rolesByGroup;
}
  Future<Map<String, dynamic>?> getOrCreateUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final uid = user.uid;
    final email = user.email!.toLowerCase();

    final docRef = _firestore.collection('users').doc(uid);
    final docSnap = await docRef.get();

    if (docSnap.exists) {
      final data = docSnap.data();
      return data;
    }

    // Якщо немає — створюємо заглушку
    final groups = await getUserGroups(email);

    final newData = {
      'email': email,
      'groups': groups,
      'firstName': '',
      'lastName': '',
      'rank': '',
      'position': '',
      'phone': '',
      'lastLogin': FieldValue.serverTimestamp(),
    };

    await docRef.set(newData);
    return newData;
  }

  Future<bool> ensureUserProfileSynced() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return false;

  final email = user.email!.toLowerCase();
  final uid = user.uid;

  final roles = await getUserRolesPerGroup(email);
  await Globals.profileManager.loadSavedGroupWithFallback(roles);

  final groups = await getUserGroups(email);
  final isAllowed = groups.isNotEmpty;
  if (!isAllowed) return false;

  final docRef = _firestore.collection('users').doc(uid);
  final existingDoc = await docRef.get();

  final baseData = {
    'email': email,
    'groups': groups,
    'lastLogin': FieldValue.serverTimestamp(),
  };

  if (existingDoc.exists) {
    await docRef.update(baseData);
  } else {
    await docRef.set({
      ...baseData,
      'firstName': '',
      'lastName': '',
      'rank': '',
      'position': '',
      'phone': '',
    });
  }

  return true;
}
Future<Map<String, String>> getGroupNamesForUser(String email) async {
  final normalizedEmail = email.toLowerCase();
  final snapshot = await _firestore.collection('allowed_users').get();
  final Map<String, String> groupNames = {};

  for (final doc in snapshot.docs) {
    final data = doc.data();
    final members = Map<String, dynamic>.from(data['members'] ?? {});
    if (members.containsKey(normalizedEmail)) {
      groupNames[doc.id] = data['name'] ?? doc.id;
    }
  }

  return groupNames;
}
}
