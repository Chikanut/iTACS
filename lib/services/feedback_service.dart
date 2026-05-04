import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

enum FeedbackCategory { bug, feature, other }

enum FeedbackPriority { low, medium, high }

class AppFeedback {
  final FeedbackCategory category;
  final FeedbackPriority? priority;
  final String description;
  final String userEmail;
  final String userName;
  final String userId;
  final String appVersion;
  final String platform;
  final DateTime createdAt;
  final String status;

  const AppFeedback({
    required this.category,
    this.priority,
    required this.description,
    required this.userEmail,
    required this.userName,
    required this.userId,
    required this.appVersion,
    required this.platform,
    required this.createdAt,
    this.status = 'new',
  });

  Map<String, dynamic> toMap() => {
    'category': category.name,
    'priority': priority?.name,
    'description': description,
    'userEmail': userEmail,
    'userName': userName,
    'userId': userId,
    'appVersion': appVersion,
    'platform': platform,
    'createdAt': Timestamp.fromDate(createdAt),
    'status': status,
  };
}

class FeedbackService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> submitFeedback({
    required FeedbackCategory category,
    FeedbackPriority? priority,
    required String description,
    required String appVersion,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Користувач не авторизований');

    final feedback = AppFeedback(
      category: category,
      priority: category == FeedbackCategory.bug ? (priority ?? FeedbackPriority.medium) : null,
      description: description.trim(),
      userEmail: user.email ?? '',
      userName: user.displayName ?? user.email ?? '',
      userId: user.uid,
      appVersion: appVersion,
      platform: _currentPlatform,
      createdAt: DateTime.now(),
    );

    await _firestore.collection('app_feedback').add(feedback.toMap());
    debugPrint('✅ Feedback submitted: ${feedback.category.name}');
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
