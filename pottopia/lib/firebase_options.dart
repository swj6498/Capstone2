
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
    apiKey: 'AIzaSyAeNrhQ4IE052mqNGeuOQvatFqf2NLlGrU',
    appId: '1:267453229231:web:300095a6b9cfb67b188c5a',
    messagingSenderId: '267453229231',
    projectId: 'pottopia',
    authDomain: 'pottopia.firebaseapp.com',
    storageBucket: 'pottopia.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDtHhKH1mXclCKd4lgrlkCV9j2PpywIenI',
    appId: '1:267453229231:android:54b9bbe2da92a274188c5a',
    messagingSenderId: '267453229231',
    projectId: 'pottopia',
    storageBucket: 'pottopia.firebasestorage.app',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCNoIrq2Skw7GMJoUV5MZMPa1QOjX0LMAo',
    appId: '1:267453229231:ios:6a88069482306411188c5a',
    messagingSenderId: '267453229231',
    projectId: 'pottopia',
    storageBucket: 'pottopia.firebasestorage.app',
    iosBundleId: 'com.example.pottopia',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyAeNrhQ4IE052mqNGeuOQvatFqf2NLlGrU',
    appId: '1:267453229231:web:5ebb4477f644a741188c5a',
    messagingSenderId: '267453229231',
    projectId: 'pottopia',
    authDomain: 'pottopia.firebaseapp.com',
    storageBucket: 'pottopia.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCNoIrq2Skw7GMJoUV5MZMPa1QOjX0LMAo',
    appId: '1:267453229231:ios:6a88069482306411188c5a',
    messagingSenderId: '267453229231',
    projectId: 'pottopia',
    storageBucket: 'pottopia.firebasestorage.app',
    iosBundleId: 'com.example.pottopia',
  );

}