import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final TextEditingController _searchController = TextEditingController();
  String _searchText = "";

  String getChatId(String user1, String user2) {
    return user1.hashCode <= user2.hashCode ? '$user1-$user2' : '$user2-$user1';
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return "";
    DateTime date = timestamp.toDate();
    String hour = date.hour > 12 ? (date.hour - 12).toString() : (date.hour == 0 ? "12" : date.hour.toString());
    String minute = date.minute.toString().padLeft(2, '0');
    String period = date.hour >= 12 ? "PM" : "AM";
    return "$hour:$minute $period";
  }

  void _showNewChatDialog() {
    TextEditingController phoneController = TextEditingController();
    bool isLoading = false;
    Map<String, dynamic>? foundUser;
    String? errorMessage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Start New Chat", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  TextField(
                    controller: phoneController,
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      hintText: "Enter Phone Number (+94...)",
                      hintStyle: TextStyle(color: Colors.grey[600]),
                      filled: true,
                      fillColor: const Color(0xFF2B2B3D),
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF6F00FF)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.arrow_forward, color: Colors.white),
                        onPressed: () async {
                          if (phoneController.text.trim().isEmpty) return;
                          setModalState(() { isLoading = true; errorMessage = null; foundUser = null; });
                          try {
                            var query = await FirebaseFirestore.instance.collection('users').where('phone', isEqualTo: phoneController.text.trim()).get();
                            if (query.docs.isNotEmpty) {
                              setModalState(() => foundUser = query.docs.first.data());
                            } else {
                              setModalState(() => errorMessage = "User not found!");
                            }
                          } catch (e) {
                            setModalState(() => errorMessage = "Error occurred");
                          } finally {
                            setModalState(() => isLoading = false);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (isLoading) const Center(child: CircularProgressIndicator(color: Color(0xFF6F00FF)))
                  else if (errorMessage != null) Text(errorMessage!, style: const TextStyle(color: Colors.redAccent))
                  else if (foundUser != null)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 25,
                        backgroundImage: foundUser!['photoUrl'] != null ? NetworkImage(foundUser!['photoUrl']) : null,
                        backgroundColor: const Color(0xFF6F00FF),
                        child: foundUser!['photoUrl'] == null ? const Icon(Icons.person, color: Colors.white) : null,
                      ),
                      title: Text(foundUser!['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      subtitle: Text(foundUser!['phone'], style: const TextStyle(color: Colors.grey)),
                      trailing: const Icon(Icons.chat_bubble_outline, color: Color(0xFF00C6FF)),
                      onTap: () {
                        Navigator.pop(context);
                        // මෙතනින් Chat එකට ගියාම විතරක් එයාව ලිස්ට් එකට වැටෙන්නේ නෑ. 
                        // මැසේජ් එකක් යැව්වම තමයි ලිස්ට් එකට වැටෙන්නේ.
                        Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(peerId: foundUser!['uid'], peerName: foundUser!['name'])));
                      },
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shield_moon, color: Color(0xFF6F00FF), size: 28), 
            const SizedBox(width: 10),
            const Text("LUMORA", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, color: Colors.white)),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 15),
            child: GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen())),
              child: StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('users').doc(currentUser?.uid).snapshots(),
                builder: (context, snapshot) {
                  var data = snapshot.data?.data() as Map<String, dynamic>?;
                  String? photoUrl = data?['photoUrl'];
                  return CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFF6F00FF),
                    backgroundImage: (photoUrl != null) ? NetworkImage(photoUrl) : null,
                    child: (photoUrl == null) ? const Icon(Icons.person, color: Colors.white) : null,
                  );
                },
              ),
            ),
          )
        ],
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(image: NetworkImage("https://images.unsplash.com/photo-1550751827-4bd374c3f58b?q=80&w=1000&auto=format&fit=crop"), fit: BoxFit.cover),
            ),
          ),
          Container(color: const Color(0xFF0F0F1A).withOpacity(0.85)),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchText = val.toLowerCase()),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Search chats...",
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      filled: true,
                      fillColor: const Color(0xFF1A1A2E).withOpacity(0.8),
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                Expanded(
                  child: StreamBuilder(
                    stream: FirebaseFirestore.instance.collection('users').where('uid', isNotEqualTo: currentUser!.uid).snapshots(),
                    builder: (context, AsyncSnapshot<QuerySnapshot> userSnapshot) {
                      if (!userSnapshot.hasData) return const Center(child: CircularProgressIndicator());
                      
                      var users = userSnapshot.data!.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();

                      // ✅ 1. FILTERING: මෙන්න මෙතන තමයි අපි වෙනස කළේ
                      // lastMessageTime එක NULL නම් (ඒ කියන්නේ කවදාවත් චැට් කරලා නැත්නම්) ලිස්ට් එකෙන් අයින් කරන්න
                      users = users.where((u) => u['lastMessageTime'] != null).toList();

                      if (_searchText.isNotEmpty) {
                        users = users.where((user) => (user['name'] as String).toLowerCase().contains(_searchText)).toList();
                      }

                      // Sort by time
                      users.sort((a, b) {
                        Timestamp t1 = a['lastMessageTime'] as Timestamp? ?? Timestamp(0, 0);
                        Timestamp t2 = b['lastMessageTime'] as Timestamp? ?? Timestamp(0, 0);
                        return t2.compareTo(t1);
                      });

                      if (users.isEmpty) return const Center(child: Text("No chats yet. Use + to start.", style: TextStyle(color: Colors.grey)));

                      return ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: users.length,
                        itemBuilder: (context, index) {
                          var userData = users[index];
                          String peerId = userData['uid'];
                          String chatId = getChatId(currentUser!.uid, peerId);

                          return StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance.collection('chats').doc(chatId).collection('messages')
                                .orderBy('createdAt', descending: true)
                                .snapshots(),
                            builder: (context, msgSnapshot) {
                              int unreadCount = 0;
                              String lastMsg = "No messages";
                              String time = "";
                              
                              if (msgSnapshot.hasData && msgSnapshot.data!.docs.isNotEmpty) {
                                var docs = msgSnapshot.data!.docs;
                                var lastDoc = docs.first;
                                Map<String, dynamic> lastData = lastDoc.data() as Map<String, dynamic>;
                                
                                String type = lastData['type'] ?? 'text';
                                String senderId = lastData['senderId'] ?? "";
                                String prefix = (senderId == currentUser!.uid) ? "You: " : "";

                                if (type == 'image') {
                                  lastMsg = "$prefix📷 Photo";
                                } else {
                                  lastMsg = "$prefix${lastData['text'] ?? "Message"}";
                                }

                                if (lastData['createdAt'] != null) {
                                   time = _formatTime(lastData['createdAt']);
                                }

                                for (var doc in docs) {
                                  Map<String, dynamic> d = doc.data() as Map<String, dynamic>;
                                  if (d['senderId'] != currentUser!.uid && d['isRead'] == false) {
                                    unreadCount++;
                                  }
                                }
                              }

                              return Container(
                                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1A1A2E).withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(color: const Color(0xFF2B2B3D)),
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    radius: 25,
                                    backgroundImage: userData['photoUrl'] != null ? NetworkImage(userData['photoUrl']) : null,
                                    backgroundColor: const Color(0xFF6F00FF),
                                    child: userData['photoUrl'] == null ? Text(userData['name'][0].toUpperCase(), style: const TextStyle(color: Colors.white)) : null,
                                  ),
                                  title: Text(userData['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  subtitle: Text(lastMsg, style: TextStyle(color: unreadCount > 0 ? Colors.white : Colors.grey[500], fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(time, style: TextStyle(color: unreadCount > 0 ? const Color(0xFF00C6FF) : Colors.grey, fontSize: 11)),
                                      const SizedBox(height: 5),
                                      if (unreadCount > 0)
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: const BoxDecoration(color: Color(0xFF00C6FF), shape: BoxShape.circle),
                                          child: Text("$unreadCount", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10)),
                                        )
                                    ],
                                  ),
                                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(peerId: peerId, peerName: userData['name']))),
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
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showNewChatDialog,
        backgroundColor: const Color(0xFF6F00FF),
        child: const Icon(Icons.add, color: Colors.white, size: 30),
      ),
    );
  }
}