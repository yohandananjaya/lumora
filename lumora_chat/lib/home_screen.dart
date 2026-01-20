import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';
import 'create_group_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final TextEditingController _searchController = TextEditingController();
  
  // Tab Controller එකට අදාලව
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _saveFcmToken();
  }

  Future<void> _saveFcmToken() async {
    String? token = await FirebaseMessaging.instance.getToken();
    if (token != null && currentUser != null) {
      await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).update({
        'fcmToken': token,
      });
    }
  }

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

  void _showOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.group_add, color: Color(0xFF6F00FF), size: 30),
                title: const Text("Create New Group", style: TextStyle(color: Colors.white, fontSize: 18)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateGroupScreen()));
                },
              ),
              const Divider(color: Colors.grey),
              ListTile(
                leading: const Icon(Icons.person_add, color: Color(0xFF00C6FF), size: 30),
                title: const Text("New Chat", style: TextStyle(color: Colors.white, fontSize: 18)),
                onTap: () {
                  Navigator.pop(context);
                  _showNewChatDialog();
                },
              ),
            ],
          ),
        );
      },
    );
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
    // ✅ 1. DefaultTabController එක දැම්මා Tabs 3ක් සඳහා
    return DefaultTabController(
      length: 3,
      child: Scaffold(
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
                  // --- Search Bar ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: "Search...",
                        hintStyle: TextStyle(color: Colors.grey[500]),
                        filled: true,
                        fillColor: const Color(0xFF1A1A2E).withOpacity(0.8),
                        prefixIcon: const Icon(Icons.search, color: Colors.grey),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                      ),
                    ),
                  ),

                  // ✅ 2. Tab Bar එක එකතු කිරීම
                  const TabBar(
                    indicatorColor: Color(0xFF6F00FF),
                    labelColor: Color(0xFF6F00FF),
                    unselectedLabelColor: Colors.grey,
                    labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    tabs: [
                      Tab(text: "Chats"),
                      Tab(text: "Groups"),
                      Tab(text: "Calls"),
                    ],
                  ),

                  // ✅ 3. Tab Views (Chats, Groups, Calls වෙන වෙනම පෙන්වීමට)
                  Expanded(
                    child: TabBarView(
                      children: [
                        // --- TAB 1: Personal Chats ---
                        _buildPersonalChatList(),

                        // --- TAB 2: Groups ---
                        _buildGroupList(),

                        // --- TAB 3: Calls History (දැනට Placeholder) ---
                        const Center(child: Text("Call History (Coming Soon)", style: TextStyle(color: Colors.grey))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _showOptions,
          backgroundColor: const Color(0xFF6F00FF),
          child: const Icon(Icons.add, color: Colors.white, size: 30),
        ),
      ),
    );
  }

  // 🔥 Widget 1: Personal Chats List
  Widget _buildPersonalChatList() {
    return StreamBuilder(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .collection('chatList')
          .orderBy('time', descending: true)
          .snapshots(),
      builder: (context, AsyncSnapshot<QuerySnapshot> chatListSnapshot) {
        if (!chatListSnapshot.hasData) return const Center(child: CircularProgressIndicator());
        var chatDocs = chatListSnapshot.data!.docs;
        if (chatDocs.isEmpty) return const Center(child: Text("No chats yet.", style: TextStyle(color: Colors.grey)));

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 80, top: 10),
          itemCount: chatDocs.length,
          itemBuilder: (context, index) {
            var chatData = chatDocs[index].data() as Map<String, dynamic>;
            String peerId = chatData['peerId'];
            
            return StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(peerId).snapshots(),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData || !userSnapshot.data!.exists) return const SizedBox.shrink();
                var userData = userSnapshot.data!.data() as Map<String, dynamic>;
                String chatId = getChatId(currentUser!.uid, peerId);

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('chats').doc(chatId).collection('messages')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, msgSnapshot) {
                    int unreadCount = 0;
                    String lastMsg = "Start conversation";
                    String time = "";

                    if (msgSnapshot.hasData && msgSnapshot.data!.docs.isNotEmpty) {
                      var docs = msgSnapshot.data!.docs;
                      var lastData = docs.first.data() as Map<String, dynamic>;
                      String type = lastData['type'] ?? 'text';
                      String senderId = lastData['senderId'] ?? "";
                      String prefix = (senderId == currentUser!.uid) ? "You: " : "";

                      if (type == 'image') lastMsg = "$prefix📷 Photo";
                      else lastMsg = "$prefix${lastData['text'] ?? ""}";

                      if (lastData['createdAt'] != null) time = _formatTime(lastData['createdAt']);

                      for (var doc in docs) {
                        Map<String, dynamic> d = doc.data() as Map<String, dynamic>;
                        if (d['senderId'] != currentUser!.uid && d['isRead'] == false) unreadCount++;
                      }
                    }

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: const Color(0xFF1A1A2E).withOpacity(0.9), borderRadius: BorderRadius.circular(15), border: Border.all(color: const Color(0xFF2B2B3D))),
                      child: ListTile(
                        leading: CircleAvatar(radius: 25, backgroundImage: userData['photoUrl'] != null ? NetworkImage(userData['photoUrl']) : null, backgroundColor: const Color(0xFF6F00FF), child: userData['photoUrl'] == null ? Text(userData['name'][0].toUpperCase(), style: const TextStyle(color: Colors.white)) : null),
                        title: Text(userData['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Text(lastMsg, style: TextStyle(color: unreadCount > 0 ? Colors.white : Colors.grey[500], fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(time, style: TextStyle(color: unreadCount > 0 ? const Color(0xFF00C6FF) : Colors.grey, fontSize: 11)),
                            const SizedBox(height: 5),
                            if (unreadCount > 0) Container(padding: const EdgeInsets.all(6), decoration: const BoxDecoration(color: Color(0xFF00C6FF), shape: BoxShape.circle), child: Text("$unreadCount", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10)))
                          ],
                        ),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(peerId: peerId, peerName: userData['name']))),
                      ),
                    );
                  }
                );
              }
            );
          },
        );
      },
    );
  }

  // 🔥 Widget 2: Group List (අලුතින් එකතු කළ කොටස)
  Widget _buildGroupList() {
    return StreamBuilder(
      // මම ඉන්න Group විතරක් Filter කරනවා
      stream: FirebaseFirestore.instance.collection('groups')
          .where('members', arrayContains: currentUser!.uid)
          .orderBy('recentMessageTime', descending: true)
          .snapshots(),
      builder: (context, AsyncSnapshot<QuerySnapshot> groupSnapshot) {
        if (!groupSnapshot.hasData) return const Center(child: CircularProgressIndicator());
        var groups = groupSnapshot.data!.docs;
        if (groups.isEmpty) return const Center(child: Text("No groups yet.", style: TextStyle(color: Colors.grey)));

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 80, top: 10),
          itemCount: groups.length,
          itemBuilder: (context, index) {
            var groupData = groups[index].data() as Map<String, dynamic>;
            String groupId = groupData['groupId'];
            String groupName = groupData['groupName'];
            String lastMsg = groupData['recentMessage'] ?? "";
            String lastSender = groupData['recentMessageSender'] ?? "";
            
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: const Color(0xFF1A1A2E).withOpacity(0.9), borderRadius: BorderRadius.circular(15), border: Border.all(color: const Color(0xFF2B2B3D))),
              child: ListTile(
                leading: CircleAvatar(
                  radius: 25,
                  backgroundColor: Colors.purpleAccent,
                  child: const Icon(Icons.group, color: Colors.white),
                ),
                title: Text(groupName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text("$lastSender: $lastMsg", style: TextStyle(color: Colors.grey[500], fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () {
                  // දැනට Group Chat Screen එකක් නෑ. මෙතන පොඩි මැසේජ් එකක් දාමු.
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Group Chat Screen Coming Soon!")));
                },
              ),
            );
          },
        );
      },
    );
  }
}