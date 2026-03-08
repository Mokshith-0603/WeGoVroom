import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'wegovroom_notifications',
    'WeGoVroom Notifications',
    description: 'Notifications for trip updates and admin alerts',
    importance: Importance.high,
  );

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _requestPermission();
    await _initializeLocalNotifications();
    await _configureForegroundPresentation();

    final token = await _messaging.getToken();
    await _saveTokenForCurrentUser(token);

    _messaging.onTokenRefresh.listen(_saveTokenForCurrentUser);
    _auth.authStateChanges().listen((_) async {
      final currentToken = await _messaging.getToken();
      await _saveTokenForCurrentUser(currentToken);
    });

    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('Notification tapped: ${message.messageId}');
    });

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('App opened from terminated state: ${initialMessage.messageId}');
    }

    _initialized = true;
  }

  Future<void> syncCurrentUserToken() async {
    if (kIsWeb) return;
    final token = await _messaging.getToken();
    await _saveTokenForCurrentUser(token);
  }

  Future<void> _requestPermission() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
  }

  Future<void> _configureForegroundPresentation() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(settings);

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_channel);
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  Future<void> _saveTokenForCurrentUser(String? token) async {
    final user = _auth.currentUser;
    if (user == null || token == null || token.isEmpty) return;

    final userRef = _db.collection('users').doc(user.uid);
    final userDoc = await userRef.get();
    if (!userDoc.exists) return;

    await userRef.set({
      'fcmTokens': FieldValue.arrayUnion([token]),
      'lastFcmToken': token,
      'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      'lastSeenPlatform': Platform.operatingSystem,
    }, SetOptions(merge: true));
  }
}
