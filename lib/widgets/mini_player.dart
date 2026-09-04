import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/player_service.dart';
import '../screens/player_screen.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerService>();
    final song = player.currentSong;
    if (song == null) return const SizedBox.shrink();

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PlayerScreen()),
      ),
      child: Container(
        height: 64,
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            const Icon(Icons.music_note, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            IconButton(
              icon: Icon(player.isPlaying ? Icons.pause : Icons.play_arrow),
              onPressed: player.togglePlayPause,
            ),
            IconButton(
              icon: const Icon(Icons.skip_next),
              onPressed: player.next,
            ),
          ],
        ),
      ),
    );
  }
}
