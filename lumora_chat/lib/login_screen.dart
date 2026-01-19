import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'setup_profile_screen.dart'; // අලුත් Profile පිටුව
import 'home_screen.dart';          // අලුත් Home පිටුව

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  String? _verificationId;
  bool _codeSent = false;
  bool _isLoading = false;

  // 1. Phone Number එක Verify කරන කොටස
  Future<void> _verifyPhone() async {
    String number = _phoneController.text.trim();

    if (number.isEmpty || !number.startsWith('+')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter number with Country Code (e.g. +94700000000)")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: number,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _auth.signInWithCredential(credential);
          _checkUserAndNavigate(); // Auto Login වුනොත් මෙතනින් යන්න
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: ${e.message}")),
          );
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _verificationId = verificationId;
            _codeSent = true;
            _isLoading = false;
          });
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          if (mounted) {
             setState(() {
               _verificationId = verificationId;
             });
          }
        },
      );
    } catch (e) {
      setState(() => _isLoading = false);
      print("General Error: $e");
    }
  }

  // 2. OTP Code එක Check කරන කොටස
  Future<void> _signInWithOTP() async {
    String otp = _otpController.text.trim();
    
    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter valid 6-digit OTP")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );
      
      await _auth.signInWithCredential(credential);
      _checkUserAndNavigate(); // Login හරි නම් ඊළඟට යන්න
      
    } on FirebaseAuthException catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Login Failed: ${e.message}")));
    }
  }

  // 3. User පරණ කෙනෙක්ද අලුත් කෙනෙක්ද කියලා බලන කොටස (New Logic)
  void _checkUserAndNavigate() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Database එකේ මේ User ඉන්නවද බලනවා
      var userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      
      if (mounted) {
        setState(() => _isLoading = false);
        
        if (userDoc.exists) {
          // කලින් නම දීලා Register වෙලා නම් -> Home එකට යන්න
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomeScreen()));
        } else {
          // අලුත් කෙනෙක් නම් (නම දීලා නෑ) -> Setup Profile එකට යන්න
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const SetupProfileScreen()));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(25.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.verified_user, size: 70, color: Color(0xFF6F00FF)),
              const SizedBox(height: 20),
              const Text("SECURE LOGIN", 
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
              const SizedBox(height: 40),
              
              if (!_codeSent) 
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.phone_android, color: Colors.grey),
                    hintText: "+94700000000",
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    filled: true,
                    fillColor: const Color(0xFF1A1A2E),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              
              if (_codeSent)
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.lock_clock, color: Colors.grey),
                    hintText: "Enter 6-digit Code",
                    hintStyle: TextStyle(color: Colors.grey[600]),
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
                  onPressed: _isLoading ? null : (_codeSent ? _signInWithOTP : _verifyPhone),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6F00FF),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(_codeSent ? "VERIFY & LOGIN" : "SEND CODE", 
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              
              if (_codeSent)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _codeSent = false;
                      _isLoading = false;
                      _otpController.clear();
                    });
                  }, 
                  child: const Text("Change Number", style: TextStyle(color: Colors.grey))
                )
            ],
          ),
        ),
      ),
    );
  }
}