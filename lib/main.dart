import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:get/get.dart';
import 'screens/main_navigation.dart';
import 'screens/login_screen.dart';
import 'services/api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi locale 'id' agar DateFormat bisa format nama hari/bulan bahasa Indonesia
  await initializeDateFormatting('id', null);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const SahadutaApp());
}

class SahadutaApp extends StatelessWidget {
  const SahadutaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Sahaduta Mobile',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E3A8A),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
        fontFamily: 'Roboto',
      ),
      home: const AuthWrapper(),
    );
  }
}

/// Cek token → jika sudah login langsung ke MainNavigation,
/// jika belum → LoginScreen.
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  Future<Map<String, dynamic>> _checkAuth() async {
    final isLoggedIn = await ApiService.instance.isLoggedIn;
    final biometricEnabled = await ApiService.instance.isBiometricEnabled();
    return {
      'isLoggedIn': isLoggedIn,
      'biometricEnabled': biometricEnabled,
    };
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _checkAuth(),
      builder: (context, snapshot) {
        // Tampilkan splash singkat saat cek token
        if (!snapshot.hasData) {
          return const Scaffold(
            backgroundColor: Color(0xFF1E3A8A),
            body: Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          );
        }
        
        final data = snapshot.data!;
        // Jika sudah login dan biometrik TIDAK aktif, langsung ke dashboard
        if (data['isLoggedIn'] == true && data['biometricEnabled'] == false) {
          return const MainNavigation();
        }
        
        // Jika belum login, ATAU sudah login tapi biometrik aktif -> ke LoginScreen
        return const LoginScreen();
      },
    );
  }
}
