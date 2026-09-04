// Generated from android/app/google-services.json for the
// "musicplayer-4e276" Firebase project (Android app: app.musicplayer).
// If you ever add other platforms (iOS/web), re-run `flutterfire configure`
// to add those blocks here too.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return android;
    }
    throw UnsupportedError(
      'DefaultFirebaseOptions have only been configured for Android in this '
      'template. Run `flutterfire configure` to add other platforms.',
    );
  }

  static const android = FirebaseOptions(
    apiKey: 'AIzaSyCeHfQ7TX4XuReIZ0r3V2j-syyL514MCP0',
    appId: '1:719875909471:android:90bdd270c09e4e390df8ea',
    messagingSenderId: '719875909471',
    projectId: 'musicplayer-4e276',
    storageBucket: 'musicplayer-4e276.firebasestorage.app',
  );
}
