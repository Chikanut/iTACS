import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;



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
    apiKey: 'AIzaSyBL2_WGaWRRJIGO8yVPoIHFQwFiOqPlnvk',
    appId: '1:786984799876:web:2526cb2018bb9020adfcd1',
    messagingSenderId: '786984799876',
    projectId: 'gspp-9e089',
    authDomain: 'gspp-9e089.firebaseapp.com',
    storageBucket: 'gspp-9e089.firebasestorage.app',
    measurementId: 'G-26J77QXPDF',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyANJHbXS9yWpyfLsAXjvDei6LSTC00FfmA',
    appId: '1:786984799876:android:aa7b1f027ba2467fadfcd1',
    messagingSenderId: '786984799876',
    projectId: 'gspp-9e089',
    storageBucket: 'gspp-9e089.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCB6Hw-cVMymuDZW9yscDDGLV-lscoNpT0',
    appId: '1:786984799876:ios:6d55d7878256ea10adfcd1',
    messagingSenderId: '786984799876',
    projectId: 'gspp-9e089',
    storageBucket: 'gspp-9e089.firebasestorage.app',
    iosBundleId: 'com.example.flutterApplication1',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCB6Hw-cVMymuDZW9yscDDGLV-lscoNpT0',
    appId: '1:786984799876:ios:6d55d7878256ea10adfcd1',
    messagingSenderId: '786984799876',
    projectId: 'gspp-9e089',
    storageBucket: 'gspp-9e089.firebasestorage.app',
    iosBundleId: 'com.example.flutterApplication1',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyBL2_WGaWRRJIGO8yVPoIHFQwFiOqPlnvk',
    appId: '1:786984799876:web:e782f2730fe3fe50adfcd1',
    messagingSenderId: '786984799876',
    projectId: 'gspp-9e089',
    authDomain: 'gspp-9e089.firebaseapp.com',
    storageBucket: 'gspp-9e089.firebasestorage.app',
    measurementId: 'G-1VWPSRZLT6',
  );
}

extension DriveApiKey on FirebaseOptions {
  String get apiKeyForDrive => apiKey;
}

String get googleDriveApiKey => DefaultFirebaseOptions.currentPlatform.apiKeyForDrive;