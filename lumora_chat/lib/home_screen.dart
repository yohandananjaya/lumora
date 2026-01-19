import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        title: const Text("LUMORA CHATS", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1A1A2E),
        automaticallyImplyLeading: false, // Back button අයින් කරන්න
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle, size: 30),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen()));
            },
          )
        ],
      ),
      // දැනට App එකේ ලියාපදිංචි වී ඇති සියලුම දෙනා පෙන්වයි
      body: StreamBuilder(
        stream: FirebaseFirestore.instance.collection('users').where('uid', isNotEqualTo: currentUser?.uid).snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          if (snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No users found yet.", style: TextStyle(color: Colors.grey)));
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var user = snapshot.data!.docs[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF6F00FF),
                  child: Text(user['name'][0].toUpperCase(), style: const TextStyle(color: Colors.white)),
                ),
                title: Text(user['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text(user['phone'], style: const TextStyle(color: Colors.grey)),
                onTap: () {
                  // Chat එක Open කිරීම (නම සහ ID යවයි)
                  Navigator.push(
                    context, 
                    MaterialPageRoute(builder: (context) => ChatScreen(peerId: user['uid'], peerName: user['name']))
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF6F00FF),
        child: const Icon(Icons.add_comment, color: Colors.white),
        onPressed: () {
           // මෙතනින් අලුත් නම්බර් එකක් Search කරන්න පුළුවන් (දැනට ලිස්ට් එකෙන් තෝරන්න කියමු)
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Select a user from the list above!")));
        },
      ),
    );
  }
}