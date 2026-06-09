import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../features/messaging/data/dm_navigation_intent.dart';

class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  final StreamController<DmNavigationIntent> _dmNavigationController =
      StreamController<DmNavigationIntent>.broadcast();

  /// Emits when the user taps a direct-message notification (foreground tap or cold start).
  Stream<DmNavigationIntent> get dmNavigationStream =>
      _dmNavigationController.stream;

  /// Lazily resolved so a logged-out app / tests never touch [FirebaseMessaging]
  /// before [Firebase.initializeApp], and [clearCurrentUserToken] can no-op first.
  FirebaseMessaging get _messaging => FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  String? _activeUid;
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onMessageOpenedSub;
  String _preferredLanguage = 'el';
  Future<void> _tokenLifecycle = Future<void>.value();

  static const AndroidNotificationChannel _highPriorityChannel =
      AndroidNotificationChannel(
        'scholilink_high_priority',
        'ScholiLink Alerts',
        description: 'Messages and important study reminders',
        importance: Importance.high,
      );

  Future<void> _enqueueTokenLifecycle(Future<void> Function() action) {
    final next = _tokenLifecycle.then((_) => action());
    _tokenLifecycle = next.catchError((_) {});
    return next;
  }

  Future<void> initializeForUser({
    required String uid,
    required String preferredLanguage,
  }) {
    return _enqueueTokenLifecycle(() async {
      _preferredLanguage = preferredLanguage;

      // Web push requires a service worker + VAPID key; mobile-only for now.
      if (kIsWeb) return;

      // Prevent repeated side effects when auth/user profile streams emit unchanged users.
      if (_activeUid == uid &&
          _tokenRefreshSub != null &&
          _onMessageSub != null) {
        return;
      }

      if (_activeUid != null && _activeUid != uid) {
        await _tokenRefreshSub?.cancel();
        _tokenRefreshSub = null;
        await _onMessageSub?.cancel();
        _onMessageSub = null;
        await _onMessageOpenedSub?.cancel();
        _onMessageOpenedSub = null;
        await _removeTokenForUid(_activeUid!);
      } else if (_activeUid != uid) {
        await _tokenRefreshSub?.cancel();
        _tokenRefreshSub = null;
        await _onMessageSub?.cancel();
        _onMessageSub = null;
        await _onMessageOpenedSub?.cancel();
        _onMessageOpenedSub = null;
      }

      if (!_initialized) {
        await _initializeCore();
      }

      _activeUid = uid;
      await _requestPermissionIfNeeded();
      await _syncToken(uid);
      await _updateUserTimezone(uid);

      _tokenRefreshSub?.cancel();
      _tokenRefreshSub = _messaging.onTokenRefresh.listen((token) async {
        final activeUid = _activeUid;
        if (activeUid == null) return;
        await _saveToken(uid: activeUid, token: token);
      });

      _onMessageSub = FirebaseMessaging.onMessage.listen((message) async {
        if (!_isMessageForActiveUser(message)) return;
        await _showForegroundNotification(
          title:
              message.notification?.title ??
              (_preferredLanguage == 'el' ? 'Νέα ενημέρωση' : 'New update'),
          body:
              message.notification?.body ??
              (_preferredLanguage == 'el'
                  ? 'Άνοιξε την εφαρμογή για λεπτομέρειες.'
                  : 'Open the app for details.'),
        );
      });

      _onMessageOpenedSub?.cancel();
      _onMessageOpenedSub =
          FirebaseMessaging.onMessageOpenedApp.listen(_emitDmNavigationIfAny);

      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _emitDmNavigationIfAny(initialMessage);
      }
    });
  }

  bool _isMessageForActiveUser(RemoteMessage message) {
    final activeUid = _activeUid;
    if (activeUid == null) return false;
    final recipientUid = message.data['recipientUid']?.trim();
    if (recipientUid == null || recipientUid.isEmpty) {
      // Backward compatibility for in-flight pushes without recipientUid.
      return true;
    }
    return recipientUid == activeUid;
  }

  void _emitDmNavigationIfAny(RemoteMessage message) {
    if (!_isMessageForActiveUser(message)) return;

    final data = message.data;
    if (data['type'] != 'direct_message') return;
    final chatId = data['chatId']?.trim();
    final friendId = data['senderId']?.trim();
    if (chatId == null ||
        chatId.isEmpty ||
        friendId == null ||
        friendId.isEmpty) {
      return;
    }
    _dmNavigationController.add(
      DmNavigationIntent(chatId: chatId, friendId: friendId),
    );
  }

  Future<void> clearCurrentUserToken() {
    return _enqueueTokenLifecycle(() async {
      if (kIsWeb) {
        _activeUid = null;
        return;
      }
      final uid = _activeUid;
      _activeUid = null;
      await _tokenRefreshSub?.cancel();
      _tokenRefreshSub = null;
      await _onMessageSub?.cancel();
      _onMessageSub = null;
      await _onMessageOpenedSub?.cancel();
      _onMessageOpenedSub = null;
      if (uid != null) {
        await _removeTokenForUid(uid);
      }
    });
  }

  Future<void> _removeTokenForUid(String uid) async {
    final token = await _messaging.getToken();
    if (token == null || token.isEmpty) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('device_tokens')
        .doc(token)
        .delete()
        .catchError((_) {});
  }

  Future<void> _initializeCore() async {
    final androidInit = const AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    await _localNotifications.initialize(
      InitializationSettings(android: androidInit),
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_highPriorityChannel);

    _initialized = true;
  }

  Future<void> _requestPermissionIfNeeded() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (kDebugMode && settings.authorizationStatus != AuthorizationStatus.denied) {
      debugPrint('FCM permission status: ${settings.authorizationStatus}');
    }
  }

  Future<void> _syncToken(String uid) async {
    final token = await _messaging.getToken();
    if (token == null || token.isEmpty) return;
    await _saveToken(uid: uid, token: token);
  }

  Future<void> _saveToken({required String uid, required String token}) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('device_tokens')
        .doc(token)
        .set({
          'token': token,
          'platform': defaultTargetPlatform.name,
          'updatedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<void> _updateUserTimezone(String uid) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'timezone': DateTime.now().timeZoneName,
      'timezoneOffsetMinutes': DateTime.now().timeZoneOffset.inMinutes,
      'timezoneUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _showForegroundNotification({
    required String title,
    required String body,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch.remainder(2147483647);
    await _localNotifications.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'scholilink_high_priority',
          'ScholiLink Alerts',
          channelDescription: 'Messages and important study reminders',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }
}
