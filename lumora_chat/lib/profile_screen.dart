import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart'; // ෆොටෝ අප්ලෝඩ් කරන්න
import 'dart:io';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  final cloudinary = CloudinaryPublic('ds974lczz', 'fulvalgc', cache: false); // ඔයාගේ Cloudinary විස්තර
  bool _isUploading = false;

  // 1. Bio එක වෙනස් කරන Function එක
  void _editBio(String currentBio) {
    TextEditingController bioController = TextEditingController(text: currentBio);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text("Update Bio", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: bioController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: "Type your bio here...",
            hintStyle: TextStyle(color: Colors.grey[600]),
            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF6F00FF))),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              if (bioController.text.trim().isNotEmpty) {
                await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
                  'bio': bioController.text.trim(),
                });
                Navigator.pop(context);
              }
            },
            child: const Text("Save", style: TextStyle(color: Color(0xFF6F00FF), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // 2. Profile Photo එක වෙනස් කරන Function එක
  Future<void> _updateProfilePhoto() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    
    if (pickedFile != null) {
      setState(() => _isUploading = true);
      File imageFile = File(pickedFile.path);

      try {
        // Cloudinary වෙත Upload කිරීම
        CloudinaryResponse response = await cloudinary.uploadFile(
          CloudinaryFile.fromFile(imageFile.path, resourceType: CloudinaryResourceType.Image),
        );

        // Firestore හි Link එක update කිරීම
        await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
          'photoUrl': response.secureUrl,
        });

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile photo updated!")));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to update photo")));
      } finally {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        title: const Text("Profile", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1A1A2E),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          var data = snapshot.data!.data() as Map<String, dynamic>?;
          String photoUrl = data?['photoUrl'] ?? "";
          String name = data?['name'] ?? "User";
          String phone = data?['phone'] ?? "";
          String bio = data?['bio'] ?? "Hey there! I am using Lumora."; // Default Bio එක

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const SizedBox(height: 20),
                
                // --- Profile Picture Section ---
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 70,
                        backgroundColor: const Color(0xFF2B2B3D),
                        backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                        child: _isUploading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : (photoUrl.isEmpty ? const Icon(Icons.person, size: 70, color: Colors.white) : null),
                      ),
                      // කැමරා අයිකන් එක (Update Button)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _isUploading ? null : _updateProfilePhoto,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: const BoxDecoration(
                              color: Color(0xFF6F00FF),
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 5)],
                            ),
                            child: const Icon(Icons.camera_alt, color: Colors.white, size: 22),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 30),

                // --- Name & Phone Section ---
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person, color: Color(0xFF6F00FF)),
                  title: const Text("Name", style: TextStyle(color: Colors.grey, fontSize: 14)),
                  subtitle: Text(name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                const Divider(color: Color(0xFF2B2B3D)),

                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.phone, color: Color(0xFF6F00FF)),
                  title: const Text("Phone", style: TextStyle(color: Colors.grey, fontSize: 14)),
                  subtitle: Text(phone, style: const TextStyle(color: Colors.white, fontSize: 18)),
                ),
                const Divider(color: Color(0xFF2B2B3D)),

                // --- Bio Section (Editable) ---
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.info_outline, color: Color(0xFF6F00FF)),
                  title: const Text("About", style: TextStyle(color: Colors.grey, fontSize: 14)),
                  subtitle: Text(bio, style: const TextStyle(color: Colors.white, fontSize: 16)),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit, color: Color(0xFF00C6FF)),
                    onPressed: () => _editBio(bio),
                  ),
                ),
                
                const SizedBox(height: 50),

                // --- Logout Button ---
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await FirebaseAuth.instance.signOut();
                      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
                    },
                    icon: const Icon(Icons.logout, color: Colors.white),
                    label: const Text("LOGOUT", style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2B2B3D),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }
}