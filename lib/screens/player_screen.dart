import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../services/player_service.dart';
import '../services/download_service.dart';
import '../widgets/song_tile.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final _downloads = DownloadService();

  /// Non-null only while the user is dragging, so the thumb follows the finger
  /// instead of being yanked back by the next position tick.
  double? _dragMs;
  String? _downloadedForId;
  bool _isDownloaded = false;

  static String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  /// Resolved once per song rather than by a FutureBuilder that kicks off a
  /// fresh lookup on every rebuild.
  Future<void> _syncDownloadedFlag(Song song) async {
    if (_downloadedForId == song.id) return;
    _downloadedForId = song.id;
    final downloaded = await _downloads.isDownloaded(song.id);
    if (!mounted || _downloadedForId != song.id) return;
    setState(() => _isDownloaded = downloaded);
  }

  Future<void> _skip(Future<void> Function() action, PlayerService player) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
    } catch (_) {
      final error = player.consumeError();
      if (error != null) {
        messenger.showSnackBar(SnackBar(content: Text(error)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerService>();
    final song = player.currentSong;

    if (song == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Nothing playing')),
      );
    }

    _syncDownloadedFlag(song);
    final total = player.duration;
    final maxMs = total.inMilliseconds > 0 ? total.inMilliseconds.toDouble() : 1.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Now Playing'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Tooltip(
              message: _isDownloaded ? 'Playing the offline copy' : 'Streaming',
              child: Icon(
                _isDownloaded ? Icons.download_done : Icons.cloud_outlined,
                size: 20,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SongCover(coverUrl: song.coverUrl, size: 280, iconSize: 120),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(song.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(song.artist,
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 24),
              StreamBuilder<Duration>(
                stream: player.positionStream,
                builder: (context, snap) {
                  final pos = snap.data ?? Duration.zero;
                  final shownMs =
                      _dragMs ?? pos.inMilliseconds.clamp(0, maxMs.toInt()).toDouble();
                  return Column(
                    children: [
                      Slider(
                        // clamp() only returns double when every argument is
                        // a double, so 0.0 rather than 0 here.
                        value: shownMs.clamp(0.0, maxMs),
                        max: maxMs,
                        // Seeking on every pixel of the drag thrashes the
                        // decoder; commit once on release instead.
                        onChanged: total.inMilliseconds > 0
                            ? (v) => setState(() => _dragMs = v)
                            : null,
                        onChangeEnd: (v) {
                          player.seek(Duration(milliseconds: v.toInt()));
                          setState(() => _dragMs = null);
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_fmt(Duration(milliseconds: shownMs.toInt()))),
                            Text(_fmt(total)),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    iconSize: 40,
                    icon: const Icon(Icons.skip_previous),
                    onPressed: player.hasPrevious
                        ? () => _skip(player.previous, player)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  if (player.isBuffering)
                    const SizedBox(
                      width: 64, height: 64,
                      child: Center(
                        child: SizedBox(
                          width: 32, height: 32,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        ),
                      ),
                    )
                  else
                    IconButton(
                      iconSize: 64,
                      icon: Icon(player.isPlaying
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_filled),
                      onPressed: player.togglePlayPause,
                    ),
                  const SizedBox(width: 16),
                  IconButton(
                    iconSize: 40,
                    icon: const Icon(Icons.skip_next),
                    onPressed:
                        player.hasNext ? () => _skip(player.next, player) : null,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.volume_down, size: 20),
                  Expanded(
                    child: Slider(
                      // Was hardcoded to 1.0, so the thumb never moved.
                      value: player.volume,
                      onChanged: player.setVolume,
                    ),
                  ),
                  const Icon(Icons.volume_up, size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
