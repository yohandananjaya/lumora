/// Active Call Screen - Displays during an ongoing call
/// ISOLATED - Does NOT modify existing chat UI

import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import '../models/call_model.dart';
import '../services/call_service.dart';

class CallScreen extends StatefulWidget {
  final CallModel call;
  final bool isCaller;

  const CallScreen({
    Key? key,
    required this.call,
    required this.isCaller,
  }) : super(key: key);

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final CallService _callService = CallService();
  
  bool _isMuted = false;
  bool _isSpeakerOn = true;
  bool _isVideoEnabled = true;
  int _callDuration = 0;
  StreamSubscription? _durationSubscription;

  int? _remoteUid;
  bool _remoteJoined = false;

  @override
  void initState() {
    super.initState();
    _initializeCall();
    _listenToDuration();
  }

  void _initializeCall() async {
    // Register Agora event handler for this screen
    await _callService.initializeAgora();
    
    // Listen for remote user
    _callService._agoraEngine?.registerEventHandler(
      RtcEngineEventHandler(
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          setState(() {
            _remoteUid = remoteUid;
            _remoteJoined = true;
          });
        },
        onUserOffline: (RtcConnection connection, int remoteUid,
            UserOfflineReasonType reason) {
          setState(() {
            _remoteJoined = false;
            _remoteUid = null;
          });
          _endCall();
        },
      ),
    );
  }

  void _listenToDuration() {
    _durationSubscription = _callService.callDurationStream.listen((seconds) {
      setState(() {
        _callDuration = seconds;
      });
    });
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void _toggleMute() {
    setState(() => _isMuted = !_isMuted);
    _callService.toggleMute();
  }

  void _toggleSpeaker() {
    setState(() => _isSpeakerOn = !_isSpeakerOn);
    _callService.toggleSpeaker(_isSpeakerOn);
  }

  void _switchCamera() {
    _callService.switchCamera();
  }

  void _toggleVideo() {
    setState(() => _isVideoEnabled = !_isVideoEnabled);
    _callService.toggleVideo(_isVideoEnabled);
  }

  void _endCall() async {
    await _callService.endCall();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _durationSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final peerName = widget.call.getPeerName(_callService._auth.currentUser!.uid);
    final peerPhoto = widget.call.getPeerPhotoUrl(_callService._auth.currentUser!.uid);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF0F0F1A),
              const Color(0xFF1A1A2E),
              const Color(0xFF0F0F1A),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top Bar
              _buildTopBar(),
              
              const Spacer(),

              // Video View (for video calls)
              if (widget.call.callType == CallType.video)
                _buildVideoView()
              else
                _buildAudioView(peerName, peerPhoto),

              const Spacer(),

              // Call Status
              _buildCallStatus(peerName),

              const SizedBox(height: 40),

              // Control Buttons
              _buildControls(),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _formatDuration(_callDuration),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (widget.call.callType == CallType.video)
            IconButton(
              onPressed: _switchCamera,
              icon: const Icon(Icons.cameraswitch, color: Colors.white),
              iconSize: 28,
            ),
        ],
      ),
    );
  }

  Widget _buildVideoView() {
    return Expanded(
      child: Stack(
        children: [
          // Remote Video (Full Screen)
          if (_remoteJoined && _remoteUid != null)
            AgoraVideoView(
              controller: VideoViewController.remote(
                rtcEngine: _callService._agoraEngine!,
                canvas: VideoCanvas(uid: _remoteUid),
                connection: RtcConnection(channelId: widget.call.channelId),
              ),
            )
          else
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Color(0xFF6F00FF)),
                  const SizedBox(height: 20),
                  Text(
                    'Waiting for ${widget.call.getPeerName(_callService._auth.currentUser!.uid)}...',
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ],
              ),
            ),

          // Local Video (Picture-in-Picture)
          if (_isVideoEnabled)
            Positioned(
              top: 20,
              right: 20,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 120,
                  height: 160,
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF6F00FF), width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: AgoraVideoView(
                    controller: VideoViewController(
                      rtcEngine: _callService._agoraEngine!,
                      canvas: const VideoCanvas(uid: 0),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAudioView(String peerName, String peerPhoto) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Avatar
        Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF6F00FF), Color(0xFF00C6FF)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6F00FF).withOpacity(0.3),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: peerPhoto.isNotEmpty
              ? CircleAvatar(
                  radius: 70,
                  backgroundImage: NetworkImage(peerPhoto),
                )
              : Center(
                  child: Text(
                    peerName[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 60,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 30),

        // Name
        Text(
          peerName,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildCallStatus(String peerName) {
    String status = _remoteJoined ? 'Connected' : 'Ringing...';
    
    return Column(
      children: [
        Text(
          status,
          style: TextStyle(
            fontSize: 18,
            color: _remoteJoined ? const Color(0xFF00C6FF) : Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (!_remoteJoined) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[600]!),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Mute Button
          _buildControlButton(
            icon: _isMuted ? Icons.mic_off : Icons.mic,
            color: _isMuted ? Colors.red : Colors.white,
            backgroundColor: _isMuted ? Colors.red.withOpacity(0.2) : Colors.white24,
            onPressed: _toggleMute,
          ),

          // Speaker Button (Audio) / Video Toggle (Video)
          if (widget.call.callType == CallType.audio)
            _buildControlButton(
              icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_off,
              color: Colors.white,
              backgroundColor: Colors.white24,
              onPressed: _toggleSpeaker,
            )
          else
            _buildControlButton(
              icon: _isVideoEnabled ? Icons.videocam : Icons.videocam_off,
              color: _isVideoEnabled ? Colors.white : Colors.red,
              backgroundColor: _isVideoEnabled ? Colors.white24 : Colors.red.withOpacity(0.2),
              onPressed: _toggleVideo,
            ),

          // End Call Button
          _buildControlButton(
            icon: Icons.call_end,
            color: Colors.white,
            backgroundColor: Colors.red,
            onPressed: _endCall,
            size: 70,
            iconSize: 35,
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required Color color,
    required Color backgroundColor,
    required VoidCallback onPressed,
    double size = 60,
    double iconSize = 28,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: backgroundColor.withOpacity(0.3),
              blurRadius: 15,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Icon(icon, color: color, size: iconSize),
      ),
    );
  }
}
