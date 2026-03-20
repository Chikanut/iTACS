import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../globals.dart';
import '../models/notification_preferences.dart';

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
      final ref = _firestore
          .collection(collection)
          .doc(groupId)
          .collection('items')
          .doc(docId);
      final doc = await ref.get();
      if (doc.exists) {
        await ref.delete();
        deleted.add(groupId);
      }
    } else {
      skipped.add(groupId);
    }

    return {'deleted': deleted, 'skipped': skipped};
  }

  /// Отримати список учасників групи з повною інформацією
  /// Отримати список учасників групи з повною інформацією
  /// Отримати список учасників групи з повною інформацією (через email lookup)
  Future<List<Map<String, dynamic>>> getGroupMembersWithDetails(
    String groupId,
  ) async {
    try {
      // Отримуємо список email-ів з групи
      final groupDoc = await _firestore
          .collection('allowed_users')
          .doc(groupId)
          .get();

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
        if (!_isValidMemberEmailKey(email)) {
          continue;
        }
        final roleValue = entry.value;

        // Роль може бути як рядком (стара структура), так і об'єктом (нова)
        String role = 'viewer';
        if (roleValue is String) {
          role = roleValue;
        } else if (roleValue is Map<String, dynamic>) {
          role = roleValue['role'] as String? ?? 'viewer';
        }

        final memberData = roleValue is Map<String, dynamic>
            ? roleValue
            : const <String, dynamic>{};
        final fallbackFirstName = (memberData['firstName'] as String?) ?? '';
        final fallbackLastName = (memberData['lastName'] as String?) ?? '';
        final fallbackRank = (memberData['rank'] as String?) ?? '';
        final fallbackPosition = (memberData['position'] as String?) ?? '';
        final fallbackPhone = (memberData['phone'] as String?) ?? '';
        final fallbackFullName =
            '$fallbackFirstName $fallbackLastName'.trim().isNotEmpty
            ? '$fallbackFirstName $fallbackLastName'.trim()
            : email.split('@').first;

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
              'fullName':
                  userData['fullName'] ??
                      '${(userData['firstName'] ?? fallbackFirstName).toString()} ${(userData['lastName'] ?? fallbackLastName).toString()}'
                          .trim()
                          .isNotEmpty
                  ? '${(userData['firstName'] ?? fallbackFirstName).toString()} ${(userData['lastName'] ?? fallbackLastName).toString()}'
                        .trim()
                  : fallbackFullName,
              'firstName': userData['firstName'] ?? fallbackFirstName,
              'lastName': userData['lastName'] ?? fallbackLastName,
              'rank': userData['rank'] ?? fallbackRank,
              'position': userData['position'] ?? fallbackPosition,
              'phone': userData['phone'] ?? fallbackPhone,
            });
          } else {
            // Якщо профіль користувача не знайдено, використовуємо базові дані
            debugPrint('FirestoreManager: Профіль не знайдено для $email');
            membersWithDetails.add({
              'uid': '', // Без UID, якщо профіль не знайдено
              'email': email,
              'role': role,
              'fullName': fallbackFullName,
              'firstName': fallbackFirstName,
              'lastName': fallbackLastName,
              'rank': fallbackRank,
              'position': fallbackPosition,
              'phone': fallbackPhone,
            });
          }
        } catch (e) {
          debugPrint(
            'FirestoreManager: Помилка отримання даних користувача $email: $e',
          );
          // Додаємо базову інформацію навіть при помилці
          membersWithDetails.add({
            'uid': '',
            'email': email,
            'role': role,
            'fullName': fallbackFullName,
            'firstName': fallbackFirstName,
            'lastName': fallbackLastName,
            'rank': fallbackRank,
            'position': fallbackPosition,
            'phone': fallbackPhone,
          });
        }
      }

      // Сортуємо за ім'ям
      membersWithDetails.sort(
        (a, b) => (a['fullName'] as String).compareTo(b['fullName'] as String),
      );

      debugPrint(
        'FirestoreManager: Завантажено ${membersWithDetails.length} учасників групи',
      );
      return membersWithDetails;
    } catch (e) {
      debugPrint('FirestoreManager: Помилка отримання учасників групи: $e');
      return [];
    }
  }

  /// Отримати email користувача за його UID (через зворотний пошук)
  Future<String?> getUserEmailByUid(String groupId, String uid) async {
    try {
      final normalizedUid = uid.trim();
      if (normalizedUid.isEmpty) return null;
      if (normalizedUid.contains('@')) {
        return normalizedUid.toLowerCase();
      }

      // Шукаємо користувача в users за UID (document ID)
      final userDoc = await _firestore
          .collection('users')
          .doc(normalizedUid)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final email = userData['email'] as String?;

        if (email != null) {
          // Перевіряємо чи цей email є в групі
          final groupDoc = await _firestore
              .collection('allowed_users')
              .doc(groupId)
              .get();
          if (groupDoc.exists) {
            final groupData = groupDoc.data() as Map<String, dynamic>;
            final members = Map<String, dynamic>.from(
              groupData['members'] ?? {},
            );

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

  Future<void> addOrUpdateGroupMember({
    required String groupId,
    required String email,
    String role = 'viewer',
    String? firstName,
    String? lastName,
    String? rank,
    String? position,
    String? phone,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) {
      throw Exception('Email не може бути порожнім');
    }

    final groupRef = _firestore.collection('allowed_users').doc(groupId);
    final groupDoc = await groupRef.get();
    final groupData = groupDoc.data() ?? {};
    final members = Map<String, dynamic>.from(groupData['members'] ?? {});
    final malformedMember = _extractMalformedMemberEntry(
      members,
      normalizedEmail,
    );
    final existingMember = members[normalizedEmail] ?? malformedMember;

    String? memberUid;
    if (existingMember is Map<String, dynamic>) {
      memberUid = existingMember['uid'] as String?;
    }

    final userSnapshot = await _firestore
        .collection('users')
        .where('email', isEqualTo: normalizedEmail)
        .limit(1)
        .get();

    if (userSnapshot.docs.isNotEmpty) {
      memberUid = userSnapshot.docs.first.id;
    }

    final memberPayload = existingMember is Map<String, dynamic>
        ? Map<String, dynamic>.from(existingMember)
        : <String, dynamic>{};

    memberPayload['role'] = role;
    if (memberUid != null && memberUid.isNotEmpty) {
      memberPayload['uid'] = memberUid;
    }

    void setOptionalField(String key, String? value) {
      if (value == null) {
        return;
      }
      memberPayload[key] = value.trim();
    }

    setOptionalField('firstName', firstName);
    setOptionalField('lastName', lastName);
    setOptionalField('rank', rank);
    setOptionalField('position', position);
    setOptionalField('phone', phone);

    members[normalizedEmail] = memberPayload;
    await groupRef.update({'members': members});

    try {
      await _upsertPendingUserProfile(
        email: normalizedEmail,
        firstName: firstName,
        lastName: lastName,
        rank: rank,
        position: position,
        phone: phone,
      );
    } catch (e) {
      // Адмін може додавати людей у групу раніше, ніж вони створять власний
      // профіль. У такому разі allowed_users вже оновлено успішно, а запис
      // у /users може бути заборонений rules і не повинен валити весь сценарій.
      debugPrint(
        'FirestoreManager: Профіль користувача $normalizedEmail не було '
        'синхронізовано під час додавання до групи: $e',
      );
    }
  }

  Future<void> updateGroupMemberRole({
    required String groupId,
    required String email,
    required String role,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) {
      throw Exception('Email не може бути порожнім');
    }

    final groupRef = _firestore.collection('allowed_users').doc(groupId);
    final groupDoc = await groupRef.get();
    final groupData = groupDoc.data() ?? {};
    final members = Map<String, dynamic>.from(groupData['members'] ?? {});
    final malformedMember = _extractMalformedMemberEntry(
      members,
      normalizedEmail,
    );
    final existingMember = members[normalizedEmail] ?? malformedMember;

    if (existingMember == null) {
      throw Exception('Учасника не знайдено в цій групі');
    }

    if (existingMember is Map<String, dynamic>) {
      final updatedMember = Map<String, dynamic>.from(existingMember);
      updatedMember['role'] = role;
      members[normalizedEmail] = updatedMember;
    } else {
      members[normalizedEmail] = {'role': role};
    }
    await groupRef.update({'members': members});
  }

  Future<void> removeGroupMember({
    required String groupId,
    required String email,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) {
      throw Exception('Email не може бути порожнім');
    }

    final groupRef = _firestore.collection('allowed_users').doc(groupId);
    final groupDoc = await groupRef.get();
    final groupData = groupDoc.data() ?? {};
    final members = Map<String, dynamic>.from(groupData['members'] ?? {});
    members.remove(normalizedEmail);
    _extractMalformedMemberEntry(members, normalizedEmail);
    await groupRef.update({'members': members});
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
        query = query.where(
          'endDate',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
        );
      }

      if (endDate != null) {
        query = query.where(
          'startDate',
          isLessThanOrEqualTo: Timestamp.fromDate(endDate),
        );
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
      debugPrint(
        'FirestoreManager: Знайдено ${snapshot.docs.length} відсутностей',
      );

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

  Future<void> saveUserProfile({
    required String uid,
    required String email,
  }) async {
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
    Map<String, bool>? notificationPreferences,
  }) async {
    Map<String, dynamic> updates = {};

    if (firstName != null) updates['firstName'] = firstName;
    if (lastName != null) updates['lastName'] = lastName;
    if (position != null) updates['position'] = position;
    if (rank != null) updates['rank'] = rank;
    if (phone != null) updates['phone'] = phone;
    if (notificationPreferences != null) {
      updates['notificationPreferences'] = notificationPreferences;
    }

    if (updates.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update(updates);
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
    return await _ensureUserDocForAuthenticatedUser(uid: uid, email: email);
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

    await _ensureUserDocForAuthenticatedUser(uid: uid, email: email);

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
        final malformedMember = _extractMalformedMemberEntry(
          members,
          normalizedEmail,
        );

        if (members.containsKey(normalizedEmail) || malformedMember != null) {
          final currentValue = members[normalizedEmail] ?? malformedMember;

          // Перевіряємо чи це стара структура (тільки роль як рядок)
          if (currentValue is String) {
            debugPrint(
              '🔄 Оновлюємо структуру для $normalizedEmail в групі $groupId',
            );

            members[normalizedEmail] = {'uid': uid, 'role': currentValue};
            await _firestore.collection('allowed_users').doc(groupId).update({
              'members': members,
            });

            debugPrint('✅ UID додано для $normalizedEmail в групі $groupId');
          } else if (currentValue is Map<String, dynamic>) {
            // Перевіряємо чи UID вже є
            if (currentValue['uid'] != uid) {
              debugPrint(
                '🔄 Оновлюємо UID для $normalizedEmail в групі $groupId',
              );

              final updatedMember = Map<String, dynamic>.from(currentValue);
              updatedMember['uid'] = uid;
              members[normalizedEmail] = updatedMember;
              await _firestore.collection('allowed_users').doc(groupId).update({
                'members': members,
              });

              debugPrint(
                '✅ UID оновлено для $normalizedEmail в групі $groupId',
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Помилка оновлення UID в групах: $e');
      // Не кидаємо помилку, щоб не блокувати вхід
    }
  }

  dynamic _extractMalformedMemberEntry(
    Map<String, dynamic> members,
    String normalizedEmail,
  ) {
    if (members.containsKey(normalizedEmail)) {
      _removeMalformedMemberEntry(members, normalizedEmail);
      return null;
    }

    final parts = normalizedEmail.split('.');
    if (parts.length < 2) {
      return null;
    }

    dynamic current = members;
    for (final part in parts) {
      if (current is! Map || !current.containsKey(part)) {
        return null;
      }
      current = current[part];
    }

    _removeMalformedMemberEntry(members, normalizedEmail);
    return current;
  }

  void _removeMalformedMemberEntry(
    Map<String, dynamic> members,
    String normalizedEmail,
  ) {
    final parts = normalizedEmail.split('.');
    if (parts.length < 2) {
      return;
    }

    _removeNestedKeyPath(members, parts, 0);
  }

  bool _removeNestedKeyPath(
    Map<String, dynamic> current,
    List<String> parts,
    int index,
  ) {
    final key = parts[index];
    if (!current.containsKey(key)) {
      return false;
    }

    if (index == parts.length - 1) {
      current.remove(key);
      return current.isEmpty;
    }

    final next = current[key];
    if (next is! Map) {
      return false;
    }

    final nextMap = Map<String, dynamic>.from(next);
    final shouldRemoveChild = _removeNestedKeyPath(nextMap, parts, index + 1);

    if (shouldRemoveChild) {
      current.remove(key);
    } else {
      current[key] = nextMap;
    }

    return current.isEmpty;
  }

  bool _isValidMemberEmailKey(String value) {
    final normalized = value.trim().toLowerCase();
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(normalized);
  }

  Future<void> _upsertPendingUserProfile({
    required String email,
    String? firstName,
    String? lastName,
    String? rank,
    String? position,
    String? phone,
  }) async {
    final existingDoc = await _findUserDocByEmail(email);
    final targetDocRef =
        existingDoc?.reference ?? _firestore.collection('users').doc(email);
    final existingData = existingDoc?.data() ?? {};
    final groups = await getUserGroups(email);

    await targetDocRef.set({
      'email': email,
      'groups': groups,
      'firstName': _pickProfileValue(firstName, existingData['firstName']),
      'lastName': _pickProfileValue(lastName, existingData['lastName']),
      'rank': _pickProfileValue(rank, existingData['rank']),
      'position': _pickProfileValue(position, existingData['position']),
      'phone': _pickProfileValue(phone, existingData['phone']),
      'notificationPreferences': _normalizeNotificationPreferencesMap(
        existingData['notificationPreferences'],
      ),
      'profileSeedSource': 'group_member_add',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>> _ensureUserDocForAuthenticatedUser({
    required String uid,
    required String email,
  }) async {
    final docRef = _firestore.collection('users').doc(uid);
    final docSnap = await docRef.get();
    final groups = await getUserGroups(email);

    if (docSnap.exists) {
      await docRef.set({
        'email': email,
        'groups': groups,
        'notificationPreferences': _normalizeNotificationPreferencesMap(
          docSnap.data()?['notificationPreferences'],
        ),
        'lastLogin': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final refreshedDoc = await docRef.get();
      return refreshedDoc.data() ?? {};
    }

    final pendingDoc = await _findUserDocByEmail(email);
    final pendingData = pendingDoc?.data() ?? {};

    await docRef.set({
      'email': email,
      'groups': groups,
      'firstName': (pendingData['firstName'] as String?) ?? '',
      'lastName': (pendingData['lastName'] as String?) ?? '',
      'rank': (pendingData['rank'] as String?) ?? '',
      'position': (pendingData['position'] as String?) ?? '',
      'phone': (pendingData['phone'] as String?) ?? '',
      'notificationPreferences': _normalizeNotificationPreferencesMap(
        pendingData['notificationPreferences'],
      ),
      'lastLogin': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (pendingDoc != null && pendingDoc.id != uid) {
      await pendingDoc.reference.delete();
    }

    await updateUserUidInGroups(email, uid);

    final refreshedDoc = await docRef.get();
    return refreshedDoc.data() ?? {};
  }

  Future<QueryDocumentSnapshot<Map<String, dynamic>>?> _findUserDocByEmail(
    String email,
  ) async {
    final normalizedEmail = email.trim().toLowerCase();
    final snapshot = await _firestore
        .collection('users')
        .where('email', isEqualTo: normalizedEmail)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    return snapshot.docs.first;
  }

  String _pickProfileValue(dynamic candidate, dynamic existing) {
    final candidateText = (candidate as String?)?.trim();
    if (candidateText != null && candidateText.isNotEmpty) {
      return candidateText;
    }

    final existingText = (existing as String?)?.trim();
    return existingText ?? '';
  }

  Map<String, bool> _normalizeNotificationPreferencesMap(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return NotificationPreferences.fromMap(raw).toMap();
    }

    if (raw is Map) {
      return NotificationPreferences.fromMap(
        Map<String, dynamic>.from(raw),
      ).toMap();
    }

    return NotificationPreferences.defaults.toMap();
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
