import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../services/download_service.dart';
import '../services/player_service.dart';
import '../widgets/song_tile.dart';
import '../widgets/mini_player.dart';

/// This screen works with zero network access: the downloaded song list and
/// its metadata both come from local storage, written at download time.
/// (It used to look each song up in Firestore, so a genuinely offline device
/// with a cold cache showed an empty Downloads list.)
class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  final _downloads = DownloadService();
  List<Song> _songs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    final songs = await _downloads.downloadedSongs();
    if (!mounted) return;
    setState(() {
      _songs = songs;
      _loading = false;
    });
  }

  Future<void> _delete(Song song) async {
    final messenger = ScaffoldMessenger.of(context);
    await _downloads.deleteDownload(song.id);
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text('Removed the local copy of "${song.title}".')),
    );
    await _load();
  }

  Future<void> _play(int index) async {
    final player = context.read<PlayerService>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await player.playQueue(_songs, index);
    } catch (_) {
      final error = player.consumeError();
      if (error != null) {
        messenger.showSnackBar(SnackBar(content: Text(error)));
      }
      // The file may have gone missing; re-read local state.
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Downloads'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _songs.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'No downloaded songs yet.\nTap the download icon next to a '
                            'song to keep it on this device.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          itemCount: _songs.length,
                          itemBuilder: (context, i) => SongTile(
                            key: ValueKey(_songs[i].id),
                            song: _songs[i],
                            // Everything listed here is local, so it stays
                            // playable with no connection.
                            isOnline: false,
                            initiallyDownloaded: true,
                            onPlay: () => _play(i),
                            onDeleteDownload: () => _delete(_songs[i]),
                          ),
                        ),
                      ),
          ),
          const MiniPlayer(),
        ],
      ),
    );
  }
}
