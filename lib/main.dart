// W pliku main.dart zaktualizuj klasę MyApp:

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/auth_service.dart';
import 'screens/home_screen.dart';
import 'screens/welcome_screen.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Inicjujemy nasz serwis
    final authService = AuthService();
    final String? currentUserId = authService.getCurrentUserId();

    return MaterialApp(
      title: 'QuidSplit', // Nazwa publiczna
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      // Zależnie od tego, czy mamy UID, ładujemy konkretny ekran
      home: currentUserId == null ? const WelcomeScreen() : const HomeScreen(),
    );
  }
}