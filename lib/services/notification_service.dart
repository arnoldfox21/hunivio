import 'dart:async';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../models/chat_message.dart';
import '../screens/kost_chat_screen.dart';
import 'api_service.dart';
import 'auth_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } catch (_) {}
}

class NotificationService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _chatChannel =
      AndroidNotificationChannel(
    'hunivio_chat_channel',
    'Pesan Chat HuniVio',
    description: 'Notifikasi pesan masuk dari penyewa dan pemilik properti.',
    importance: Importance.high,
    playSound: true,
  );

  static bool _initialized = false;
  static io.Socket? _userSocket;
  static int? _connectedUserId;
  static int? activeChatKostId;
  static int? activeGroupKostId;
  static StreamSubscription<String>? _tokenRefreshSub;
  static final Set<int> _notifiedMessageIds = <int>{};

  /// Counter untuk memicu refresh inbox / badge unread secara reaktif
  static final ValueNotifier<int> inboxEventCounter = ValueNotifier<int>(0);
  static final ValueNotifier<int> totalUnreadCount = ValueNotifier<int>(0);

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // 1. Setup Local Notifications
    try {
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings();
      const initSettings = InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      );
      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (details) {
          if (details.payload != null && details.payload!.isNotEmpty) {
            try {
              final data =
                  jsonDecode(details.payload!) as Map<String, dynamic>;
              final kostId = int.tryParse('${data['kostId']}');
              if (kostId != null && kostId > 0) {
                openChatFromNotification(kostId);
              }
            } catch (_) {}
          }
        },
      );

      final androidPlugin =
          _localNotifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(_chatChannel);
      await androidPlugin?.requestNotificationsPermission();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _requestAndroidNotificationPermission();
      });
    } catch (e) {
      debugPrint('Local notification init error: $e');
    }

    // 2. Setup Firebase & FCM
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final data = message.data;
        final kostId = int.tryParse('${data['kostId']}');
        final senderId = int.tryParse('${data['senderId']}');
        final receiverId = int.tryParse('${data['receiverId']}');
        final currentId = AuthService.currentUser?.id;

        // Pastikan notifikasi hanya tampil jika user sedang login & memang penerimanya
        if (currentId == null) return;
        if (receiverId != null && receiverId != currentId) return;
        if (senderId == currentId) return;
        if (kostId != null && activeChatKostId == kostId) return;

        final messageId = int.tryParse('${data['messageId']}') ?? kostId;
        final title =
            message.notification?.title ?? data['senderName'] ?? 'Pesan Baru';
        final body = message.notification?.body ?? 'Anda mendapat pesan baru.';
        if (kostId != null && kostId > 0) {
          showChatNotification(
            kostId: kostId,
            title: title,
            body: body,
            messageId: messageId,
          );
          refreshUnreadCount();
        }
      });

      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        final data = message.data;
        final currentId = AuthService.currentUser?.id;
        final receiverId = int.tryParse('${data['receiverId']}');
        if (currentId == null) return;
        if (receiverId != null && receiverId != currentId) return;
        final kostId = int.tryParse('${data['kostId']}');
        if (kostId != null && kostId > 0) {
          openChatFromNotification(kostId);
        }
      });

      final initialMsg = await messaging.getInitialMessage();
      if (initialMsg != null) {
        final data = initialMsg.data;
        final currentId = AuthService.currentUser?.id;
        final receiverId = int.tryParse('${data['receiverId']}');
        final kostId = int.tryParse('${data['kostId']}');
        if (currentId != null &&
            (receiverId == null || receiverId == currentId) &&
            kostId != null &&
            kostId > 0) {
          Future.delayed(const Duration(milliseconds: 600), () {
            openChatFromNotification(kostId);
          });
        }
      }
    } catch (e) {
      debugPrint('Firebase messaging init skipped/error: $e');
    }

    // 3. Sinkronkan user socket & FCM token otomatis saat status login berubah
    AuthService.currentUserNotifier.addListener(_onAuthChanged);
    _onAuthChanged();
  }

  static Future<void> _requestAndroidNotificationPermission() async {
    try {
      final androidPlugin =
          _localNotifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission();
    } catch (_) {}
  }

  static void _onAuthChanged() {
    final user = AuthService.currentUser;
    if (user == null) {
      disconnectUserSocket();
      _notifiedMessageIds.clear();
      totalUnreadCount.value = 0;
      return;
    }
    _requestAndroidNotificationPermission();
    connectUserSocket(user.id);
    syncFcmToken(user.id);
    refreshUnreadCount();
  }

  static Future<void> syncFcmToken(int userId) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null &&
          token.trim().isNotEmpty &&
          AuthService.currentUser?.id == userId) {
        await ApiService.updateUserFcmToken(
          userId: userId,
          fcmToken: token.trim(),
        );
      }
      await _tokenRefreshSub?.cancel();
      _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen((t) {
        if (AuthService.currentUser?.id == userId && t.trim().isNotEmpty) {
          ApiService.updateUserFcmToken(userId: userId, fcmToken: t.trim());
        }
      });
    } catch (e) {
      debugPrint('Sync FCM token error: $e');
    }
  }

  static void connectUserSocket(int userId) {
    if (_connectedUserId == userId && _userSocket?.connected == true) {
      return;
    }
    disconnectUserSocket();
    _connectedUserId = userId;

    try {
      final socket = io.io(
        ApiService.socketBaseUrl,
        io.OptionBuilder()
            .setTransports(['websocket'])
            .disableAutoConnect()
            .build(),
      );

      socket.onConnect((_) {
        socket.emit('joinUserRoom', {'userId': userId});
      });

      socket.on('newMessage', (data) {
        if (data == null) return;
        final msg = ChatMessage.fromJson(Map<String, dynamic>.from(data as Map));
        inboxEventCounter.value++;
        refreshUnreadCount();

        if (msg.senderId != userId && activeChatKostId != msg.kostId) {
          showChatNotification(
            kostId: msg.kostId,
            title: msg.senderName,
            body: msg.message,
            messageId: msg.id,
          );
        }
      });

      socket.on('inboxUpdated', (_) {
        inboxEventCounter.value++;
        refreshUnreadCount();
      });

      socket.on('messageStatusUpdated', (_) {
        inboxEventCounter.value++;
        refreshUnreadCount();
      });

      socket.on('newGroupNotification', (data) {
        if (data == null) return;
        final map = Map<String, dynamic>.from(data as Map);
        final kostId = int.tryParse('${map['kostId']}') ?? 0;
        final senderId = int.tryParse('${map['senderId']}') ?? 0;
        final senderName = map['senderName']?.toString() ?? 'Grup Penghuni';
        final message = map['message']?.toString() ?? '';
        final messageId = int.tryParse('${map['messageId']}') ?? kostId;
        inboxEventCounter.value++;
        if (senderId != userId &&
            kostId > 0 &&
            activeGroupKostId != kostId) {
          showChatNotification(
            kostId: kostId,
            title: 'Grup Penghuni • $senderName',
            body: message,
            messageId: messageId,
          );
        }
      });

      socket.connect();
      _userSocket = socket;
    } catch (_) {}
  }

  static void disconnectUserSocket() {
    _userSocket?.dispose();
    _userSocket = null;
    _connectedUserId = null;
  }

  static Future<void> refreshUnreadCount() async {
    final user = AuthService.currentUser;
    if (user == null) {
      totalUnreadCount.value = 0;
      return;
    }
    try {
      final convs = await ApiService.fetchChatConversations(user.id);
      int sum = 0;
      for (final c in convs) {
        sum += c.unreadCount;
      }
      totalUnreadCount.value = sum;
    } catch (_) {}
  }

  static Future<void> showChatNotification({
    required int kostId,
    required String title,
    required String body,
    int? messageId,
  }) async {
    if (messageId != null && messageId > 0) {
      if (_notifiedMessageIds.contains(messageId)) return;
      _notifiedMessageIds.add(messageId);
      if (_notifiedMessageIds.length > 100) {
        _notifiedMessageIds.remove(_notifiedMessageIds.first);
      }
    }
    try {
      const androidDetails = AndroidNotificationDetails(
        'hunivio_chat_channel',
        'Pesan Chat HuniVio',
        channelDescription:
            'Notifikasi pesan masuk dari penyewa dan pemilik properti.',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );
      const iosDetails = DarwinNotificationDetails();
      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.show(
        messageId ?? kostId,
        title,
        body,
        details,
        payload: jsonEncode({'kostId': kostId}),
      );
    } catch (_) {}
  }

  static Future<void> openChatFromNotification(int kostId) async {
    final kost = await ApiService.fetchKostById(kostId);
    if (kost == null) return;
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => KostChatScreen(kost: kost),
      ),
    );
  }
}
