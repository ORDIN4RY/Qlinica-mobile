import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'notification_service.dart';

/// Top-level background message handler for FCM.
/// Must be outside the class and must be top-level/static.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Tidak perlu memanggil local notification di sini karena OS Android
  // secara otomatis menampilkan push notification jika ada objek 'notification' di payload.
  if (kDebugMode) {
    print("FCM Background Message: ${message.messageId}");
  }
}

class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  bool _initialized = false;

  /// Inisialisasi Firebase Messaging
  Future<void> init() async {
    if (_initialized) return;

    // Set background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Minta izin notifikasi (terutama penting untuk iOS dan Android 13+)
    await requestPermission();

    // Setup foreground message handler (saat aplikasi sedang aktif dibuka)
    _setupForegroundListener();

    // Setup tap handler (saat notifikasi di-tap oleh user dari background/terminated)
    _setupNotificationTapListener();

    _initialized = true;
    if (kDebugMode) {
      print("FCM Service initialized successfully.");
    }
  }

  /// Meminta izin notifikasi dari user
  Future<void> requestPermission() async {
    try {
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (kDebugMode) {
        print('User granted permission: ${settings.authorizationStatus}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error requesting FCM permission: $e');
      }
    }
  }

  /// Mengambil FCM Token dari perangkat ini dan mengirimkannya ke Laravel server
  Future<void> getAndSendToken() async {
    try {
      // Hanya kirim token jika user sudah login
      final isLoggedIn = await ApiService.instance.isLoggedIn;
      if (!isLoggedIn) return;

      // Ambil data user yang sedang login untuk membedakan cache antar akun
      final user = await ApiService.instance.getSavedUser();
      if (user == null) return;

      // Ambil token dari Firebase
      String? token = await _messaging.getToken();
      if (token == null) return;

      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'last_sent_fcm_token_user_${user.id}';
      final cachedToken = prefs.getString(cacheKey);

      // Jika token sama dengan yang pernah dikirim untuk user ini, skip kirim ke server
      if (cachedToken == token) {
        if (kDebugMode) {
          print("FCM Token is already synced for user ${user.name}. Skipping API call.");
        }
        return;
      }

      if (kDebugMode) {
        print("Device FCM Token changed or new login. Sending to server: $token");
      }

      // Kirim token ke backend Laravel
      final success = await ApiService.instance.updateFcmToken(token);
      if (success) {
        // Simpan token ke local cache agar tidak dikirim berulang
        await prefs.setString(cacheKey, token);
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error getting or sending FCM Token: $e");
      }
    }
  }

  /// Menghapus FCM Token (dipanggil saat user logout)
  Future<void> deleteToken() async {
    try {
      await _messaging.deleteToken();
    } catch (e) {
      if (kDebugMode) {
        print("Error deleting FCM Token: $e");
      }
    }
  }

  /// Mendengar notifikasi yang masuk ketika aplikasi sedang dibuka (Foreground)
  void _setupForegroundListener() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) {
        print('FCM Foreground Message: ${message.notification?.title}');
      }

      final notification = message.notification;
      if (notification != null) {
        // Karena aplikasi sedang aktif di depan, sistem operasi secara default
        // TIDAK memunculkan banner notifikasi di atas.
        // Oleh karena itu, kita paksa tampilkan menggunakan FlutterLocalNotificationsPlugin kita!
        NotificationService.instance.tampilkanNotifikasi(
          id: message.messageId.hashCode,
          judul: notification.title ?? 'Notifikasi Sahaduta',
          isi: notification.body ?? '',
          payload: message.data['type'] ?? 'fcm_default',
        );
      }
    });
  }

  /// Menangani aksi tap pada notifikasi saat aplikasi berada di background/terminated
  void _setupNotificationTapListener() {
    // 1. Saat aplikasi dalam keadaan Background (tetapi masih berjalan di RAM) dan di-tap
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _onNotificationOpened(message.data);
    });

    // 2. Saat aplikasi dalam keadaan Terminated (mati total) lalu di-tap dan aplikasi terbuka
    _messaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        _onNotificationOpened(message.data);
      }
    });
  }

  /// Logika navigasi atau aksi saat notifikasi di-tap
  void _onNotificationOpened(Map<String, dynamic> data) {
    if (kDebugMode) {
      print("Notification Tapped with data: $data");
    }
    
    // Contoh: Jika tipe data adalah cuti_status, kita bisa mengarahkan user ke halaman Cuti
    // final type = data['type'];
    // if (type == 'cuti_status') {
    //   Get.toNamed('/cuti');
    // }
  }
}
