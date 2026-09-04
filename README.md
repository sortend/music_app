# My Music — Personal Cloud Music App

A small Flutter/Firebase Android app: upload your own/licensed songs once,
then stream or download them for offline playback on any device logged
into the same account.

**Storage note:** Firebase Storage now requires the paid Blaze plan, so
this project uses **Cloudinary** (free, no card required) to host audio
files and cover images instead. Firebase is still used for Auth
(login) and Firestore (song metadata/search) — both fully free.

## What's included

```
lib/
  models/song.dart              Song data model (Firestore doc <-> Dart object)
  services/
    auth_service.dart           Firebase Auth (email/password)
    firestore_service.dart      Song metadata: list, search, add, delete
    storage_service.dart        Uploads audio/covers to Cloudinary, returns public URLs
    download_service.dart       Local download manager (progress, dedupe, delete)
    player_service.dart         Playback: local-file-first, else stream; background audio
  screens/
    login_screen.dart
    home_screen.dart            Search bar, recently added, all songs, downloads shortcut
    search_screen.dart          Search by title/artist/album
    downloads_screen.dart       Offline-first: local songs, delete local copy
    player_screen.dart          Full player: cover, progress, controls, volume
    admin_upload_screen.dart    Upload form: title/artist/album/cover/audio
  widgets/
    song_tile.dart              Shared row: cover, title, artist, download + play
    mini_player.dart            Bottom bar shown across screens
  main.dart                     App entry, providers, auth gate
  firebase_options.dart         Filled in with your Firebase project's real values
firestore.rules                 Only authenticated users can read/write songs
android/app/src/main/AndroidManifest.xml   Permissions + background-audio service
```

## Setup

This copy is already connected to the Firebase project **musicplayer-4e276**
(Android package `app.musicplayer`) — `android/app/google-services.json`
and `lib/firebase_options.dart` are filled in with real values.

Still required before it runs:

### 1. Firebase (Auth + Firestore only — stay on the free Spark plan)

In the Firebase Console for this project, enable:
- Authentication → Email/Password sign-in method
- Firestore Database (start in production mode)

Deploy the Firestore rules (requires Node.js + Firebase CLI: `npm i -g firebase-tools`):
```
firebase login
firebase use musicplayer-4e276
firebase deploy --only firestore:rules
```
(Skip this and Firestore stays locked — production mode blocks all
access until rules are deployed.)

### 2. Cloudinary (free — hosts the actual audio/cover files)

1. Create a free account at cloudinary.com
2. On your Dashboard, copy your **Cloud name**
3. Go to Settings → Upload → Upload presets → "Add upload preset"
   - Set **Signing Mode** to **Unsigned** (required — lets the app upload
     directly without a backend server)
   - Save, then copy the preset name
4. Open `lib/services/storage_service.dart` and replace:
   ```dart
   static const String cloudName = 'REPLACE_WITH_YOUR_CLOUD_NAME';
   static const String uploadPreset = 'REPLACE_WITH_YOUR_UNSIGNED_PRESET';
   ```
   with your actual cloud name and preset name.

Cloudinary's free tier (25GB storage, 25GB bandwidth/month) is plenty
for a personal library.

### 3. Build and run (needs Flutter SDK + Android Studio or a device)

```
flutter pub get
flutter run
```
Or to produce an installable APK directly:
```
flutter build apk --release
```
The APK will be at `build/app/outputs/flutter-apk/app-release.apk`.

## How the core requirements map to the code

- **Upload once, see everywhere** — `admin_upload_screen.dart` uploads the
  audio/cover to Cloudinary (which returns a permanent public URL) and
  writes that URL + metadata to Firestore `songs/{songId}`; every device
  just reads that same Firestore collection.
- **Stream without full download** — `player_service.dart` calls
  `AudioSource.uri()` on the Cloudinary HTTPS URL; `just_audio` streams it
  progressively rather than downloading first.
- **Download for offline** — `download_service.dart` streams the file to
  a temp path and only renames it into place once complete (so an
  interrupted download can't masquerade as a finished one), tracks
  downloaded IDs in `SharedPreferences`, and skips re-downloading if a
  song is already present.
- **Offline mode** — `home_screen.dart` and `downloads_screen.dart` check
  connectivity via `connectivity_plus`; the Downloads screen never touches
  the network to list what's available, and online-only songs show a
  "cloud off" indicator and disabled play/download buttons.
- **Multi-device** — nothing device-specific is stored in Firestore/Cloudinary;
  only the local download cache and SharedPreferences record are per-device.
- **Delete download ≠ delete song** — `download_service.deleteDownload()`
  only removes the local file and local record; the Cloudinary original
  and Firestore entry are never touched.
- **Background playback** — `just_audio_background` + the Android
  `AudioService`/`MediaButtonReceiver` entries in the manifest give
  lockscreen/notification controls.

## Notes / things to double check before shipping

- Cloudinary's unsigned upload preset means anyone with your cloud
  name + preset could technically upload to your account. For a
  personal app this is a reasonable tradeoff (no card, no server), but
  don't share those values publicly. If that matters more later, switch
  to a signed upload flow via a small backend function.
- `firestore_service.searchSongs()` does a client-side filter, which is
  fine for a personal library (hundreds/low thousands of songs).
- The admin upload screen has no separate "admin role" — any authenticated
  user of the app can upload, matching a single-owner personal app.
- iOS isn't wired up (Android-only per the spec).
- Only upload audio you own or are licensed to distribute.
