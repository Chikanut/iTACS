import 'package:flutter/foundation.dart';

class AppRuntimeState extends ChangeNotifier {
  bool _isReadOnlyOffline = false;
  DateTime? _lastSuccessfulSyncAt;

  bool get isReadOnlyOffline => _isReadOnlyOffline;
  DateTime? get lastSuccessfulSyncAt => _lastSuccessfulSyncAt;

  void updateSessionState({
    required bool isReadOnlyOffline,
    DateTime? lastSuccessfulSyncAt,
  }) {
    final hasChanges =
        _isReadOnlyOffline != isReadOnlyOffline ||
        _lastSuccessfulSyncAt != lastSuccessfulSyncAt;
    if (!hasChanges) {
      return;
    }

    _isReadOnlyOffline = isReadOnlyOffline;
    _lastSuccessfulSyncAt = lastSuccessfulSyncAt;
    notifyListeners();
  }

  void clearSessionState() {
    if (!_isReadOnlyOffline && _lastSuccessfulSyncAt == null) {
      return;
    }

    _isReadOnlyOffline = false;
    _lastSuccessfulSyncAt = null;
    notifyListeners();
  }
}
