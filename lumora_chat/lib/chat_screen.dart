import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'dart:io';
import 'dart:async'; // StreamSubscription සඳහා

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
  final cloudinary = CloudinaryPublic('ds974lczz', 'fulvalgc', cache: false);
  late String chatId;
  bool _isUploading = false;
  
  // ✅ අලුතෙන් එකතු කළ කොටස: දිගටම අහගෙන ඉන්න Listener එකක්
  StreamSubscription? _unreadListener;

  @override
  void initState() {
    super.initState();
    chatId = widget.peerId.hashCode <= currentUser!.uid.hashCode 
        ? '${widget.peerId}-${currentUser!.uid}' : '${currentUser!.uid}-${widget.peerId}';
    
    // Chat එකට ආපු ගමන් Auto Read වෙන්න පටන් ගන්නවා
    _startListeningForUnreadMessages();
  }

  @override
  void dispose() {
    // Chat එකෙන් එළියට යනකොට Listener එක නවත්වනවා (Memory Save කරන්න)
    _unreadListener?.cancel();
    super.dispose();
  }

  // ✅ මැසේජ් කියෙව්වා කියලා ස්වයංක්‍රීයව අප්ඩේට් කරන Function එක
  void _startListeningForUnreadMessages() {
    _unreadListener = FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('senderId', isNotEqualTo: currentUser!.uid) // මගේ නොවන
        .where('isRead', isEqualTo: false) // කියවා නැති
        .snapshots()
        .listen((snapshot) {
      // කියවා නැති මැසේජ් තියෙනවා නම්, ඒවා ඔක්කොම true කරන්න
      for (var doc in snapshot.docs) {
        doc.reference.update({'isRead': true});
      }
    });
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return "";
    DateTime date = timestamp.toDate();
    String hour = date.hour > 12 ? (date.hour - 12).toString() : (date.hour == 0 ? "12" : date.hour.toString());
    String minute = date.minute.toString().padLeft(2, '0');
    String period = date.hour >= 12 ? "PM" : "AM";
    return "$hour:$minute $period";
  }

  void _updateChatTime() {
    FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).update({'lastMessageTime': Timestamp.now()});
    FirebaseFirestore.instance.collection('users').doc(widget.peerId).update({'lastMessageTime': Timestamp.now()});
  }

  void _confirmDelete(String docId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text("Delete Message?", style: TextStyle(color: Colors.white)),
        content: const Text("Remove for everyone?", style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await FirebaseFirestore.instance.collection('chats').doc(chatId).collection('messages').doc(docId).delete();
            },
            child: const Text("Delete", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  Future<void> _sendImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _isUploading = true);
      try {
        File imageFile = File(pickedFile.path);
        CloudinaryResponse response = await cloudinary.uploadFile(
          CloudinaryFile.fromFile(imageFile.path, resourceType: CloudinaryResourceType.Image),
        );
        await FirebaseFirestore.instance.collection('chats').doc(chatId).collection('messages').add({
          'text': '', 'imageUrl': response.secureUrl, 'type': 'image',
          'createdAt': Timestamp.now(), 'senderId': currentUser!.uid, 'isRead': false,
        });
        _updateChatTime();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Upload failed")));
      } finally {
        setState(() => _isUploading = false);
      }
    }
  }

  void sendMessage() {
    if (_msgController.text.trim().isEmpty) return;
    FirebaseFirestore.instance.collection('chats').doc(chatId).collection('messages').add({
      'text': _msgController.text.trim(), 'type': 'text',
      'createdAt': Timestamp.now(), 'senderId': currentUser!.uid, 'isRead': false,
    });
    _updateChatTime();
    _msgController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E).withOpacity(0.7),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(widget.peerId).snapshots(),
          builder: (context, snapshot) {
            String? photoUrl;
            if (snapshot.hasData && snapshot.data!.data() != null) {
              var data = snapshot.data!.data() as Map<String, dynamic>;
              if (data.containsKey('photoUrl')) photoUrl = data['photoUrl'];
            }
            return Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFF6F00FF),
                  backgroundImage: (photoUrl != null && photoUrl.isNotEmpty) ? NetworkImage(photoUrl) : null,
                  child: (photoUrl == null || photoUrl.isEmpty) ? Text(widget.peerName[0].toUpperCase(), style: const TextStyle(color: Colors.white)) : null,
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(widget.peerName, style: const TextStyle(color: Colors.white, fontSize: 18), overflow: TextOverflow.ellipsis)),
              ],
            );
          },
        ),
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(image: NetworkImage("https://images.unsplash.com/photo-1535868463750-c78d9543614f?q=80&w=1000&auto=format&fit=crop"), fit: BoxFit.cover),
            ),
          ),
          Container(color: const Color(0xFF0F0F1A).withOpacity(0.7)),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: StreamBuilder(
                    stream: FirebaseFirestore.instance.collection('chats').doc(chatId).collection('messages').orderBy('createdAt', descending: true).snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      return ListView(
                        reverse: true,
                        padding: const EdgeInsets.all(15),
                        children: snapshot.data!.docs.map((doc) {
                          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
                          bool isRead = data.containsKey('isRead') ? data['isRead'] : false;
                          String text = data.containsKey('text') ? data['text'] : "";
                          String type = data.containsKey('type') ? data['type'] : "text";
                          String imageUrl = data.containsKey('imageUrl') ? data['imageUrl'] : "";
                          String senderId = data.containsKey('senderId') ? data['senderId'] : "";
                          Timestamp? createdAt = data.containsKey('createdAt') ? data['createdAt'] : null;
                          bool isMe = senderId == currentUser!.uid;
                          
                          return GestureDetector(
                            onLongPress: isMe ? () => _confirmDelete(doc.id) : null,
                            child: Align(
                              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                                decoration: BoxDecoration(
                                  gradient: isMe 
                                    ? const LinearGradient(colors: [Color(0xFF00C6FF), Color(0xFF0072FF)])
                                    : LinearGradient(colors: [const Color(0xFF2B2B3D).withOpacity(0.9), const Color(0xFF2B2B3D).withOpacity(0.9)]),
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(15), topRight: const Radius.circular(15),
                                    bottomLeft: isMe ? const Radius.circular(15) : Radius.zero, bottomRight: isMe ? Radius.zero : const Radius.circular(15),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    if (type == 'image') ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(imageUrl, fit: BoxFit.cover))
                                    else Text(text, style: const TextStyle(color: Colors.white, fontSize: 16)),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(_formatTime(createdAt), style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 10)),
                                        if (isMe) ...[
                                          const SizedBox(width: 5),
                                          Icon(isRead ? Icons.done_all : Icons.done, size: 14, color: isRead ? Colors.white : Colors.white60),
                                        ]
                                      ],
                                    )
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ),
                if (_isUploading) const LinearProgressIndicator(color: Color(0xFF6F00FF)),
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 5),
                  color: Colors.transparent,
                  child: Row(
                    children: [
                      CircleAvatar(radius: 24, backgroundColor: const Color(0xFF2B2B3D), child: IconButton(icon: const Icon(Icons.image, color: Colors.white, size: 22), onPressed: _isUploading ? null : _sendImage)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(color: const Color(0xFF2B2B3D).withOpacity(0.9), borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 5)]),
                          child: TextField(controller: _msgController, style: const TextStyle(color: Colors.white), decoration: InputDecoration(hintText: "Type a message...", hintStyle: TextStyle(color: Colors.grey[400]), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12))),
                        ),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(radius: 24, backgroundColor: const Color(0xFF6F00FF), child: IconButton(icon: const Icon(Icons.send, color: Colors.white, size: 22), onPressed: sendMessage))
                    ],
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}