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
    apiKey: 'AIzaSyCoGEU3slZZIqmHeY_e830w9ue2roMeDvY',
    appId: '1:382367359308:web:fcb34785fd4d12b2edafe9',
    messagingSenderId: '382367359308',
    projectId: 'gigshield-e38ec',
    authDomain: 'gigshield-e38ec.firebaseapp.com',
    storageBucket: 'gigshield-e38ec.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCoGEU3slZZIqmHeY_e830w9ue2roMeDvY',
    appId: '1:382367359308:android:fcb34785fd4d12b2edafe9',
    messagingSenderId: '382367359308',
    projectId: 'gigshield-e38ec',
    storageBucket: 'gigshield-e38ec.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCoGEU3slZZIqmHeY_e830w9ue2roMeDvY',
    appId: '1:382367359308:ios:fcb34785fd4d12b2edafe9',
    messagingSenderId: '382367359308',
    projectId: 'gigshield-e38ec',
    storageBucket: 'gigshield-e38ec.firebasestorage.app',
    iosBundleId: 'com.example.app',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'REPLACE_ME_WITH_REAL_API_KEY',
    appId: '1:1234567890:ios:1234567890',
    messagingSenderId: '1234567890',
    projectId: 'gigshield-e38ec',
    storageBucket: 'gigshield-e38ec.appspot.com',
    iosBundleId: 'com.example.app',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'REPLACE_ME_WITH_REAL_API_KEY',
    appId: '1:1234567890:web:1234567890',
    messagingSenderId: '1234567890',
    projectId: 'gigshield-e38ec',
    authDomain: 'gigshield-e38ec.firebaseapp.com',
    storageBucket: 'gigshield-e38ec.appspot.com',
  );
}
