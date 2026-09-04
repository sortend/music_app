import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../models/song.dart';
import 'download_service.dart';

/// Central playback controller.
///
/// Chooses the local file automatically when a song is downloaded; otherwise
/// streams directly from the song's public HTTPS URL (just_audio streams
/// progressively, so a full download-before-play is never needed).
/// Wired to just_audio_background in main.dart for background/lockscreen
/// playback controls.
class PlayerService extends ChangeNotifier {
  PlayerService() {
    // The player's state also changes from outside the app (lockscreen and
    // notification buttons, audio focus loss, a track ending), so mirror it
    // into ChangeNotifier rather than only notifying from our own methods.
    _stateSub = _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _onTrackFinished();
      }
      notifyListeners();
    });
    // `duration` is null until the source is loaded; re-render once it lands
    // so the progress bar gets a real maximum.
    _durationSub = _player.durationStream.listen((_) => notifyListeners());
  }

  final AudioPlayer _player = AudioPlayer();
  final DownloadService _downloads = DownloadService();

  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<Duration?>? _durationSub;
  bool _disposed = false;

  List<Song> _queue = [];
  int _currentIndex = -1;
  double _volume = 1.0;
  String? _lastError;

  /// Increments on every load so a slow load that's been superseded by a
  /// newer one (rapid next/prev taps) can't overwrite the current track.
  int _loadToken = 0;

  Song? get currentSong => _currentIndex >= 0 && _currentIndex < _queue.length
      ? _queue[_currentIndex]
      : null;

  List<Song> get queue => List.unmodifiable(_queue);
  bool get hasNext => _currentIndex >= 0 && _currentIndex < _queue.length - 1;
  bool get hasPrevious => _currentIndex > 0;

  Stream<Duration> get positionStream => _player.positionStream;
  Duration get duration => _player.duration ?? Duration.zero;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  bool get isPlaying => _player.playing;
  bool get isBuffering =>
      _player.processingState == ProcessingState.loading ||
      _player.processingState == ProcessingState.buffering;
  double get volume => _volume;

  /// Set when a track could not be loaded (offline and not downloaded, dead
  /// URL, ...). Read once by the UI, then cleared.
  String? consumeError() {
    final error = _lastError;
    _lastError = null;
    return error;
  }

  /// Starts [queue] at [startIndex]. Throws if the track cannot be loaded, so
  /// callers can surface a message; the thrown text is user-readable.
  Future<void> playQueue(List<Song> queue, int startIndex) async {
    if (queue.isEmpty) return;
    _queue = List.of(queue);
    _currentIndex = startIndex.clamp(0, _queue.length - 1);
    notifyListeners();
    await _playCurrent();
  }

  Future<void> _playCurrent() async {
    final song = currentSong;
    if (song == null) return;

    final token = ++_loadToken;
    final isLocal = await _downloads.isDownloaded(song.id);
    if (token != _loadToken) return; // superseded while we checked

    final tag = MediaItem(
      id: song.id,
      title: song.title,
      artist: song.artist,
      album: song.album.isNotEmpty ? song.album : null,
      duration: song.durationMs > 0 ? Duration(milliseconds: song.durationMs) : null,
      artUri: song.coverUrl.isNotEmpty ? Uri.tryParse(song.coverUrl) : null,
    );

    try {
      final Uri uri;
      if (isLocal) {
        final file = await _downloads.localFile(song.id);
        uri = Uri.file(file.path);
      } else {
        if (song.audioPath.isEmpty) {
          throw Exception('This song has no audio file attached.');
        }
        uri = Uri.parse(song.audioPath);
      }
      if (token != _loadToken) return;

      await _player.setAudioSource(AudioSource.uri(uri, tag: tag));
      if (token != _loadToken) return;

      await _player.setVolume(_volume);
      await _player.play();
      _lastError = null;
      notifyListeners();
    } catch (e) {
      if (token != _loadToken) return;
      // Online-only song while offline, or the stream URL failed.
      _lastError = isLocal
          ? 'Could not play the downloaded copy of "${song.title}".'
          : '"${song.title}" is not available offline. Download it first.';
      notifyListeners();
      throw Exception(_lastError);
    }
  }

  /// Auto-advance: without this, playback simply stopped at the end of every
  /// track instead of continuing through the queue.
  void _onTrackFinished() {
    if (!hasNext) return;
    // The stream listener can't await, and a failure is already recorded in
    // _lastError, so swallow it here rather than raising an async error.
    unawaited(next().catchError((_) {}));
  }

  Future<void> togglePlayPause() async {
    if (_player.playing) {
      await _player.pause();
    } else {
      // Restart from the top if the previous track ran to completion.
      if (_player.processingState == ProcessingState.completed) {
        await _player.seek(Duration.zero);
      }
      await _player.play();
    }
    notifyListeners();
  }

  Future<void> next() async {
    if (!hasNext) return;
    _currentIndex++;
    notifyListeners();
    await _playCurrent();
  }

  Future<void> previous() async {
    if (!hasPrevious) return;
    _currentIndex--;
    notifyListeners();
    await _playCurrent();
  }

  Future<void> seek(Duration position) => _player.seek(position);

  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    await _player.setVolume(_volume);
    notifyListeners();
  }

  @override
  void notifyListeners() {
    // Stream events can land in the same tick as disposal; notifying then
    // throws in debug builds.
    if (_disposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _stateSub?.cancel();
    _durationSub?.cancel();
    _player.dispose();
    super.dispose();
  }
}
