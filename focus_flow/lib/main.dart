import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:focusnflow/core/app_theme.dart';
import 'package:focusnflow/core/app_routes.dart';
import 'package:focusnflow/screens/auth/auth_gate.dart';
import 'package:focusnflow/services/firebase_seeder.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Seed Firestore with sample data
  await FirebaseSeeder.seedIfNeeded();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FocusNFlow',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const AuthGate(),
      onGenerateRoute: AppRoutes.generateRoute,
      debugShowCheckedModeBanner: false,
    );
  }
}
