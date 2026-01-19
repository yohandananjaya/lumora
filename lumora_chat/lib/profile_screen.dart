import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(title: const Text("My Profile"), backgroundColor: const Color(0xFF1A1A2E)),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(user?.uid).get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          var userData = snapshot.data!.data() as Map<String, dynamic>?;
          String name = userData?['name'] ?? "User";
          String phone = userData?['phone'] ?? user?.phoneNumber ?? "";

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircleAvatar(radius: 50, backgroundColor: Color(0xFF6F00FF), child: Icon(Icons.person, size: 50, color: Colors.white)),
                const SizedBox(height: 20),
                Text(name, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                Text(phone, style: const TextStyle(color: Colors.grey, fontSize: 16)),
                const SizedBox(height: 40),
                ElevatedButton.icon(
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    Navigator.pushAndRemoveUntil(
                      context, MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text("LOGOUT"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                )
              ],
            ),
          );
        },
      ),
    );
  }
}