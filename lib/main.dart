import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FakhriTokApp());
}

class FakhriTokApp extends StatelessWidget {
  const FakhriTokApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FakhriTok',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF090909),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF25F4EE),
          brightness: Brightness.dark,
          primary: const Color(0xFF25F4EE),
          secondary: const Color(0xFFFF2D55),
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const AppShell(),
    );
  }
}