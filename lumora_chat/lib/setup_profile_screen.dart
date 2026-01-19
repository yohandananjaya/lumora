import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart'; // ෆොටෝ තෝරගන්න
import 'package:cloudinary_public/cloudinary_public.dart'; // Cloudinary වලට යවන්න
import 'dart:io';
import 'home_screen.dart';

class SetupProfileScreen extends StatefulWidget {
  const SetupProfileScreen({super.key});

  @override
  State<SetupProfileScreen> createState() => _SetupProfileScreenState();
}

class _SetupProfileScreenState extends State<SetupProfileScreen> {
  final _nameController = TextEditingController();
  bool _isLoading = false;
  File? _imageFile;

  // ✅ ඔයාගේ Cloudinary විස්තර මම මෙතනට දැම්මා
  final cloudinary = CloudinaryPublic('ds974lczz', 'fulvalgc', cache: false);

  // 1. ගැලරි එකෙන් ෆොටෝ එකක් තෝරාගැනීම
  Future<void> _pickImage() async {
    try {
      final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() => _imageFile = File(pickedFile.path));
      }
    } catch (e) {
      print("Error picking image: $e");
    }
  }

  // 2. Profile එක Save කිරීම (Upload + Firestore)
  void _saveProfile() async {
    if (_nameController.text.trim().isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter your name")));
       return;
    }

    setState(() => _isLoading = true);
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      String? photoUrl;

      // ෆොටෝ එකක් තෝරාගෙන ඇත්නම් Upload කරන්න
      if (_imageFile != null) {
        try {
          print("Uploading image...");
          CloudinaryResponse response = await cloudinary.uploadFile(
            CloudinaryFile.fromFile(_imageFile!.path, resourceType: CloudinaryResourceType.Image),
          );
          photoUrl = response.secureUrl; // අපිට ලැබෙන Link එක
          print("Upload Success: $photoUrl");
        } catch (e) {
          print("Upload Error: $e");
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Image Upload Failed: $e")));
          setState(() => _isLoading = false);
          return;
        }
      }

      // විස්තර Database එකට දාන්න
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'name': _nameController.text.trim(),
        'phone': user.phoneNumber,
        'photoUrl': photoUrl, // ෆොටෝ නැත්නම් null වැටෙයි
        'createdAt': Timestamp.now(),
      }, SetOptions(merge: true));

      if (mounted) {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (context) => const HomeScreen()));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(title: const Text("Setup Profile"), backgroundColor: const Color(0xFF1A1A2E)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            
            // Profile Photo තෝරන රවුම
            GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 60,
                backgroundColor: const Color(0xFF2B2B3D),
                backgroundImage: _imageFile != null ? FileImage(_imageFile!) : null,
                child: _imageFile == null
                    ? const Icon(Icons.add_a_photo, size: 40, color: Color(0xFF6F00FF))
                    : null,
              ),
            ),
            const SizedBox(height: 10),
            const Text("Tap to add photo", style: TextStyle(color: Colors.grey)),
            
            const SizedBox(height: 30),
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Display Name",
                labelStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: const Icon(Icons.person, color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFF1A1A2E),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 30),
            
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6F00FF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("SAVE & CONTINUE", style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            )
          ],
        ),
      ),
    );
  }
}