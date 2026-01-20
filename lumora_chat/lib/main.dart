import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';
import 'home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // Firebase පටන් ගන්නවා
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Lumora Chat',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        useMaterial3: true,
      ),
      // මෙන්න මෙතනින් තමයි Login වෙලාද කියලා බලන්නේ
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // 1. Loading වෙන වෙලාව (Login වෙනකම්)
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // 2. User කෙනෙක් ඉන්නවා නම් (Login වෙලා නම්) -> Home එකට යවන්න
          if (snapshot.hasData) {
            return const HomeScreen();
          }

          // 3. එහෙම නැත්නම් (Logout වෙලා නම්) -> Login එකට යවන්න
          return const LoginScreen();
        },
      ),
    );
  }
}