import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyB3X9b9m7M0nEdJs_qjZzK0WA1uuvNIQgI',
    appId: '1:313094370491:android:611c8a2fae809e51b7259e',
    messagingSenderId: '313094370491',
    projectId: 'allsuri-abab9',
    authDomain: 'allsuri.firebaseapp.com',
    storageBucket: 'allsuri.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB3X9b9m7M0nEdJs_qjZzK0WA1uuvNIQgI',
    appId: '1:313094370491:android:611c8a2fae809e51b7259e',
    messagingSenderId: '313094370491',
    projectId: 'allsuri-abab9',
    storageBucket: 'allsuri.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyB3X9b9m7M0nEdJs_qjZzK0WA1uuvNIQgI',
    appId: '1:313094370491:android:611c8a2fae809e51b7259e',
    messagingSenderId: '313094370491',
    projectId: 'allsuri-abab9',
    storageBucket: 'allsuri.firebasestorage.app',
    iosClientId: '313094370491-abcdefghijklmnop.apps.googleusercontent.com',
    iosBundleId: 'com.ononcompany.allsuri',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyB3X9b9m7M0nEdJs_qjZzK0WA1uuvNIQgI',
    appId: '1:313094370491:android:611c8a2fae809e51b7259e',
    messagingSenderId: '313094370491',
    projectId: 'allsuri-abab9',
    storageBucket: 'allsuri.firebasestorage.app',
    iosClientId: '313094370491-abcdefghijklmnop.apps.googleusercontent.com',
    iosBundleId: 'com.ononcompany.allsuri',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyB3X9b9m7M0nEdJs_qjZzK0WA1uuvNIQgI',
    appId: '1:313094370491:android:611c8a2fae809e51b7259e',
    messagingSenderId: '313094370491',
    projectId: 'allsuri-abab9',
    authDomain: 'allsuri.firebaseapp.com',
    storageBucket: 'allsuri.firebasestorage.app',
  );
} 