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
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    Connectivity().onConnectivityChanged.listen((results) {
      final online = !results.contains(ConnectivityResult.none);
      if (mounted) setState(() => _isOnline = online);
    });
    Connectivity().checkConnectivity().then((results) {
      if (mounted) setState(() => _isOnline = !results.contains(ConnectivityResult.none));
    });
  }

  void _play(List<Song> queue, int index) {
    context.read<PlayerService>().playQueue(queue, index);
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
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AdminUploadScreen()),
            ),
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
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: const [
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
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Could not load songs: ${snapshot.error}'));
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
              child: Text('Recently added', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            SizedBox(
              height: 96,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: recent.length,
                itemBuilder: (context, i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: () => _play(songs, i),
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 64, height: 64,
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            child: const Icon(Icons.music_note),
                          ),
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: 64,
                          child: Text(recent[i].title, maxLines: 1,
                              overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
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
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'You\'re offline. Open Downloads to play songs saved on this device.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
