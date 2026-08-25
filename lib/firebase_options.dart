import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Trasia Firebase is configured for mobile only.');
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'Trasia Firebase is not configured for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBSEOHAIUrRYyZJmHvUayY2I8NCLGDpCNk',
    appId: '1:113461449954:android:06845917923537401fbabb',
    messagingSenderId: '113461449954',
    projectId: 'trasia-3ca75',
    storageBucket: 'trasia-3ca75.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyD3QCr9u7kepQbvWL3ScgtuR9c7mO34JMI',
    appId: '1:113461449954:ios:3b20a5dd6ea1a5c91fbabb',
    messagingSenderId: '113461449954',
    projectId: 'trasia-3ca75',
    storageBucket: 'trasia-3ca75.firebasestorage.app',
    iosBundleId: 'com.example.trasia',
  );
}
