/// CallService - Singleton service managing Agora Engine & Firebase Signaling
/// COMPLETELY ISOLATED - Does NOT modify existing chat/auth services
/// Follows Open/Closed Principle

import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/call_model.dart';

class CallService {
  // Singleton pattern
  static final CallService _instance = CallService._internal();
  factory CallService() => _instance;
  CallService._internal();

  // ==================== CONFIGURATION ====================
  // TODO: Replace with your Agora App ID from https://console.agora.io
  static const String agoraAppId = 'YOUR_AGORA_APP_ID_HERE';
  
  // Note: For production, use token server. For testing, you can use null token.
  // Get temp token from: https://console.agora.io/projects

  // ==================== DEPENDENCIES ====================
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  RtcEngine? _agoraEngine;

  // ==================== STATE ====================
  CallModel? _currentCall;
  StreamSubscription<DocumentSnapshot>? _callListener;
  Timer? _callTimer;
  int _callDurationSeconds = 0;

  // ==================== STREAMS ====================
  final StreamController<CallModel?> _incomingCallController =
      StreamController<CallModel?>.broadcast();
  final StreamController<CallModel?> _activeCallController =
      StreamController<CallModel?>.broadcast();
  final StreamController<int> _durationController =
      StreamController<int>.broadcast();

  Stream<CallModel?> get incomingCallStream => _incomingCallController.stream;
  Stream<CallModel?> get activeCallStream => _activeCallController.stream;
  Stream<int> get callDurationStream => _durationController.stream;

  CallModel? get currentCall => _currentCall;
  bool get isInCall => _currentCall != null;

  // ==================== INITIALIZATION ====================
  
  /// Initialize Agora Engine (call once in app lifecycle)
  Future<void> initializeAgora() async {
    if (_agoraEngine != null) return;

    try {
      _agoraEngine = createAgoraRtcEngine();
      await _agoraEngine!.initialize(const RtcEngineContext(
        appId: agoraAppId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ));

      await _agoraEngine!.enableAudio();
      await _agoraEngine!.enableVideo();

      // Register event handlers
      _agoraEngine!.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            debugPrint('✅ Agora: Successfully joined channel ${connection.channelId}');
          },
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            debugPrint('✅ Agora: Remote user $remoteUid joined');
            _updateCallStatus(CallStatus.answered);
          },
          onUserOffline: (RtcConnection connection, int remoteUid,
              UserOfflineReasonType reason) {
            debugPrint('❌ Agora: Remote user $remoteUid left');
            endCall();
          },
          onError: (ErrorCodeType err, String msg) {
            debugPrint('❌ Agora Error: $err - $msg');
          },
        ),
      );

      debugPrint('✅ CallService: Agora Engine initialized');
    } catch (e) {
      debugPrint('❌ CallService: Failed to initialize Agora - $e');
    }
  }

  /// Listen for incoming calls for current user
  void startListeningForCalls() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    // Listen to the active call document for this user
    _callListener = _firestore
        .collection('calls')
        .where('receiverId', isEqualTo: userId)
        .where('status', isEqualTo: CallStatus.ringing.name)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final callData = snapshot.docs.first.data();
        final incomingCall = CallModel.fromFirestore(callData);
        _incomingCallController.add(incomingCall);
        debugPrint('📞 CallService: Incoming call from ${incomingCall.callerName}');
      }
    });
  }

  /// Stop listening for calls
  void stopListeningForCalls() {
    _callListener?.cancel();
    _callListener = null;
  }

  // ==================== PERMISSIONS ====================
  
  Future<bool> _requestPermissions(CallType callType) async {
    final permissions = [Permission.microphone];
    if (callType == CallType.video) {
      permissions.add(Permission.camera);
    }

    final statuses = await permissions.request();
    return statuses.values.every((status) => status.isGranted);
  }

  // ==================== OUTGOING CALL ====================
  
  /// Initiate a call to another user
  Future<CallModel?> makeCall({
    required String receiverId,
    required String receiverName,
    required String receiverPhotoUrl,
    required CallType callType,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        debugPrint('❌ CallService: User not authenticated');
        return null;
      }

      // Check permissions
      final hasPermissions = await _requestPermissions(callType);
      if (!hasPermissions) {
        debugPrint('❌ CallService: Permissions denied');
        return null;
      }

      // Generate unique IDs
      final callId = _firestore.collection('calls').doc().id;
      final channelId = callId; // Use callId as Agora channel

      // Create call model
      final call = CallModel(
        callId: callId,
        channelId: channelId,
        callerId: currentUser.uid,
        callerName: currentUser.displayName ?? 'Unknown',
        callerPhotoUrl: currentUser.photoURL ?? '',
        receiverId: receiverId,
        receiverName: receiverName,
        receiverPhotoUrl: receiverPhotoUrl,
        callType: callType,
        status: CallStatus.ringing,
        timestamp: DateTime.now(),
      );

      // Save to Firestore (this triggers notification to receiver)
      await _firestore.collection('calls').doc(callId).set(call.toFirestore());

      // Set current call
      _currentCall = call;
      _activeCallController.add(call);

      // Join Agora channel
      await _joinAgoraChannel(channelId, currentUser.uid);

      debugPrint('✅ CallService: Call initiated to $receiverName');
      return call;
    } catch (e) {
      debugPrint('❌ CallService: Failed to make call - $e');
      return null;
    }
  }

  // ==================== INCOMING CALL ====================
  
  /// Answer an incoming call
  Future<void> answerCall(CallModel call) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      // Check permissions
      final hasPermissions = await _requestPermissions(call.callType);
      if (!hasPermissions) {
        await rejectCall(call);
        return;
      }

      // Update call status in Firestore
      await _firestore.collection('calls').doc(call.callId).update({
        'status': CallStatus.answered.name,
        'answeredAt': FieldValue.serverTimestamp(),
      });

      // Set current call
      _currentCall = call.copyWith(
        status: CallStatus.answered,
        answeredAt: DateTime.now(),
      );
      _activeCallController.add(_currentCall);
      _incomingCallController.add(null); // Clear incoming call

      // Join Agora channel
      await _joinAgoraChannel(call.channelId, currentUser.uid);

      // Start call timer
      _startCallTimer();

      debugPrint('✅ CallService: Call answered');
    } catch (e) {
      debugPrint('❌ CallService: Failed to answer call - $e');
    }
  }

  /// Reject an incoming call
  Future<void> rejectCall(CallModel call) async {
    try {
      await _firestore.collection('calls').doc(call.callId).update({
        'status': CallStatus.rejected.name,
        'endedAt': FieldValue.serverTimestamp(),
      });

      _incomingCallController.add(null);
      debugPrint('✅ CallService: Call rejected');
    } catch (e) {
      debugPrint('❌ CallService: Failed to reject call - $e');
    }
  }

  // ==================== END CALL ====================
  
  /// End the current active call
  Future<void> endCall() async {
    try {
      if (_currentCall == null) return;

      final callId = _currentCall!.callId;

      // Update Firestore
      await _firestore.collection('calls').doc(callId).update({
        'status': CallStatus.ended.name,
        'endedAt': FieldValue.serverTimestamp(),
        'durationSeconds': _callDurationSeconds,
      });

      // Leave Agora channel
      await _agoraEngine?.leaveChannel();

      // Stop timer
      _callTimer?.cancel();
      _callTimer = null;
      _callDurationSeconds = 0;

      // Clear state
      _currentCall = null;
      _activeCallController.add(null);

      debugPrint('✅ CallService: Call ended');
    } catch (e) {
      debugPrint('❌ CallService: Failed to end call - $e');
    }
  }

  // ==================== AGORA CHANNEL ====================
  
  Future<void> _joinAgoraChannel(String channelId, String userId) async {
    if (_agoraEngine == null) {
      await initializeAgora();
    }

    try {
      // For production, generate token from your server
      // For testing, you can use null or get temp token from Agora Console
      await _agoraEngine!.joinChannel(
        token: '', // Use '' for testing without token
        channelId: channelId,
        uid: userId.hashCode, // Convert string UID to int
        options: const ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileCommunication,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
        ),
      );

      debugPrint('✅ CallService: Joined Agora channel $channelId');
    } catch (e) {
      debugPrint('❌ CallService: Failed to join Agora channel - $e');
    }
  }

  // ==================== CALL CONTROLS ====================
  
  /// Toggle microphone mute
  Future<void> toggleMute() async {
    await _agoraEngine?.muteLocalAudioStream(true);
  }

  /// Toggle speaker
  Future<void> toggleSpeaker(bool enableSpeaker) async {
    await _agoraEngine?.setEnableSpeakerphone(enableSpeaker);
  }

  /// Switch camera (front/back)
  Future<void> switchCamera() async {
    await _agoraEngine?.switchCamera();
  }

  /// Toggle video (for video calls)
  Future<void> toggleVideo(bool enable) async {
    await _agoraEngine?.muteLocalVideoStream(!enable);
  }

  // ==================== HELPERS ====================
  
  void _startCallTimer() {
    _callDurationSeconds = 0;
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _callDurationSeconds++;
      _durationController.add(_callDurationSeconds);
    });
  }

  Future<void> _updateCallStatus(CallStatus status) async {
    if (_currentCall == null) return;
    _currentCall = _currentCall!.copyWith(status: status);
    _activeCallController.add(_currentCall);
  }

  // ==================== CLEANUP ====================
  
  /// Dispose resources
  Future<void> dispose() async {
    await endCall();
    await _callListener?.cancel();
    await _agoraEngine?.leaveChannel();
    await _agoraEngine?.release();
    _agoraEngine = null;
    await _incomingCallController.close();
    await _activeCallController.close();
    await _durationController.close();
    debugPrint('✅ CallService: Disposed');
  }
}
