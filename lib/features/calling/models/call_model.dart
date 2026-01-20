/// Call Feature Models - Completely isolated from existing User/Message models
/// Follows Open/Closed Principle - Does NOT modify existing data structures

import 'package:cloud_firestore/cloud_firestore.dart';

/// Call Status Enum
enum CallStatus {
  ringing,
  answered,
  rejected,
  missed,
  ended,
  busy;

  String get displayName {
    switch (this) {
      case CallStatus.ringing:
        return 'Ringing...';
      case CallStatus.answered:
        return 'Connected';
      case CallStatus.rejected:
        return 'Rejected';
      case CallStatus.missed:
        return 'Missed';
      case CallStatus.ended:
        return 'Ended';
      case CallStatus.busy:
        return 'Busy';
    }
  }
}

/// Call Type Enum
enum CallType {
  audio,
  video;

  String get displayName => this == CallType.audio ? 'Audio Call' : 'Video Call';
}

/// Call Model - Completely separate from existing Message model
class CallModel {
  final String callId;
  final String channelId; // Agora channel ID
  final String callerId;
  final String callerName;
  final String callerPhotoUrl;
  final String receiverId;
  final String receiverName;
  final String receiverPhotoUrl;
  final CallType callType;
  final CallStatus status;
  final DateTime timestamp;
  final DateTime? answeredAt;
  final DateTime? endedAt;
  final int? durationSeconds;

  CallModel({
    required this.callId,
    required this.channelId,
    required this.callerId,
    required this.callerName,
    required this.callerPhotoUrl,
    required this.receiverId,
    required this.receiverName,
    required this.receiverPhotoUrl,
    required this.callType,
    required this.status,
    required this.timestamp,
    this.answeredAt,
    this.endedAt,
    this.durationSeconds,
  });

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'callId': callId,
      'channelId': channelId,
      'callerId': callerId,
      'callerName': callerName,
      'callerPhotoUrl': callerPhotoUrl,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'receiverPhotoUrl': receiverPhotoUrl,
      'callType': callType.name,
      'status': status.name,
      'timestamp': Timestamp.fromDate(timestamp),
      'answeredAt': answeredAt != null ? Timestamp.fromDate(answeredAt!) : null,
      'endedAt': endedAt != null ? Timestamp.fromDate(endedAt!) : null,
      'durationSeconds': durationSeconds,
    };
  }

  /// Create from Firestore document
  factory CallModel.fromFirestore(Map<String, dynamic> data) {
    return CallModel(
      callId: data['callId'] ?? '',
      channelId: data['channelId'] ?? '',
      callerId: data['callerId'] ?? '',
      callerName: data['callerName'] ?? '',
      callerPhotoUrl: data['callerPhotoUrl'] ?? '',
      receiverId: data['receiverId'] ?? '',
      receiverName: data['receiverName'] ?? '',
      receiverPhotoUrl: data['receiverPhotoUrl'] ?? '',
      callType: CallType.values.firstWhere(
        (e) => e.name == data['callType'],
        orElse: () => CallType.audio,
      ),
      status: CallStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => CallStatus.ended,
      ),
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      answeredAt: data['answeredAt'] != null
          ? (data['answeredAt'] as Timestamp).toDate()
          : null,
      endedAt: data['endedAt'] != null
          ? (data['endedAt'] as Timestamp).toDate()
          : null,
      durationSeconds: data['durationSeconds'],
    );
  }

  /// Copy with method for state updates
  CallModel copyWith({
    String? callId,
    String? channelId,
    String? callerId,
    String? callerName,
    String? callerPhotoUrl,
    String? receiverId,
    String? receiverName,
    String? receiverPhotoUrl,
    CallType? callType,
    CallStatus? status,
    DateTime? timestamp,
    DateTime? answeredAt,
    DateTime? endedAt,
    int? durationSeconds,
  }) {
    return CallModel(
      callId: callId ?? this.callId,
      channelId: channelId ?? this.channelId,
      callerId: callerId ?? this.callerId,
      callerName: callerName ?? this.callerName,
      callerPhotoUrl: callerPhotoUrl ?? this.callerPhotoUrl,
      receiverId: receiverId ?? this.receiverId,
      receiverName: receiverName ?? this.receiverName,
      receiverPhotoUrl: receiverPhotoUrl ?? this.receiverPhotoUrl,
      callType: callType ?? this.callType,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      answeredAt: answeredAt ?? this.answeredAt,
      endedAt: endedAt ?? this.endedAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
    );
  }

  /// Get formatted duration
  String get formattedDuration {
    if (durationSeconds == null) return '0:00';
    final minutes = durationSeconds! ~/ 60;
    final seconds = durationSeconds! % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// Check if I'm the caller
  bool isCaller(String currentUserId) => callerId == currentUserId;

  /// Get peer ID
  String getPeerId(String currentUserId) {
    return callerId == currentUserId ? receiverId : callerId;
  }

  /// Get peer name
  String getPeerName(String currentUserId) {
    return callerId == currentUserId ? receiverName : callerName;
  }

  /// Get peer photo
  String getPeerPhotoUrl(String currentUserId) {
    return callerId == currentUserId ? receiverPhotoUrl : callerPhotoUrl;
  }
}
