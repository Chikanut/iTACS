import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../globals.dart';

/// Модель профільних даних користувача
class UserProfile {
  final String? firstName;
  final String? lastName;
  final String? rank;
  final String? position;
  final String? phone;
  final String? email;
  final String? uid;
  final List<String> groups;
  final Map<String, String> rolesPerGroup;
  final DateTime? lastUpdated;

  const UserProfile({
    this.firstName,
    this.lastName,
    this.rank,
    this.position,
    this.phone,
    this.email,
    this.uid,
    this.groups = const [],
    this.rolesPerGroup = const {},
    this.lastUpdated,
  });

  /// Повне ім'я користувача
  String get fullName {
    final first = firstName ?? '';
    final last = lastName ?? '';
    if (first.isEmpty && last.isEmpty) return email?.split('@').first ?? 'Користувач';
    return '$first $last'.trim();
  }

  /// Ініціали користувача
  String get initials {
    final first = firstName?.isNotEmpty == true ? firstName![0].toUpperCase() : '';
    final last = lastName?.isNotEmpty == true ? lastName![0].toUpperCase() : '';
    if (first.isEmpty && last.isEmpty) {
      final emailName = email?.split('@').first ?? 'У';
      return emailName.isNotEmpty ? emailName[0].toUpperCase() : 'У';
    }
    return '$first$last';
  }

  /// Створити копію з оновленими полями
  UserProfile copyWith({
    String? firstName,
    String? lastName,
    String? rank,
    String? position,
    String? phone,
    String? email,
    String? uid,
    List<String>? groups,
    Map<String, String>? rolesPerGroup,
    DateTime? lastUpdated,
  }) {
    return UserProfile(
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      rank: rank ?? this.rank,
      position: position ?? this.position,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      uid: uid ?? this.uid,
      groups: groups ?? this.groups,
      rolesPerGroup: rolesPerGroup ?? this.rolesPerGroup,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  /// Конвертувати у Map
  Map<String, dynamic> toMap() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'rank': rank,
      'position': position,
      'phone': phone,
      'email': email,
      'uid': uid,
      'groups': groups,
      'rolesPerGroup': rolesPerGroup,
      'lastUpdated': lastUpdated?.toIso8601String(),
    };
  }

  /// Створити з Map
  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      firstName: map['firstName'],
      lastName: map['lastName'],
      rank: map['rank'],
      position: map['position'],
      phone: map['phone'],
      email: map['email'],
      uid: map['uid'],
      groups: List<String>.from(map['groups'] ?? []),
      rolesPerGroup: Map<String, String>.from(map['rolesPerGroup'] ?? {}),
      lastUpdated: map['lastUpdated'] != null 
          ? DateTime.parse(map['lastUpdated']) 
          : null,
    );
  }

  static const empty = UserProfile();
}

/// Модель поточної групи
class CurrentGroup {
  final String id;
  final String name;
  final String? role;

  const CurrentGroup({
    required this.id,
    required this.name,
    this.role,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'role': role,
    };
  }

  factory CurrentGroup.fromMap(Map<String, dynamic> map) {
    return CurrentGroup(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      role: map['role'],
    );
  }
}

class ProfileManager {
  static const String _profileBoxName = 'user_profile';
  static const String _currentGroupBoxName = 'current_group';
  
  static const String _profileKey = 'profile_data';
  static const String _currentGroupKey = 'current_group_data';

  Box<dynamic>? _profileBox;
  Box<dynamic>? _currentGroupBox;

  UserProfile _profile = UserProfile.empty;
  CurrentGroup? _currentGroup;

  /// Ініціалізація Hive боксів
  Future<void> initialize() async {
    try {
      _profileBox = await Hive.openBox(_profileBoxName);
      _currentGroupBox = await Hive.openBox(_currentGroupBoxName);
      
      // Завантажуємо збережені дані
      await _loadProfileFromBox();
      await _loadCurrentGroupFromBox();
    } catch (e) {
      if (kDebugMode) {
        print('Помилка ініціалізації ProfileManager: $e');
      }
    }
  }

  /// Геттери для поточного профілю
  UserProfile get profile => _profile;
  String? get currentGroupId => _currentGroup?.id;
  String? get currentGroupName => _currentGroup?.name;
  String? get currentRole => _currentGroup?.role;
  String get currentUserName => _profile.fullName;
  String get currentUserInitials => _profile.initials;
  String? get currentUserEmail => _profile.email;
  String? get currentUserId => _profile.uid;

  /// Завантажити профіль з Firestore та синхронізувати локально
  Future<bool> loadAndSyncProfile() async {
    try {
      final user = Globals.firebaseAuth.currentUser;
      if (user == null) return false;

      // Отримуємо дані з Firestore
      final firestoreData = await Globals.firestoreManager.getOrCreateUserData();
      if (firestoreData == null) return false;

      // Отримуємо групи та ролі
      final groups = await Globals.firestoreManager.getUserGroups(user.email!);
      final roles = await Globals.firestoreManager.getUserRolesPerGroup(user.email!);

      // Створюємо профіль
      final updatedProfile = UserProfile(
        firstName: firestoreData['firstName'],
        lastName: firestoreData['lastName'],
        rank: firestoreData['rank'],
        position: firestoreData['position'],
        phone: firestoreData['phone'],
        email: user.email,
        uid: user.uid,
        groups: groups,
        rolesPerGroup: roles,
        lastUpdated: DateTime.now(),
      );

      // Зберігаємо локально
      await _saveProfile(updatedProfile);

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Помилка завантаження профілю: $e');
      }
      return false;
    }
  }

  /// Оновити особисті дані користувача
  Future<bool> updatePersonalInfo({
    String? firstName,
    String? lastName,
    String? rank,
    String? position,
    String? phone,
  }) async {
    try {
      final user = Globals.firebaseAuth.currentUser;
      if (user == null) return false;

      // Оновлюємо в Firestore
      await Globals.firestoreManager.updateEditableProfileFields(
        uid: user.uid,
        firstName: firstName,
        lastName: lastName,
        rank: rank,
        position: position,
        phone: phone,
      );

      // Оновлюємо локальний профіль
      final updatedProfile = _profile.copyWith(
        firstName: firstName,
        lastName: lastName,
        rank: rank,
        position: position,
        phone: phone,
        lastUpdated: DateTime.now(),
      );

      await _saveProfile(updatedProfile);
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Помилка оновлення особистих даних: $e');
      }
      return false;
    }
  }

  /// Встановити поточну групу
  Future<void> setCurrentGroup(String groupId, String groupName, [String? role]) async {
    try {
      final newGroup = CurrentGroup(
        id: groupId,
        name: groupName,
        role: role,
      );

      _currentGroup = newGroup;
      
      // Зберігаємо в Hive
      await _currentGroupBox?.put(_currentGroupKey, newGroup.toMap());
      
      if (kDebugMode) {
        print('Встановлено поточну групу: $groupName ($groupId) з роллю: $role');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Помилка встановлення поточної групи: $e');
      }
    }
  }

  /// Завантажити збережену групу з fallback
  Future<void> loadSavedGroupWithFallback(Map<String, String> allGroups) async {
    try {
      // Спробуємо завантажити збережену групу
      await _loadCurrentGroupFromBox();
      
      // Перевіряємо чи збережена група ще доступна
      if (_currentGroup != null && allGroups.containsKey(_currentGroup!.id)) {
        // Оновлюємо роль з актуальних даних
        final roles = _profile.rolesPerGroup;
        final updatedRole = roles[_currentGroup!.id];
        
        if (updatedRole != _currentGroup!.role) {
          await setCurrentGroup(_currentGroup!.id, _currentGroup!.name, updatedRole);
        }
        return;
      }

      // Якщо збереженої групи немає або вона недоступна, вибираємо першу доступну
      if (allGroups.isNotEmpty) {
        final firstGroupId = allGroups.keys.first;
        final firstGroupName = allGroups.values.first;
        final role = _profile.rolesPerGroup[firstGroupId];
        
        await setCurrentGroup(firstGroupId, firstGroupName, role);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Помилка завантаження збереженої групи: $e');
      }
    }
  }

  /// Очистити дані поточної групи
  Future<void> clearCurrentGroup() async {
    try {
      _currentGroup = null;
      await _currentGroupBox?.delete(_currentGroupKey);
    } catch (e) {
      if (kDebugMode) {
        print('Помилка очищення поточної групи: $e');
      }
    }
  }

  /// Очистити всі дані профілю
  Future<void> clearProfile() async {
    try {
      _profile = UserProfile.empty;
      _currentGroup = null;
      
      await _profileBox?.clear();
      await _currentGroupBox?.clear();
    } catch (e) {
      if (kDebugMode) {
        print('Помилка очищення профілю: $e');
      }
    }
  }

  /// Перевірити чи потрібно синхронізувати профіль
  bool needsSync() {
    if (_profile.lastUpdated == null) return true;
    final timeSinceUpdate = DateTime.now().difference(_profile.lastUpdated!);
    return timeSinceUpdate.inHours > 1; // Синхронізуємо кожну годину
  }

  /// Отримати список доступних груп користувача
  Map<String, String> getAvailableGroups() {
    final groups = <String, String>{};
    for (final groupId in _profile.groups) {
      // Тут можна додати логіку отримання назв груп
      // Поки що використовуємо ID як назву
      groups[groupId] = groupId;
    }
    return groups;
  }

  /// Перевірити чи користувач має роль admin у поточній групі
  bool get isCurrentGroupAdmin {
    return _currentGroup?.role?.toLowerCase() == 'admin';
  }

  /// Перевірити чи користувач має роль editor у поточній групі
  bool get isCurrentGroupEditor {
    final role = _currentGroup?.role?.toLowerCase();
    return role == 'admin' || role == 'editor';
  }

  /// Отримати роль у конкретній групі
  String? getRoleInGroup(String groupId) {
    return _profile.rolesPerGroup[groupId];
  }

  // ===== ПРИВАТНІ МЕТОДИ =====

  /// Завантажити профіль з Hive
  Future<void> _loadProfileFromBox() async {
    try {
      final data = _profileBox?.get(_profileKey);
      if (data != null) {
        _profile = UserProfile.fromMap(Map<String, dynamic>.from(data));
      }
    } catch (e) {
      if (kDebugMode) {
        print('Помилка завантаження профілю з Hive: $e');
      }
    }
  }

  /// Завантажити поточну групу з Hive
  Future<void> _loadCurrentGroupFromBox() async {
    try {
      final data = _currentGroupBox?.get(_currentGroupKey);
      if (data != null) {
        _currentGroup = CurrentGroup.fromMap(Map<String, dynamic>.from(data));
      }
    } catch (e) {
      if (kDebugMode) {
        print('Помилка завантаження поточної групи з Hive: $e');
      }
    }
  }

  /// Зберегти профіль у Hive
  Future<void> _saveProfile(UserProfile profile) async {
    try {
      _profile = profile;
      await _profileBox?.put(_profileKey, profile.toMap());
    } catch (e) {
      if (kDebugMode) {
        print('Помилка збереження профілю у Hive: $e');
      }
    }
  }

  /// Закрити Hive бокси
  Future<void> dispose() async {
    try {
      await _profileBox?.close();
      await _currentGroupBox?.close();
    } catch (e) {
      if (kDebugMode) {
        print('Помилка закриття Hive боксів: $e');
      }
    }
  }

  @override
  String toString() {
    return 'ProfileManager(profile: ${_profile.fullName}, currentGroup: ${_currentGroup?.name})';
  }
}