// File generated manually from google-services.json
// firebase_options.dart — do not edit manually after flutterfire is working

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      default:
        return android;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDo-oHgVM0GLi3oGT_3xCo56ujl93urISA',
    appId: '1:966164606581:android:093c44d7fd81028afdd23c',
    messagingSenderId: '966164606581',
    projectId: 'travelplanner-fortress',
    storageBucket: 'travelplanner-fortress.firebasestorage.app',
  );

  // iOS — paste your GoogleService-Info.plist values here once you have them
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDo-oHgVM0GLi3oGT_3xCo56ujl93urISA',
    appId: '1:966164606581:ios:093c44d7fd81028afdd23c',
    messagingSenderId: '966164606581',
    projectId: 'travelplanner-fortress',
    storageBucket: 'travelplanner-fortress.firebasestorage.app',
    iosClientId: '',
    iosBundleId: 'com.example.travelplannerapp',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDo-oHgVM0GLi3oGT_3xCo56ujl93urISA',
    appId: '1:966164606581:web:093c44d7fd81028afdd23c',
    messagingSenderId: '966164606581',
    projectId: 'travelplanner-fortress',
    storageBucket: 'travelplanner-fortress.firebasestorage.app',
    authDomain: 'travelplanner-fortress.firebaseapp.com',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDo-oHgVM0GLi3oGT_3xCo56ujl93urISA',
    appId: '1:966164606581:ios:093c44d7fd81028afdd23c',
    messagingSenderId: '966164606581',
    projectId: 'travelplanner-fortress',
    storageBucket: 'travelplanner-fortress.firebasestorage.app',
    iosBundleId: 'com.example.travelplannerapp',
  );
}
