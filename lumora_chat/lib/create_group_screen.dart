import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart'; // මේක නැත්නම්: flutter pub add uuid ගහන්න

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final TextEditingController _groupNameController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  List<Map<String, dynamic>> memberList = []; // යාලුවෝ ඔක්කොම
  List<String> selectedMembers = []; // තෝරාගත් අයගේ IDs
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    getCurrentUserDetails();
  }

  // 1. Database එකෙන් Users ලා ටික ගන්නවා
  void getCurrentUserDetails() async {
    String myId = _auth.currentUser!.uid;
    var snapshot = await _firestore.collection('users').where("uid", isNotEqualTo: myId).get();
    
    setState(() {
      memberList = snapshot.docs.map((doc) => doc.data()).toList();
    });
  }

  // 2. Group එක Create කරන Function එක
  void createGroup() async {
    if (_groupNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Enter Group Name")));
      return;
    }
    if (selectedMembers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Select at least one member")));
      return;
    }

    setState(() => isLoading = true);

    try {
      String groupId = const Uuid().v1(); // අලුත් ID එකක්
      String myId = _auth.currentUser!.uid;
      String myName = _auth.currentUser!.displayName ?? "Admin";

      // මාවත් ලිස්ට් එකට එකතු කරගන්න ඕන
      selectedMembers.add(myId);

      // Group එක Database එකේ Save කරනවා
      await _firestore.collection('groups').doc(groupId).set({
        'groupId': groupId,
        'groupName': _groupNameController.text,
        'groupIcon': '', // පස්සේ දාමු
        'admin': myId,
        'members': selectedMembers, // මෙතන ID ලිස්ට් එක තියෙනවා
        'recentMessage': 'Group Created',
        'recentMessageSender': myName,
        'recentMessageTime': FieldValue.serverTimestamp(),
      });

      Navigator.pop(context); // ආපහු Home එකට
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Group Created Successfully!")));

    } catch (e) {
      print(e);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to create group")));
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("New Group", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1A1A2E),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: const Color(0xFF0F0F1A),
      body: isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF6F00FF)))
        : Column(
          children: [
            // Group Name Input
            Padding(
              padding: const EdgeInsets.all(15.0),
              child: TextField(
                controller: _groupNameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Enter Group Name",
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  filled: true,
                  fillColor: const Color(0xFF1A1A2E),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  prefixIcon: const Icon(Icons.group, color: Color(0xFF6F00FF)),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 15, vertical: 5),
              child: Align(alignment: Alignment.centerLeft, child: Text("Select Members", style: TextStyle(color: Colors.grey, fontSize: 16))),
            ),
            
            // User List with Checkboxes
            Expanded(
              child: ListView.builder(
                itemCount: memberList.length,
                itemBuilder: (context, index) {
                  var user = memberList[index];
                  bool isSelected = selectedMembers.contains(user['uid']);

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: user['photoUrl'] != null ? NetworkImage(user['photoUrl']) : null,
                      backgroundColor: const Color(0xFF6F00FF),
                      child: user['photoUrl'] == null ? Text(user['name'][0], style: const TextStyle(color: Colors.white)) : null,
                    ),
                    title: Text(user['name'], style: const TextStyle(color: Colors.white)),
                    subtitle: Text(user['email'] ?? "", style: const TextStyle(color: Colors.grey)),
                    trailing: Checkbox(
                      value: isSelected,
                      activeColor: const Color(0xFF6F00FF),
                      checkColor: Colors.white,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            selectedMembers.add(user['uid']);
                          } else {
                            selectedMembers.remove(user['uid']);
                          }
                        });
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      floatingActionButton: FloatingActionButton(
        onPressed: createGroup,
        backgroundColor: const Color(0xFF6F00FF),
        child: const Icon(Icons.check, color: Colors.white),
      ),
    );
  }
}