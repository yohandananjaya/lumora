import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  String getChatId(String user1, String user2) {
    return user1.hashCode <= user2.hashCode ? '$user1-$user2' : '$user2-$user1';
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      extendBodyBehindAppBar: true, // Background එක උඩටම යන්න
      appBar: AppBar(
        title: const Text("LUMORA", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, color: Colors.white)),
        centerTitle: true,
        backgroundColor: Colors.transparent, // AppBar එක Transparent කළා
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          // --- 1. Profile Photo එක AppBar එකේ පෙන්වීම ---
          Padding(
            padding: const EdgeInsets.only(right: 15),
            child: GestureDetector(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen()));
              },
              child: StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('users').doc(currentUser?.uid).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data!.data() != null) {
                    var data = snapshot.data!.data() as Map<String, dynamic>;
                    String? photoUrl = data['photoUrl'];

                    return CircleAvatar(
                      radius: 20,
                      backgroundColor: const Color(0xFF6F00FF),
                      backgroundImage: (photoUrl != null && photoUrl.isNotEmpty) ? NetworkImage(photoUrl) : null,
                      child: (photoUrl == null || photoUrl.isEmpty) 
                          ? const Icon(Icons.person, color: Colors.white) 
                          : null,
                    );
                  }
                  return const CircleAvatar(backgroundColor: Color(0xFF2B2B3D), child: Icon(Icons.person, color: Colors.white));
                },
              ),
            ),
          )
        ],
      ),
      // --- 2. Background Image එක දැමීම ---
      body: Stack(
        children: [
          // Background Image Layer
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                // මම මෙතන ඔයාගේ App එකට ගැලපෙන Dark Neon Image එකක් දැම්මා
                image: NetworkImage("https://images.unsplash.com/photo-1550751827-4bd374c3f58b?q=80&w=1000&auto=format&fit=crop"), 
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Dark Overlay (පින්තූරය උඩින් කළු පාටක් දැම්මා අකුරු පේන්න)
          Container(
            color: const Color(0xFF0F0F1A).withOpacity(0.85),
          ),

          // User List Layer
          SafeArea(
            child: StreamBuilder(
              stream: FirebaseFirestore.instance.collection('users').where('uid', isNotEqualTo: currentUser?.uid).snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> userSnapshot) {
                if (!userSnapshot.hasData) return const Center(child: CircularProgressIndicator());
                if (userSnapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No users found yet.", style: TextStyle(color: Colors.grey)));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  itemCount: userSnapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var userDoc = userSnapshot.data!.docs[index];
                    var userData = userDoc.data() as Map<String, dynamic>;
                    String peerId = userData['uid'];
                    String peerName = userData['name'] ?? "Unknown";
                    String? photoUrl = userData['photoUrl'];
                    String chatId = getChatId(currentUser!.uid, peerId);

                    return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('chats')
                          .doc(chatId)
                          .collection('messages')
                          .where('senderId', isNotEqualTo: currentUser.uid)
                          .where('isRead', isEqualTo: false)
                          .snapshots(),
                      builder: (context, messageSnapshot) {
                        int unreadCount = 0;
                        if (messageSnapshot.hasData) {
                          unreadCount = messageSnapshot.data!.docs.length;
                        }

                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A2E).withOpacity(0.9), // චැට් කාඩ් එක ටිකක් විනිවිද පෙනෙන විදියට
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: const Color(0xFF2B2B3D)),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 5)]
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                            leading: CircleAvatar(
                              radius: 25,
                              backgroundColor: const Color(0xFF6F00FF),
                              backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                              child: photoUrl == null
                                  ? Text(peerName[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 20))
                                  : null,
                            ),
                            title: Text(peerName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
                            subtitle: Text(userData['phone'] ?? "", style: TextStyle(color: Colors.grey[400])),
                            trailing: unreadCount > 0
                                ? Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF00C6FF),
                                      shape: BoxShape.circle,
                                      boxShadow: [BoxShadow(color: Color(0xFF00C6FF), blurRadius: 8)] // Neon Glow Effect
                                    ),
                                    child: Text(
                                      unreadCount.toString(),
                                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  )
                                : null,
                            onTap: () {
                              Navigator.push(
                                context, 
                                MaterialPageRoute(builder: (context) => ChatScreen(peerId: peerId, peerName: peerName))
                              );
                            },
                          ),
                        );
                      }
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}