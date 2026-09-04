import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/player_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // A failure here (no google-services.json, Firestore/Auth not enabled in
  // the console, ...) used to leave a blank screen with the reason only
  // visible in the device log.
  String? startupError;
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

    // Enables lockscreen/notification playback controls for background playback.
    await JustAudioBackground.init(
      androidNotificationChannelId: 'app.musicplayer.channel.audio',
      androidNotificationChannelName: 'Music playback',
      androidNotificationOngoing: true,
    );
  } catch (e) {
    startupError = '$e';
  }

  runApp(startupError == null ? const MusicApp() : StartupErrorApp(message: startupError));
}

ThemeData _theme() => ThemeData(
      colorSchemeSeed: const Color(0xFF6C4CE0),
      brightness: Brightness.dark,
      useMaterial3: true,
    );

class MusicApp extends StatelessWidget {
  const MusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        ChangeNotifierProvider<PlayerService>(create: (_) => PlayerService()),
      ],
      child: MaterialApp(
        title: 'My Music',
        debugShowCheckedModeBanner: false,
        theme: _theme(),
        home: const AuthGate(),
      ),
    );
  }
}

/// Shown instead of a blank screen when Firebase can't start up.
class StartupErrorApp extends StatelessWidget {
  final String message;

  const StartupErrorApp({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Music',
      debugShowCheckedModeBanner: false,
      theme: _theme(),
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 16),
                const Text(
                  "My Music couldn't start",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Check that Firebase Auth and Firestore are enabled for this '
                  'project (see README.md).',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(message, textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: Colors.white54)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows the login screen or the home screen depending on auth state,
/// and reacts automatically if the user signs in/out on any device.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    return StreamBuilder(
      stream: auth.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasData) {
          return const HomeScreen();
        }
        return const LoginScreen();
      },
    );
  }
}
