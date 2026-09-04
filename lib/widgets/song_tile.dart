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

  /// Optional hint from a caller that already knows the answer (the Downloads
  /// screen), so the row doesn't flash "unavailable offline" for one frame
  /// while the async check runs.
  final bool initiallyDownloaded;

  const SongTile({
    super.key,
    required this.song,
    required this.onPlay,
    required this.isOnline,
    this.onDeleteDownload,
    this.initiallyDownloaded = false,
  });

  @override
  State<SongTile> createState() => _SongTileState();
}

class _SongTileState extends State<SongTile> {
  final _downloads = DownloadService();
  late DownloadState _state;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _state = widget.initiallyDownloaded
        ? DownloadState.downloaded
        : DownloadState.notDownloaded;
    _refreshState();
  }

  @override
  void didUpdateWidget(SongTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // ListView recycles State objects by position, so a rebuilt list can hand
    // this tile a different song. Without this the row would keep showing the
    // previous song's download state.
    if (oldWidget.song.id != widget.song.id) {
      _progress = 0;
      _state = widget.initiallyDownloaded
          ? DownloadState.downloaded
          : DownloadState.notDownloaded;
      _refreshState();
    }
  }

  Future<void> _refreshState() async {
    final downloaded = await _downloads.isDownloaded(widget.song.id);
    if (!mounted) return;
    setState(() =>
        _state = downloaded ? DownloadState.downloaded : DownloadState.notDownloaded);
  }

  Future<void> _startDownload() async {
    // Captured before the first await — reading it off `context` afterwards is
    // unsafe once this tile may have been disposed.
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _state = DownloadState.downloading;
      _progress = 0;
    });

    await _downloads.downloadSong(
      widget.song,
      // Fires once per network chunk, so only rebuild on visible movement
      // rather than hundreds of times per download.
      onProgress: (p) {
        if (mounted && (p - _progress).abs() >= 0.01) {
          setState(() => _progress = p);
        }
      },
      onComplete: () {
        if (mounted) setState(() => _state = DownloadState.downloaded);
      },
      onError: (msg) {
        if (mounted) setState(() => _state = DownloadState.failed);
        messenger.showSnackBar(SnackBar(content: Text(msg)));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final unavailableOffline = !widget.isOnline && _state != DownloadState.downloaded;

    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SongCover(coverUrl: widget.song.coverUrl, size: 48),
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
              child: Tooltip(
                message: 'Unavailable offline',
                child: Icon(Icons.cloud_off, size: 20),
              ),
            )
          else if (widget.onDeleteDownload != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Remove download',
              onPressed: widget.onDeleteDownload,
            )
          else if (_state == DownloadState.downloading)
            SizedBox(
              width: 24, height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                value: _progress > 0 ? _progress : null,
              ),
            )
          else if (_state == DownloadState.downloaded)
            const Tooltip(
              message: 'Available offline',
              child: Icon(Icons.download_done, size: 20),
            )
          else
            IconButton(
              icon: Icon(_state == DownloadState.failed
                  ? Icons.refresh
                  : Icons.download_outlined),
              tooltip: _state == DownloadState.failed
                  ? 'Retry download'
                  : 'Download for offline',
              onPressed: widget.isOnline ? _startDownload : null,
            ),
          IconButton(
            icon: const Icon(Icons.play_circle_fill, size: 32),
            tooltip: 'Play',
            onPressed: unavailableOffline ? null : widget.onPlay,
          ),
        ],
      ),
    );
  }
}

/// Shared cover-art box: network image when there is one, themed music-note
/// placeholder otherwise. Keeps Home, Search, Downloads and the player
/// consistent instead of each rolling its own fallback.
class SongCover extends StatelessWidget {
  final String coverUrl;
  final double size;

  /// Defaults to half the box size.
  final double? iconSize;

  const SongCover({
    super.key,
    required this.coverUrl,
    required this.size,
    this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: size,
      height: size,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(Icons.music_note, size: iconSize ?? size / 2),
    );

    if (coverUrl.isEmpty) return placeholder;

    return CachedNetworkImage(
      imageUrl: coverUrl,
      width: size,
      height: size,
      fit: BoxFit.cover,
      placeholder: (_, __) => placeholder,
      errorWidget: (_, __, ___) => placeholder,
    );
  }
}
