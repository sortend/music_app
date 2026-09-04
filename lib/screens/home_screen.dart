import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/song.dart';
import '../services/firestore_service.dart';
import '../services/player_service.dart';
import '../services/auth_service.dart';
import '../widgets/song_tile.dart';
import '../widgets/mini_player.dart';
import 'search_screen.dart';
import 'downloads_screen.dart';
import 'admin_upload_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _firestore = FirestoreService();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    // Held so it can be cancelled — an un-cancelled subscription kept calling
    // setState after this screen was gone.
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      _setOnline(!results.contains(ConnectivityResult.none));
    });
    Connectivity().checkConnectivity().then(
      (results) => _setOnline(!results.contains(ConnectivityResult.none)),
      onError: (_) {
        // Connectivity plugin unavailable: assume online rather than locking
        // the user out of their library.
      },
    );
  }

  void _setOnline(bool online) {
    if (!mounted || _isOnline == online) return;
    setState(() => _isOnline = online);
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  Future<void> _play(List<Song> queue, int index) async {
    final player = context.read<PlayerService>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await player.playQueue(queue, index);
    } catch (_) {
      // playQueue throws a user-readable message when a track can't load;
      // previously this went unhandled and showed up as a red framework error.
      final error = player.consumeError();
      if (error != null) {
        messenger.showSnackBar(SnackBar(content: Text(error)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Music'),
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_upload_outlined),
            tooltip: 'Upload song',
            onPressed: _isOnline
                ? () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AdminUploadScreen()),
                    )
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () => context.read<AuthService>().signOut(),
          ),
        ],
      ),
      body: Column(
        children: [
          if (!_isOnline)
            Container(
              width: double.infinity,
              color: Colors.orange.shade800,
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: const Text('Offline — showing downloaded songs only',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.search),
                    SizedBox(width: 8),
                    Text('Search songs, artists, albums'),
                  ],
                ),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.download_done_outlined),
            title: const Text('Downloads'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DownloadsScreen()),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _isOnline ? _buildOnlineLibrary() : _buildOfflineNotice(),
          ),
          const MiniPlayer(),
        ],
      ),
    );
  }

  Widget _buildOnlineLibrary() {
    return StreamBuilder<List<Song>>(
      stream: _firestore.streamAllSongs(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Could not load songs: ${snapshot.error}',
                  textAlign: TextAlign.center),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final songs = snapshot.data ?? [];
        if (songs.isEmpty) {
          return const Center(child: Text('No songs yet — upload one to get started.'));
        }
        final recent = songs.take(10).toList();
        return ListView(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text('Recently added',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            SizedBox(
              height: 104,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: recent.length,
                itemBuilder: (context, i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: InkWell(
                    onTap: () => _play(songs, i),
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          // Was a bare placeholder icon here even when the
                          // song had cover art.
                          child: SongCover(coverUrl: recent[i].coverUrl, size: 64),
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: 64,
                          child: Text(recent[i].title,
                              maxLines: 2,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text('All songs', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            ...songs.asMap().entries.map((e) => SongTile(
                  key: ValueKey(e.value.id),
                  song: e.value,
                  isOnline: _isOnline,
                  onPlay: () => _play(songs, e.key),
                )),
          ],
        );
      },
    );
  }

  Widget _buildOfflineNotice() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "You're offline. Open Downloads to play songs saved on this device.",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.download_done_outlined),
              label: const Text('Open Downloads'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DownloadsScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
