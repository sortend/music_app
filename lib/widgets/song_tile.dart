import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/song.dart';
import '../services/download_service.dart';

/// A single row: cover, title/artist, download state, play button.
/// Used on Home, Search, and Downloads screens.
class SongTile extends StatefulWidget {
  final Song song;
  final VoidCallback onPlay;
  final bool isOnline;
  final VoidCallback? onDeleteDownload; // non-null only on Downloads screen

  const SongTile({
    super.key,
    required this.song,
    required this.onPlay,
    required this.isOnline,
    this.onDeleteDownload,
  });

  @override
  State<SongTile> createState() => _SongTileState();
}

class _SongTileState extends State<SongTile> {
  final _downloads = DownloadService();
  DownloadState _state = DownloadState.notDownloaded;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _refreshState();
  }

  Future<void> _refreshState() async {
    final downloaded = await _downloads.isDownloaded(widget.song.id);
    if (mounted) {
      setState(() => _state = downloaded ? DownloadState.downloaded : DownloadState.notDownloaded);
    }
  }

  Future<void> _startDownload() async {
    setState(() => _state = DownloadState.downloading);
    await _downloads.downloadSong(
      widget.song.id,
      widget.song.audioPath,
      onProgress: (p) => setState(() => _progress = p),
      onComplete: () => setState(() => _state = DownloadState.downloaded),
      onError: (msg) {
        setState(() => _state = DownloadState.failed);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final unavailableOffline = !widget.isOnline && _state != DownloadState.downloaded;

    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: widget.song.coverUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: widget.song.coverUrl,
                width: 48, height: 48, fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const Icon(Icons.music_note, size: 48),
              )
            : Container(
                width: 48, height: 48,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Icon(Icons.music_note),
              ),
      ),
      title: Text(widget.song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        widget.song.artist,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: unavailableOffline ? Theme.of(context).disabledColor : null,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (unavailableOffline)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Tooltip(message: 'Unavailable offline', child: Icon(Icons.cloud_off, size: 20)),
            )
          else if (widget.onDeleteDownload != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: widget.onDeleteDownload,
            )
          else if (_state == DownloadState.downloading)
            SizedBox(
              width: 24, height: 24,
              child: CircularProgressIndicator(strokeWidth: 2, value: _progress > 0 ? _progress : null),
            )
          else if (_state == DownloadState.downloaded)
            const Icon(Icons.download_done, size: 20)
          else
            IconButton(
              icon: const Icon(Icons.download_outlined),
              onPressed: widget.isOnline ? _startDownload : null,
            ),
          IconButton(
            icon: const Icon(Icons.play_circle_fill, size: 32),
            onPressed: unavailableOffline ? null : widget.onPlay,
          ),
        ],
      ),
    );
  }
}
