// lib/mixins/loading_state_mixin.dart
import 'package:flutter/material.dart';

mixin LoadingStateMixin<T extends StatefulWidget> on State<T> {
  final Map<String, bool> _loadingStates = {};
  
  bool isLoading(String key) => _loadingStates[key] ?? false;
  
  void setLoading(String key, bool loading) {
    if (mounted) {
      setState(() {
        _loadingStates[key] = loading;
      });
    }
  }
  
  void clearLoading(String key) {
    if (mounted) {
      setState(() {
        _loadingStates.remove(key);
      });
    }
  }
  
  void clearAllLoading() {
    if (mounted) {
      setState(() {
        _loadingStates.clear();
      });
    }
  }
  
  Future<T> withLoading<T>(String key, Future<T> Function() operation) async {
    if (isLoading(key)) {
      throw Exception('Операція вже виконується');
    }
    
    try {
      setLoading(key, true);
      return await operation();
    } finally {
      clearLoading(key);
    }
  }
}