import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/player_service.dart';
import '../services/download_service.dart';

class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key});

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerService>();
    final song = player.currentSong;

    if (song == null) {
      return const Scaffold(body: Center(child: Text('Nothing playing')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Now Playing'),
        actions: [
          FutureBuilder<bool>(
            future: DownloadService().isDownloaded(song.id),
            builder: (context, snap) {
              final downloaded = snap.data == true;
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(downloaded ? Icons.download_done : Icons.cloud_outlined, size: 20),
              );
            },
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
                    child: song.coverUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: song.coverUrl, width: 280, height: 280, fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => const Icon(Icons.music_note, size: 120),
                          )
                        : Container(
                            width: 280, height: 280,
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            child: const Icon(Icons.music_note, size: 120),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(song.title, style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(song.artist, style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              StreamBuilder<Duration>(
                stream: player.positionStream,
                builder: (context, snap) {
                  final pos = snap.data ?? Duration.zero;
                  final total = player.duration;
                  final maxMs = total.inMilliseconds > 0 ? total.inMilliseconds.toDouble() : 1.0;
                  return Column(
                    children: [
                      Slider(
                        value: pos.inMilliseconds.clamp(0, maxMs.toInt()).toDouble(),
                        max: maxMs,
                        onChanged: (v) => player.seek(Duration(milliseconds: v.toInt())),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_fmt(pos)),
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
                    onPressed: player.previous,
                  ),
                  const SizedBox(width: 16),
                  StreamBuilder(
                    stream: player.playerStateStream,
                    builder: (context, snap) {
                      return IconButton(
                        iconSize: 64,
                        icon: Icon(player.isPlaying
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_filled),
                        onPressed: player.togglePlayPause,
                      );
                    },
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    iconSize: 40,
                    icon: const Icon(Icons.skip_next),
                    onPressed: player.next,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.volume_down, size: 20),
                  Expanded(
                    child: Slider(
                      value: 1.0,
                      onChanged: (v) => player.setVolume(v),
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
