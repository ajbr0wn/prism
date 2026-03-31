import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDmd6wE21icwfqqNQK38nlUIvlDXZPPulg',
    appId: '1:1058950519236:android:6038acba9db5304d5c6c91',
    messagingSenderId: '1058950519236',
    projectId: 'app-dev-b74f5',
    storageBucket: 'app-dev-b74f5.firebasestorage.app',
  );
}
