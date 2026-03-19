import "dart:async";
import "dart:convert";

import "package:cloud_firestore/cloud_firestore.dart";
import "package:firebase_auth/firebase_auth.dart";
import "package:firebase_messaging/firebase_messaging.dart";
import "package:flutter/foundation.dart";
import "package:flutter_local_notifications/flutter_local_notifications.dart";

import "../theme/app_theme.dart";

enum PushNavigationKind { groupNotification, lesson }

class PushNavigationRequest {
  const PushNavigationRequest({
    required this.kind,
    required this.title,
    required this.body,
    this.groupId,
    this.lessonId,
    this.notificationId,
  });

  final PushNavigationKind kind;
  final String title;
  final String body;
  final String? groupId;
  final String? lessonId;
  final String? notificationId;

  bool get isLesson =>
      kind == PushNavigationKind.lesson && lessonId != null && lessonId != "";

  Map<String, String> toMessageData() {
    return {
      "kind": kind == PushNavigationKind.lesson
          ? "lesson_acknowledgement"
          : "group_notification",
      "title": title,
      "body": body,
      if (groupId != null && groupId!.isNotEmpty) "groupId": groupId!,
      if (lessonId != null && lessonId!.isNotEmpty) "lessonId": lessonId!,
      if (notificationId != null && notificationId!.isNotEmpty)
        "notificationId": notificationId!,
    };
  }

  String toLocalNotificationPayload() {
    return jsonEncode(toMessageData());
  }

  static PushNavigationRequest? fromLocalNotificationPayload(String? payload) {
    if (payload == null || payload.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map) {
        return null;
      }
      return fromMessageData(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  static PushNavigationRequest? fromRemoteMessage(RemoteMessage message) {
    final data = Map<String, dynamic>.from(message.data);
    if (data.isNotEmpty) {
      return fromMessageData(
        data,
        fallbackTitle: message.notification?.title,
        fallbackBody: message.notification?.body,
      );
    }

    final title = (message.notification?.title ?? "").trim();
    final body = (message.notification?.body ?? "").trim();
    if (title.isEmpty && body.isEmpty) {
      return null;
    }

    return PushNavigationRequest(
      kind: PushNavigationKind.groupNotification,
      title: title,
      body: body,
    );
  }

  static PushNavigationRequest? fromMessageData(
    Map<String, dynamic> raw, {
    String? fallbackTitle,
    String? fallbackBody,
  }) {
    final kindValue = (raw["kind"] ?? "").toString().trim();
    final groupId = (raw["groupId"] ?? "").toString().trim();
    final lessonId = (raw["lessonId"] ?? "").toString().trim();
    final notificationId = (raw["notificationId"] ?? "").toString().trim();
    final title = ((raw["title"] ?? fallbackTitle) ?? "").toString().trim();
    final body = ((raw["body"] ?? fallbackBody) ?? "").toString().trim();

    final kind = kindValue == "lesson_acknowledgement" || lessonId.isNotEmpty
        ? PushNavigationKind.lesson
        : PushNavigationKind.groupNotification;

    if (title.isEmpty && body.isEmpty && groupId.isEmpty && lessonId.isEmpty) {
      return null;
    }

    return PushNavigationRequest(
      kind: kind,
      title: title.isNotEmpty
          ? title
          : kind == PushNavigationKind.lesson
          ? "Потрібно ознайомитись із заняттям"
          : "Нове сповіщення",
      body: body,
      groupId: groupId.isNotEmpty ? groupId : null,
      lessonId: lessonId.isNotEmpty ? lessonId : null,
      notificationId: notificationId.isNotEmpty ? notificationId : null,
    );
  }
}

class PushNotificationsService extends ChangeNotifier {
  static const String androidChannelId = "itacs_high_importance_notifications";
  static const String androidChannelName = "iTACS Push";
  static const String androidChannelDescription =
      "Сповіщення про нові заняття та оголошення";

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;
  StreamSubscription<RemoteMessage>? _messageOpenedSubscription;

  bool _initialized = false;
  bool _initializing = false;
  bool _localNotificationsInitialized = false;
  String? _registeredToken;
  PushNavigationRequest? _pendingNavigationRequest;

  PushNavigationRequest? get pendingNavigationRequest =>
      _pendingNavigationRequest;

  bool get isSupportedPlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> initialize() async {
    if (!isSupportedPlatform || _initialized || _initializing) {
      return;
    }

    _initializing = true;
    try {
      await _initializeLocalNotifications();
      await _registerFirebaseListeners();

      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      await _syncTokenWithFirestore(settings);

      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _setPendingNavigationRequest(
          PushNavigationRequest.fromRemoteMessage(initialMessage),
        );
      }

      _initialized = true;
    } finally {
      _initializing = false;
    }
  }

  Future<void> handleSignOut() async {
    if (!isSupportedPlatform) {
      _resetSessionState();
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    final token = _registeredToken ?? await _messaging.getToken();

    if (user != null && token != null && token.isNotEmpty) {
      await _deleteDeviceTokenDocument(user.uid, token);
    }

    await _tokenRefreshSubscription?.cancel();
    await _foregroundMessageSubscription?.cancel();
    await _messageOpenedSubscription?.cancel();

    _tokenRefreshSubscription = null;
    _foregroundMessageSubscription = null;
    _messageOpenedSubscription = null;

    _resetSessionState();
  }

  void clearPendingNavigationRequest() {
    if (_pendingNavigationRequest == null) {
      return;
    }

    _pendingNavigationRequest = null;
    notifyListeners();
  }

  Future<void> _initializeLocalNotifications() async {
    if (_localNotificationsInitialized) {
      return;
    }

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings("@mipmap/ic_launcher"),
    );

    await _localNotifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (response) {
        _setPendingNavigationRequest(
          PushNavigationRequest.fromLocalNotificationPayload(response.payload),
        );
      },
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        androidChannelId,
        androidChannelName,
        description: androidChannelDescription,
        importance: Importance.high,
      ),
    );

    _localNotificationsInitialized = true;
  }

  Future<void> _registerFirebaseListeners() async {
    _tokenRefreshSubscription ??= _messaging.onTokenRefresh.listen(
      _handleTokenRefresh,
    );

    _foregroundMessageSubscription ??= FirebaseMessaging.onMessage.listen(
      _handleForegroundMessage,
    );

    _messageOpenedSubscription ??= FirebaseMessaging.onMessageOpenedApp.listen((
      message,
    ) {
      _setPendingNavigationRequest(
        PushNavigationRequest.fromRemoteMessage(message),
      );
    });
  }

  Future<void> _syncTokenWithFirestore(NotificationSettings settings) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    final token = await _messaging.getToken();
    if (token == null || token.isEmpty) {
      return;
    }

    _registeredToken = token;

    final authorizationStatus = settings.authorizationStatus;
    final notificationsEnabled =
        authorizationStatus == AuthorizationStatus.authorized ||
        authorizationStatus == AuthorizationStatus.provisional;

    await _firestore
        .collection("users")
        .doc(user.uid)
        .collection("devices")
        .doc(token)
        .set({
          "token": token,
          "platform": "android",
          "lastSeenAt": FieldValue.serverTimestamp(),
          "notificationsEnabled": notificationsEnabled,
          "appVersion": AppTheme.appVersion,
        }, SetOptions(merge: true));
  }

  Future<void> _handleTokenRefresh(String nextToken) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || nextToken.trim().isEmpty) {
      return;
    }

    final previousToken = _registeredToken;
    _registeredToken = nextToken;

    if (previousToken != null &&
        previousToken.isNotEmpty &&
        previousToken != nextToken) {
      await _deleteDeviceTokenDocument(user.uid, previousToken);
    }

    final settings = await _messaging.getNotificationSettings();
    await _syncTokenWithFirestore(settings);
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final request = PushNavigationRequest.fromRemoteMessage(message);
    if (request == null) {
      return;
    }

    final notificationId =
        message.messageId?.hashCode ??
        request.toLocalNotificationPayload().hashCode;

    await _localNotifications.show(
      id: notificationId,
      title: request.title,
      body: request.body.isNotEmpty ? request.body : null,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          androidChannelId,
          androidChannelName,
          channelDescription: androidChannelDescription,
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      payload: request.toLocalNotificationPayload(),
    );
  }

  Future<void> _deleteDeviceTokenDocument(String uid, String token) async {
    try {
      await _firestore
          .collection("users")
          .doc(uid)
          .collection("devices")
          .doc(token)
          .delete();
    } catch (_) {
      // Якщо документа вже немає, це не повинно блокувати logout.
    }
  }

  void _setPendingNavigationRequest(PushNavigationRequest? request) {
    if (request == null) {
      return;
    }

    _pendingNavigationRequest = request;
    notifyListeners();
  }

  void _resetSessionState() {
    _initialized = false;
    _initializing = false;
    _registeredToken = null;
    _pendingNavigationRequest = null;
    notifyListeners();
  }
}
