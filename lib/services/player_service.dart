import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:flutter/foundation.dart';
import '../models/song.dart';
import 'storage_service.dart';
import 'download_service.dart';

/// Central playback controller.
///
/// Chooses the local file automatically when a song is downloaded;
/// otherwise streams directly from Firebase Storage's HTTPS URL (just_audio
/// streams progressively, so full download-before-play is never needed).
/// Wired to just_audio_background in main.dart for background/lockscreen
/// playback controls.
class PlayerService extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();
  final StorageService _storage = StorageService();
  final DownloadService _downloads = DownloadService();

  List<Song> _queue = [];
  int _currentIndex = -1;

  Song? get currentSong => _currentIndex >= 0 && _currentIndex < _queue.length
      ? _queue[_currentIndex]
      : null;

  Stream<Duration> get positionStream => _player.positionStream;
  Duration get duration => _player.duration ?? Duration.zero;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  bool get isPlaying => _player.playing;

  Future<void> playQueue(List<Song> queue, int startIndex) async {
    _queue = queue;
    _currentIndex = startIndex;
    await _playCurrent();
  }

  Future<void> _playCurrent() async {
    final song = currentSong;
    if (song == null) return;

    final isLocal = await _downloads.isDownloaded(song.id);
    final tag = MediaItem(
      id: song.id,
      title: song.title,
      artist: song.artist,
      artUri: song.coverUrl.isNotEmpty ? Uri.tryParse(song.coverUrl) : null,
    );

    try {
      if (isLocal) {
        final file = await _downloads.localFile(song.id);
        await _player.setAudioSource(AudioSource.uri(Uri.file(file.path), tag: tag));
      } else {
        final url = await _storage.getDownloadUrl(song.audioPath);
        await _player.setAudioSource(AudioSource.uri(Uri.parse(url), tag: tag));
      }
      await _player.play();
      notifyListeners();
    } catch (e) {
      // Song is online-only and we're offline, or the stream URL failed.
      // Caller/UI should surface "unavailable offline" in this case.
      rethrow;
    }
  }

  Future<void> togglePlayPause() async {
    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
    notifyListeners();
  }

  Future<void> next() async {
    if (_currentIndex < _queue.length - 1) {
      _currentIndex++;
      await _playCurrent();
    }
  }

  Future<void> previous() async {
    if (_currentIndex > 0) {
      _currentIndex--;
      await _playCurrent();
    }
  }

  Future<void> seek(Duration position) => _player.seek(position);

  Future<void> setVolume(double volume) => _player.setVolume(volume);

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
