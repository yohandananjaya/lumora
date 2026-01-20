/// Incoming Call Screen - Full-screen overlay for incoming calls
/// ISOLATED - Does NOT modify existing UI

import 'package:flutter/material.dart';
import '../models/call_model.dart';
import '../services/call_service.dart';
import 'call_screen.dart';

class IncomingCallScreen extends StatefulWidget {
  final CallModel call;

  const IncomingCallScreen({
    Key? key,
    required this.call,
  }) : super(key: key);

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with SingleTickerProviderStateMixin {
  final CallService _callService = CallService();
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _acceptCall() async {
    await _callService.answerCall(widget.call);
    
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => CallScreen(
            call: widget.call,
            isCaller: false,
          ),
        ),
      );
    }
  }

  void _rejectCall() async {
    await _callService.rejectCall(widget.call);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final callTypeIcon = widget.call.callType == CallType.video
        ? Icons.videocam
        : Icons.phone;
    
    final callTypeText = widget.call.callType == CallType.video
        ? 'Video Call'
        : 'Voice Call';

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF0F0F1A),
              const Color(0xFF1A1A2E).withOpacity(0.9),
              const Color(0xFF0F0F1A),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 60),

              // Call Type Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF6F00FF).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: const Color(0xFF6F00FF)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(callTypeIcon, color: const Color(0xFF6F00FF), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      callTypeText,
                      style: const TextStyle(
                        color: Color(0xFF6F00FF),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 60),

              // Caller Avatar with Pulse Animation
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6F00FF), Color(0xFF00C6FF)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6F00FF).withOpacity(0.4),
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: widget.call.callerPhotoUrl.isNotEmpty
                      ? CircleAvatar(
                          radius: 80,
                          backgroundImage: NetworkImage(widget.call.callerPhotoUrl),
                        )
                      : Center(
                          child: Text(
                            widget.call.callerName[0].toUpperCase(),
                            style: const TextStyle(
                              fontSize: 70,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 40),

              // Caller Name
              Text(
                widget.call.callerName,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 10),

              // Status Text
              Text(
                'Incoming ${widget.call.callType.displayName}...',
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const Spacer(),

              // Ringing Animation
              _buildRingingIndicator(),

              const SizedBox(height: 40),

              // Action Buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Reject Button
                    _buildActionButton(
                      icon: Icons.call_end,
                      label: 'Decline',
                      color: Colors.red,
                      onPressed: _rejectCall,
                    ),

                    // Accept Button
                    _buildActionButton(
                      icon: Icons.call,
                      label: 'Accept',
                      color: Colors.green,
                      onPressed: _acceptCall,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRingingIndicator() {
    return Column(
      children: [
        SizedBox(
          width: 60,
          height: 60,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer Ring 1
              ScaleTransition(
                scale: Tween<double>(begin: 1.0, end: 2.0).animate(
                  CurvedAnimation(
                    parent: _animationController,
                    curve: Curves.easeOut,
                  ),
                ),
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF6F00FF).withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                ),
              ),
              // Inner Circle
              Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF6F00FF),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onPressed,
          child: Container(
            width: 75,
            height: 75,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: 3,
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 35),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
