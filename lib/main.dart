import 'package:flutter/material.dart';
import 'core/constants.dart';
import 'screens/auth_screen.dart';

void main() {
  runApp(const HardcoreGachaApp());
}

class HardcoreGachaApp extends StatelessWidget {
  const HardcoreGachaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HG Client',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: AppColors.bg,
        cardColor: AppColors.card,
        colorScheme: const ColorScheme.dark(primary: AppColors.accent),
      ),
      home: const AuthWrapper(),
    );
  }
}