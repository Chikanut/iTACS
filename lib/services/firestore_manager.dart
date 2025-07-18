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

/// Отримати список учасників групи з повною інформацією
  /// Отримати список учасників групи з повною інформацією
  /// Отримати список учасників групи з повною інформацією (через email lookup)
  Future<List<Map<String, dynamic>>> getGroupMembersWithDetails(String groupId) async {
    try {
      // Отримуємо список email-ів з групи
      final groupDoc = await _firestore.collection('allowed_users').doc(groupId).get();
      
      if (!groupDoc.exists) {
        debugPrint('FirestoreManager: Група $groupId не знайдена');
        return [];
      }

      final data = groupDoc.data() as Map<String, dynamic>;
      final members = Map<String, dynamic>.from(data['members'] ?? {});
      
      final List<Map<String, dynamic>> membersWithDetails = [];
      
      // Для кожного email отримуємо повну інформацію з users
      for (final entry in members.entries) {
        final email = entry.key;
        final roleValue = entry.value;
        
        // Роль може бути як рядком (стара структура), так і об'єктом (нова)
        String role = 'viewer';
        if (roleValue is String) {
          role = roleValue;
        } else if (roleValue is Map<String, dynamic>) {
          role = roleValue['role'] as String? ?? 'viewer';
        }
        
        try {
          // Шукаємо користувача в колекції users за email
          final userSnapshot = await _firestore
              .collection('users')
              .where('email', isEqualTo: email)
              .limit(1)
              .get();
          
          if (userSnapshot.docs.isNotEmpty) {
            final userDoc = userSnapshot.docs.first;
            final userData = userDoc.data();
            final uid = userDoc.id; // UID = document ID
            
            membersWithDetails.add({
              'uid': uid,
              'email': email,
              'role': role,
              'fullName': userData['fullName'] ?? userData['firstName'] ?? email.split('@').first,
              'firstName': userData['firstName'] ?? '',
              'lastName': userData['lastName'] ?? '',
              'rank': userData['rank'] ?? '',
              'position': userData['position'] ?? '',
              'phone': userData['phone'] ?? '',
            });
          } else {
            // Якщо профіль користувача не знайдено, використовуємо базові дані
            debugPrint('FirestoreManager: Профіль не знайдено для $email');
            membersWithDetails.add({
              'uid': '', // Без UID, якщо профіль не знайдено
              'email': email,
              'role': role,
              'fullName': email.split('@').first,
              'firstName': '',
              'lastName': '',
              'rank': '',
              'position': '',
              'phone': '',
            });
          }
        } catch (e) {
          debugPrint('FirestoreManager: Помилка отримання даних користувача $email: $e');
          // Додаємо базову інформацію навіть при помилці
          membersWithDetails.add({
            'uid': '',
            'email': email,
            'role': role,
            'fullName': email.split('@').first,
            'firstName': '',
            'lastName': '',
            'rank': '',
            'position': '',
            'phone': '',
          });
        }
      }
      
      // Сортуємо за ім'ям
      membersWithDetails.sort((a, b) => 
        (a['fullName'] as String).compareTo(b['fullName'] as String));
      
      debugPrint('FirestoreManager: Завантажено ${membersWithDetails.length} учасників групи');
      return membersWithDetails;
    } catch (e) {
      debugPrint('FirestoreManager: Помилка отримання учасників групи: $e');
      return [];
    }
  }

  /// Отримати email користувача за його UID (через зворотний пошук)
  Future<String?> getUserEmailByUid(String groupId, String uid) async {
    try {
      if (uid.isEmpty) return null;
      
      // Шукаємо користувача в users за UID (document ID)
      final userDoc = await _firestore.collection('users').doc(uid).get();
      
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final email = userData['email'] as String?;
        
        if (email != null) {
          // Перевіряємо чи цей email є в групі
          final groupDoc = await _firestore.collection('allowed_users').doc(groupId).get();
          if (groupDoc.exists) {
            final groupData = groupDoc.data() as Map<String, dynamic>;
            final members = Map<String, dynamic>.from(groupData['members'] ?? {});
            
            if (members.containsKey(email)) {
              return email;
            }
          }
        }
      }
      
      return null;
    } catch (e) {
      debugPrint('FirestoreManager: Помилка пошуку email для UID $uid: $e');
      return null;
    }
  }

  /// Отримати інформацію про користувача за UID
  Future<Map<String, dynamic>?> getUserByUid(String uid) async {
    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      
      if (userDoc.exists) {
        return userDoc.data() as Map<String, dynamic>;
      }
      
      return null;
    } catch (e) {
      debugPrint('FirestoreManager: Помилка отримання користувача $uid: $e');
      return null;
    }
  }

  /// CRUD операції для відсутностей
  
  /// Створити відсутність
  Future<String?> createAbsence({
    required String groupId,
    required Map<String, dynamic> absenceData,
  }) async {
    try {
      final docRef = await _firestore
          .collection('instructor_absences')
          .doc(groupId)
          .collection('items')
          .add(absenceData);
      
      debugPrint('FirestoreManager: Відсутність створена з ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('FirestoreManager: Помилка створення відсутності: $e');
      rethrow;
    }
  }

  /// Отримати відсутності для групи
  Future<List<DocumentSnapshot>> getAbsencesForGroup({
    required String groupId,
    DateTime? startDate,
    DateTime? endDate,
    String? instructorId,
    String? status,
  }) async {
    try {
      Query query = _firestore
          .collection('instructor_absences')
          .doc(groupId)
          .collection('items');

      // Фільтри по датах
      if (startDate != null) {
        query = query.where('endDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }
      
      if (endDate != null) {
        query = query.where('startDate', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      // Фільтр по інструктору
      if (instructorId != null) {
        query = query.where('instructorId', isEqualTo: instructorId);
      }

      // Фільтр по статусу
      if (status != null) {
        query = query.where('status', isEqualTo: status);
      }

      // Сортування по даті початку
      query = query.orderBy('startDate');

      final snapshot = await query.get();
      debugPrint('FirestoreManager: Знайдено ${snapshot.docs.length} відсутностей');
      
      return snapshot.docs;
    } catch (e) {
      debugPrint('FirestoreManager: Помилка отримання відсутностей: $e');
      return [];
    }
  }

  /// Оновити відсутність
  Future<bool> updateAbsence({
    required String groupId,
    required String absenceId,
    required Map<String, dynamic> updates,
  }) async {
    try {
      await _firestore
          .collection('instructor_absences')
          .doc(groupId)
          .collection('items')
          .doc(absenceId)
          .update(updates);
      
      debugPrint('FirestoreManager: Відсутність $absenceId оновлена');
      return true;
    } catch (e) {
      debugPrint('FirestoreManager: Помилка оновлення відсутності: $e');
      return false;
    }
  }

  /// Видалити відсутність
  Future<bool> deleteAbsence({
    required String groupId,
    required String absenceId,
  }) async {
    try {
      await _firestore
          .collection('instructor_absences')
          .doc(groupId)
          .collection('items')
          .doc(absenceId)
          .delete();
      
      debugPrint('FirestoreManager: Відсутність $absenceId видалена');
      return true;
    } catch (e) {
      debugPrint('FirestoreManager: Помилка видалення відсутності: $e');
      return false;
    }
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

      final membersRaw = data['members'];
      if (membersRaw == null) {
        debugPrint('⚠️ Поле members відсутнє у $groupId');
        continue;
      }

      final members = Map<String, dynamic>.from(membersRaw);

      if (members.containsKey(normalizedEmail)) {
        final memberValue = members[normalizedEmail];
        String role = 'viewer';

        // Підтримуємо обидві структури
        if (memberValue is Map<String, dynamic>) {
          // Нова структура: {uid: "...", role: "..."}
          role = memberValue['role'] as String? ?? 'viewer';
        } else if (memberValue is String) {
          // Стара структура: тільки роль як рядок
          role = memberValue;
        }

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

    final groupNames = await getGroupNamesForUser(email);
    await Globals.profileManager.loadSavedGroupWithFallback(groupNames);

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

  Future<void> updateUserUidInGroups(String email, String uid) async {
    try {
      final normalizedEmail = email.toLowerCase();
      final snapshot = await _firestore.collection('allowed_users').get();

      for (final doc in snapshot.docs) {
        final groupId = doc.id;
        final data = doc.data();
        final members = Map<String, dynamic>.from(data['members'] ?? {});

        if (members.containsKey(normalizedEmail)) {
          final currentValue = members[normalizedEmail];

          // Перевіряємо чи це стара структура (тільки роль як рядок)
          if (currentValue is String) {
            debugPrint('🔄 Оновлюємо структуру для $normalizedEmail в групі $groupId');
            
            // Оновлюємо на нову структуру з UID
            await _firestore.collection('allowed_users').doc(groupId).update({
              'members.$normalizedEmail': {
                'uid': uid,
                'role': currentValue, // зберігаємо стару роль
              }
            });
            
            debugPrint('✅ UID додано для $normalizedEmail в групі $groupId');
          } else if (currentValue is Map<String, dynamic>) {
            // Перевіряємо чи UID вже є
            if (currentValue['uid'] != uid) {
              debugPrint('🔄 Оновлюємо UID для $normalizedEmail в групі $groupId');
              
              await _firestore.collection('allowed_users').doc(groupId).update({
                'members.$normalizedEmail.uid': uid,
              });
              
              debugPrint('✅ UID оновлено для $normalizedEmail в групі $groupId');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Помилка оновлення UID в групах: $e');
      // Не кидаємо помилку, щоб не блокувати вхід
    }
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
