/// ============================================================================
/// EXACT INTEGRATION EXAMPLE FOR LUMORA
/// ============================================================================
/// This file shows the EXACT changes you need to make to integrate calling.
/// Copy these snippets directly into your files.

// ============================================================================
// FILE 1: main.dart (Add 2 lines)
// ============================================================================

/*
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import 'features/calling/services/call_service.dart'; // ← ADD THIS LINE

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Background Message: ${message.messageId}");
}

// ... existing code ...

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true, badge: true, sound: true,
  );
  
  CallService().startListeningForCalls(); // ← ADD THIS LINE

  runApp(const MyApp());
}

// ... rest of your existing code stays the same ...
*/

// ============================================================================
// FILE 2: home_screen.dart (Wrap navigation to ChatScreen)
// ============================================================================

/*
// At the top of file, add this import:
import 'features/calling/widgets/call_feature_wrapper.dart';

// Then find this code in your home_screen.dart (around line 350-360):

// ORIGINAL CODE (find this):
Navigator.push(
  context, 
  MaterialPageRoute(
    builder: (context) => ChatScreen(
      peerId: peerId, 
      peerName: userData['name']
    )
  )
);

// REPLACE WITH THIS:
Navigator.push(
  context, 
  MaterialPageRoute(
    builder: (context) => CallFeatureWrapper(
      peerId: peerId,
      peerName: userData['name'],
      peerPhotoUrl: userData['photoUrl'] ?? '',
      child: ChatScreen(
        peerId: peerId, 
        peerName: userData['name']
      ),
    )
  )
);
*/

// ============================================================================
// FILE 3: call_service.dart (Update Agora App ID)
// ============================================================================

/*
// Open: lib/features/calling/services/call_service.dart
// Find line 20 and replace with your Agora App ID:

// BEFORE:
static const String agoraAppId = 'YOUR_AGORA_APP_ID_HERE';

// AFTER (with your actual App ID from console.agora.io):
static const String agoraAppId = 'a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6';
*/

// ============================================================================
// COMPLETE WORKING EXAMPLE: Wrapping Multiple Routes
// ============================================================================

/*
// If you navigate to ChatScreen from multiple places, wrap each one:

class _HomeScreenState extends State<HomeScreen> {
  
  void navigateToChat(String peerId, String peerName, String? photoUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CallFeatureWrapper(
          peerId: peerId,
          peerName: peerName,
          peerPhotoUrl: photoUrl ?? '',
          child: ChatScreen(peerId: peerId, peerName: peerName),
        ),
      ),
    );
  }

  // Then use it like:
  void onChatTileTapped(String peerId, Map userData) {
    navigateToChat(
      peerId, 
      userData['name'], 
      userData['photoUrl']
    );
  }
}
*/

// ============================================================================
// FIREBASE SECURITY RULES (Copy to Firebase Console)
// ============================================================================

/*
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Your existing rules for users, chats, messages...
    match /users/{userId} {
      allow read, write: if request.auth != null;
    }
    
    match /chats/{chatId} {
      allow read, write: if request.auth != null;
    }
    
    // ADD THIS NEW RULE FOR CALLS:
    match /calls/{callId} {
      allow read: if request.auth != null && 
        (resource.data.callerId == request.auth.uid || 
         resource.data.receiverId == request.auth.uid);
      
      allow create: if request.auth != null && 
        request.resource.data.callerId == request.auth.uid;
      
      allow update, delete: if request.auth != null && 
        (resource.data.callerId == request.auth.uid || 
         resource.data.receiverId == request.auth.uid);
    }
  }
}
*/

// ============================================================================
// TESTING CHECKLIST
// ============================================================================

/*
1. ✅ Run: flutter pub get
2. ✅ Get Agora App ID from console.agora.io
3. ✅ Update call_service.dart with App ID
4. ✅ Add import in home_screen.dart
5. ✅ Wrap ChatScreen navigation
6. ✅ Add CallService init in main.dart
7. ✅ Update Firebase rules
8. ✅ Build: flutter build apk --release
9. ✅ Install on 2 devices
10. ✅ Login with different accounts
11. ✅ Open chat → See purple call button (top right)
12. ✅ Tap call button → Choose audio/video
13. ✅ Other device receives incoming call
14. ✅ Accept → Connected! 🎉
*/

// ============================================================================
// DIRECTORY STRUCTURE AFTER INTEGRATION
// ============================================================================

/*
lumora_chat/
├── lib/
│   ├── main.dart                    ← Modified (2 lines added)
│   ├── home_screen.dart             ← Modified (navigation wrapped)
│   ├── chat_screen.dart             ← Untouched
│   ├── login_screen.dart            ← Untouched
│   ├── profile_screen.dart          ← Untouched
│   │
│   └── features/
│       └── calling/                 ← NEW DIRECTORY
│           ├── models/
│           │   └── call_model.dart
│           ├── services/
│           │   └── call_service.dart
│           ├── screens/
│           │   ├── call_screen.dart
│           │   └── incoming_call_screen.dart
│           ├── widgets/
│           │   └── call_feature_wrapper.dart
│           ├── README.md
│           ├── QUICK_START.dart
│           ├── INTEGRATION_GUIDE.dart
│           └── EXAMPLE.dart         ← This file
│
├── android/
│   └── app/
│       └── src/
│           └── main/
│               └── AndroidManifest.xml  ← Modified (permissions added)
│
└── pubspec.yaml                    ← Modified (dependencies added)
*/

// ============================================================================
// WHAT YOU GET
// ============================================================================

/*
✅ Call button appears in every ChatScreen automatically
✅ Tap button → Bottom sheet with Audio/Video options
✅ Choose call type → Full-screen calling UI
✅ Other user receives incoming call notification
✅ Accept → Connected with audio/video
✅ Call controls: Mute, Speaker, Camera, End
✅ Real-time duration timer
✅ Beautiful animations and transitions
✅ Works between real Android devices
✅ All call data stored in Firebase
✅ Zero modifications to existing features
*/

void main() {
  print('📱 Copy the code snippets above to integrate calling!');
  print('🎯 Only 3 files need changes: main.dart, home_screen.dart, call_service.dart');
  print('✨ Everything else is automatic!');
}
