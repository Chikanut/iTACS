import 'package:shared_preferences/shared_preferences.dart';
import '../globals.dart';

class ProfileManager {
  String? _currentGroupId;
  String? _currentGroupName;
  String? _currentRole;

  String? get currentGroupId => _currentGroupId;
  String? get currentGroupName => _currentGroupName;
  String? get currentRole => _currentRole;

  Future<void> setCurrentGroup(String groupId, String groupName, [String? role]) async {
    _currentGroupId = groupId;
    _currentGroupName = groupName;
    _currentRole = role;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currentGroupId', groupId);
    await prefs.setString('currentGroupName', groupName);
    if (role != null) {
      await prefs.setString('currentGroupRole', role);
    }
  }

  Future<void> loadSavedGroupWithFallback(Map<String, String> allGroups) async {
  final prefs = await SharedPreferences.getInstance();
  final savedId = prefs.getString('currentGroupId');
  final savedName = prefs.getString('currentGroupName');

  if (savedId != null && allGroups.containsKey(savedId)) {
    _currentGroupId = savedId;
    _currentGroupName = savedName ?? allGroups[savedId];

    // 🔄 Завантажити роль з Firestore
    final email = Globals.firebaseAuth.currentUser?.email;
    if (email != null) {
      final roles = await Globals.firestoreManager.getUserRolesPerGroup(email);
      _currentRole = roles[_currentGroupId];
      await prefs.setString('currentGroupRole', _currentRole ?? '');
    }
  } else if (allGroups.isNotEmpty) {
    _currentGroupId = allGroups.keys.first;
    _currentGroupName = allGroups.values.first;

    final email = Globals.firebaseAuth.currentUser?.email;
    if (email != null) {
      final roles = await Globals.firestoreManager.getUserRolesPerGroup(email);
      _currentRole = roles[_currentGroupId];
    }

    await setCurrentGroup(_currentGroupId!, _currentGroupName!, _currentRole);
  }
}

  void clearGroup() async {
    _currentGroupId = null;
    _currentGroupName = null;
    _currentRole = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('currentGroupId');
    await prefs.remove('currentGroupName');
    await prefs.remove('currentGroupRole');
  }
}
