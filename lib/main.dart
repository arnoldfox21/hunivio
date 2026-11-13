import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'utils/formatters.dart';

void main() {
  runApp(const HuniGoApp());
}

class HuniGoApp extends StatelessWidget {
  const HuniGoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HuniGo - Cari Kost Mudah',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryGreen,
          primary: AppColors.primaryGreen,
        ),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}
