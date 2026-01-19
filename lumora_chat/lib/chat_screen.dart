import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatScreen extends StatelessWidget {
  final String peerId;
  final String peerName;

  const ChatScreen({super.key, required this.peerId, required this.peerName});

  // දෙන්නා අතර Unique Chat ID එකක් හදනවා
  String getChatId(String user1, String user2) {
    return user1.hashCode <= user2.hashCode ? '$user1-$user2' : '$user2-$user1';
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final chatId = getChatId(currentUser!.uid, peerId);
    final TextEditingController _msgController = TextEditingController();

    void sendMessage() {
      if (_msgController.text.trim().isNotEmpty) {
        FirebaseFirestore.instance
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .add({
          'text': _msgController.text.trim(),
          'createdAt': Timestamp.now(),
          'senderId': currentUser.uid,
        });
        _msgController.clear();
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        title: Text(peerName), // අදාල කෙනාගේ නම
        backgroundColor: const Color(0xFF1A1A2E),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(chatId)
                  .collection('messages')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                return ListView(
                  reverse: true,
                  padding: const EdgeInsets.all(10),
                  children: snapshot.data!.docs.map((doc) {
                    bool isMe = doc['senderId'] == currentUser.uid;
                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: isMe 
                            ? const LinearGradient(colors: [Color(0xFF00C6FF), Color(0xFF0072FF)])
                            : const LinearGradient(colors: [Color(0xFF2B2B3D), Color(0xFF2B2B3D)]),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Text(doc['text'], style: const TextStyle(color: Colors.white)),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            color: const Color(0xFF1A1A2E),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Message...",
                      hintStyle: TextStyle(color: Colors.grey[600]),
                      filled: true,
                      fillColor: const Color(0xFF2B2B3D),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: const Color(0xFF6F00FF),
                  child: IconButton(icon: const Icon(Icons.send, color: Colors.white), onPressed: sendMessage),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}