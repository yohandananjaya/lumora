/// CallFeatureWrapper - Wraps existing screens to add calling functionality
/// Follows Open/Closed Principle - Does NOT modify existing ChatScreen
/// Uses Stack to overlay call UI on top of existing content

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/call_model.dart';
import '../services/call_service.dart';
import '../screens/incoming_call_screen.dart';
import '../screens/call_screen.dart';

class CallFeatureWrapper extends StatefulWidget {
  final Widget child;
  final String? peerId; // Optional: If wrapping ChatScreen, pass peer info
  final String? peerName;
  final String? peerPhotoUrl;

  const CallFeatureWrapper({
    Key? key,
    required this.child,
    this.peerId,
    this.peerName,
    this.peerPhotoUrl,
  }) : super(key: key);

  @override
  State<CallFeatureWrapper> createState() => _CallFeatureWrapperState();
}

class _CallFeatureWrapperState extends State<CallFeatureWrapper> {
  final CallService _callService = CallService();
  StreamSubscription? _incomingCallSubscription;
  CallModel? _incomingCall;

  @override
  void initState() {
    super.initState();
    _initializeCallFeature();
  }

  void _initializeCallFeature() async {
    // Initialize Agora Engine
    await _callService.initializeAgora();
    
    // Start listening for incoming calls
    _callService.startListeningForCalls();
    
    // Subscribe to incoming call stream
    _incomingCallSubscription = _callService.incomingCallStream.listen((call) {
      if (call != null && mounted) {
        setState(() => _incomingCall = call);
        _showIncomingCallDialog(call);
      } else {
        setState(() => _incomingCall = null);
      }
    });
  }

  void _showIncomingCallDialog(CallModel call) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => IncomingCallScreen(call: call),
    ).then((_) {
      // Clear incoming call after dialog closes
      setState(() => _incomingCall = null);
    });
  }

  Future<void> _initiateCall(CallType callType) async {
    if (widget.peerId == null || widget.peerName == null) {
      _showSnackBar('Cannot make call: Peer information missing');
      return;
    }

    // Show loading indicator
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Color(0xFF6F00FF)),
        ),
      );
    }

    final call = await _callService.makeCall(
      receiverId: widget.peerId!,
      receiverName: widget.peerName!,
      receiverPhotoUrl: widget.peerPhotoUrl ?? '',
      callType: callType,
    );

    // Remove loading indicator
    if (mounted) {
      Navigator.of(context).pop();
    }

    if (call != null && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => CallScreen(call: call, isCaller: true),
        ),
      );
    } else {
      _showSnackBar('Failed to initiate call. Check permissions.');
    }
  }

  void _showCallOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                
                // Audio Call Option
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00C6FF).withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.phone,
                      color: Color(0xFF00C6FF),
                      size: 24,
                    ),
                  ),
                  title: const Text(
                    'Voice Call',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: const Text(
                    'Make an audio call',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _initiateCall(CallType.audio);
                  },
                ),
                
                const Divider(color: Colors.grey, height: 1),
                
                // Video Call Option
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6F00FF).withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.videocam,
                      color: Color(0xFF6F00FF),
                      size: 24,
                    ),
                  ),
                  title: const Text(
                    'Video Call',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: const Text(
                    'Make a video call',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _initiateCall(CallType.video);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF1A1A2E),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _incomingCallSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Original Child (e.g., ChatScreen)
        widget.child,
        
        // Overlay Call Button (Only if peer info is provided - i.e., in ChatScreen)
        if (widget.peerId != null && widget.peerName != null)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 60, // Positioned before profile icon
            child: _buildCallButton(),
          ),
      ],
    );
  }

  Widget _buildCallButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _showCallOptions,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF6F00FF).withOpacity(0.9),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6F00FF).withOpacity(0.3),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(
            Icons.phone,
            color: Colors.white,
            size: 22,
          ),
        ),
      ),
    );
  }
}

/// Extension: Easily wrap any screen with calling functionality
extension CallableScreen on Widget {
  Widget withCallFeature({
    String? peerId,
    String? peerName,
    String? peerPhotoUrl,
  }) {
    return CallFeatureWrapper(
      peerId: peerId,
      peerName: peerName,
      peerPhotoUrl: peerPhotoUrl,
      child: this,
    );
  }
}
