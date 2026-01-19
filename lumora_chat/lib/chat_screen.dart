import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatScreen extends StatefulWidget {
  final String peerId;
  final String peerName;
  const ChatScreen({super.key, required this.peerId, required this.peerName});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgController = TextEditingController();
  final currentUser = FirebaseAuth.instance.currentUser;
  late String chatId;

  @override
  void initState() {
    super.initState();
    chatId = widget.peerId.hashCode <= currentUser!.uid.hashCode 
        ? '${widget.peerId}-${currentUser!.uid}' : '${currentUser!.uid}-${widget.peerId}';
    _markRead();
  }

  void _markRead() async {
    var snap = await FirebaseFirestore.instance.collection('chats').doc(chatId).collection('messages')
        .where('senderId', isNotEqualTo: currentUser!.uid).where('isRead', isEqualTo: false).get();
    for (var doc in snap.docs) doc.reference.update({'isRead': true});
  }

  void sendMessage() {
    if (_msgController.text.trim().isEmpty) return;
    FirebaseFirestore.instance.collection('chats').doc(chatId).collection('messages').add({
      'text': _msgController.text.trim(),
      'createdAt': Timestamp.now(),
      'senderId': currentUser!.uid,
      'isRead': false,
    });
    _msgController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(title: Text(widget.peerName, style: const TextStyle(color: Colors.white)), backgroundColor: const Color(0xFF1A1A2E)),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder(
              stream: FirebaseFirestore.instance.collection('chats').doc(chatId).collection('messages').orderBy('createdAt', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                return ListView(
                  reverse: true,
                  padding: const EdgeInsets.all(10),
                  children: snapshot.data!.docs.map((doc) {
                    bool isMe = doc['senderId'] == currentUser!.uid;
                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: isMe ? const LinearGradient(colors: [Color(0xFF00C6FF), Color(0xFF0072FF)]) : const LinearGradient(colors: [Color(0xFF2B2B3D), Color(0xFF2B2B3D)]),
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
                Expanded(child: TextField(controller: _msgController, style: const TextStyle(color: Colors.white), decoration: InputDecoration(hintText: "Type...", hintStyle: TextStyle(color: Colors.grey[600]), filled: true, fillColor: const Color(0xFF2B2B3D), border: OutlineInputBorder(borderRadius: BorderRadius.circular(30))), onTap: _markRead)),
                IconButton(icon: const Icon(Icons.send, color: Color(0xFF6F00FF)), onPressed: sendMessage)
              ],
            ),
          )
        ],
      ),
    );
  }
}