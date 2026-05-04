import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

enum FeedbackCategory { bug, feature, other }

enum FeedbackPriority { low, medium, high }


class FeedbackService {
  final _functions = FirebaseFunctions.instance;

  Future<void> submitFeedback({
    required FeedbackCategory category,
    FeedbackPriority? priority,
    required String description,
    required String appVersion,
  }) async {
    final callable = _functions.httpsCallable('submitFeedback');
    await callable.call({
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
