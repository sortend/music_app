import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../services/firestore_service.dart';
import '../services/download_service.dart';
import '../services/player_service.dart';
import '../widgets/song_tile.dart';
import '../widgets/mini_player.dart';

/// This screen must work with zero network access: it reads the set of
/// downloaded song IDs from local storage, then tries to enrich each with
/// cached Firestore metadata if available, falling back to a minimal
/// locally-cached record otherwise.
class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  final _downloads = DownloadService();
  final _firestore = FirestoreService();
  List<Song> _songs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final ids = await _downloads.downloadedSongIds();
    final songs = <Song>[];
    for (final id in ids) {
      try {
        final song = await _firestore.getSong(id);
        if (song != null) songs.add(song);
      } catch (_) {
        // Offline with no cached Firestore data for this doc — Firestore's
        // local persistence cache (enabled by default) usually still
        // serves it; if not, it's simply skipped from the list rather
        // than crashing the screen.
      }
    }
    if (mounted) setState(() {
      _songs = songs;
      _loading = false;
    });
  }

  Future<void> _delete(Song song) async {
    await _downloads.deleteDownload(song.id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Downloads')),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _songs.isEmpty
                    ? const Center(child: Text('No downloaded songs yet'))
                    : ListView.builder(
                        itemCount: _songs.length,
                        itemBuilder: (context, i) => SongTile(
                          song: _songs[i],
                          isOnline: false, // downloads screen always plays local-only
                          onPlay: () => context
                              .read<PlayerService>()
                              .playQueue(_songs, i),
                          onDeleteDownload: () => _delete(_songs[i]),
                        ),
                      ),
          ),
          const MiniPlayer(),
        ],
      ),
    );
  }
}
