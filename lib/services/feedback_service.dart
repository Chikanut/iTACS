import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

enum FeedbackCategory { bug, feature, other }

enum FeedbackPriority { low, medium, high }

class FeedbackService {
  static const String _functionsRegion = 'us-central1';

  FirebaseFunctions get _functions => FirebaseFunctions.instance;

  Future<void> submitFeedback({
    required FeedbackCategory category,
    FeedbackPriority? priority,
    required String description,
    required String appVersion,
  }) async {
    await _callFeedbackFunction({
      'category': category.name,
      'priority': category == FeedbackCategory.bug
          ? (priority ?? FeedbackPriority.medium).name
          : null,
      'description': description.trim(),
      'appVersion': appVersion,
      'platform': _currentPlatform,
    });
    debugPrint('✅ Feedback submitted: ${category.name}');
  }

  bool get _supportsNativeFunctions {
    if (kIsWeb) {
      return true;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return true;
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      default:
        return false;
    }
  }

  Future<void> _callFeedbackFunction(Map<String, dynamic> payload) async {
    if (_supportsNativeFunctions) {
      try {
        final callable = _functions.httpsCallable('submitFeedback');
        await callable.call(payload);
        return;
      } on MissingPluginException catch (_) {
        debugPrint(
          'FeedbackService: cloud_functions plugin unavailable, falling back to HTTP',
        );
      }
    }

    await _callFeedbackViaHttp(payload);
  }

  Future<void> _callFeedbackViaHttp(Map<String, dynamic> payload) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      throw Exception('Потрібна авторизація для надсилання відгуку');
    }

    final idToken = await currentUser.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw Exception('Не вдалося отримати токен авторизації для відгуку');
    }

    final projectId = Firebase.app().options.projectId;
    final uri = Uri.parse(
      'https://$_functionsRegion-$projectId.cloudfunctions.net/submitFeedback',
    );

    final response = await http.post(
      uri,
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode(<String, dynamic>{'data': payload}),
    );

    _parseCallableHttpResponse(response);
  }

  void _parseCallableHttpResponse(http.Response response) {
    Map<String, dynamic>? body;
    if (response.bodyBytes.isNotEmpty) {
      final decodedBody = utf8.decode(response.bodyBytes);
      final jsonBody = jsonDecode(decodedBody);
      body = jsonBody is Map<String, dynamic>
          ? jsonBody
          : Map<String, dynamic>.from(jsonBody as Map);
    }

    final error = body?['error'];
    if (error != null) {
      final errorMap = Map<String, dynamic>.from(error as Map);
      final message = (errorMap['message'] ?? 'Помилка надсилання відгуку')
          .toString();
      throw Exception(message);
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('HTTP ${response.statusCode} під час надсилання відгуку');
    }
  }

  String get _currentPlatform {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      default:
        return 'unknown';
    }
  }
}
