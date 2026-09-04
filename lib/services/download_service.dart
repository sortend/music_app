import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/song.dart';

enum DownloadState { notDownloaded, downloading, downloaded, failed }

/// Manages offline copies of songs on this device.
///
/// - Downloaded files live in the app's own document directory
///   (`<appDocs>/downloads/{songId}.mp3`) so they're private to the app
///   and cleaned up automatically if the app is uninstalled.
/// - "Which songs are downloaded" *and* each song's metadata are tracked in
///   SharedPreferences, so the Downloads screen can list and play everything
///   with no network access at all.
/// - Deleting a download only removes the local file + local record; the
///   cloud original (Cloudinary) and the Firestore entry are untouched.
class DownloadService {
  static const _prefsKey = 'downloaded_song_ids';
  static const _metaKey = 'downloaded_song_meta';

  /// Guards against two widgets kicking off the same download at once (both
  /// would write to the same temp file and corrupt each other).
  static final Set<String> _inFlight = {};

  Future<Directory> _downloadsDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/downloads');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> localFile(String songId) async {
    final dir = await _downloadsDir();
    return File('${dir.path}/$songId.mp3');
  }

  Future<bool> isDownloaded(String songId) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_prefsKey) ?? [];
    if (!ids.contains(songId)) return false;
    final file = await localFile(songId);
    if (await file.exists()) return true;
    // Stale record — the file vanished (cleared storage, restore from
    // backup, ...). Drop it so the UI offers the download again.
    await _unmarkDownloaded(songId);
    return false;
  }

  Future<Set<String>> downloadedSongIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_prefsKey) ?? []).toSet();
  }

  /// Every downloaded song, newest first, read purely from local storage —
  /// no Firestore call, so this works with the radio off.
  Future<List<Song>> downloadedSongs() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_prefsKey) ?? [];
    final meta = _readMeta(prefs);

    final songs = <Song>[];
    for (final id in ids) {
      final file = await localFile(id);
      if (!await file.exists()) {
        await _unmarkDownloaded(id);
        continue;
      }
      final data = meta[id];
      songs.add(data != null
          ? Song.fromMap(id, data)
          // Downloaded by an older build that didn't cache metadata.
          : Song(
              id: id,
              title: 'Downloaded song',
              artist: 'Unknown artist',
              album: '',
              coverUrl: '',
              audioPath: '',
              durationMs: 0,
              createdAt: DateTime.fromMillisecondsSinceEpoch(0),
            ));
    }
    songs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return songs;
  }

  Map<String, Map<String, dynamic>> _readMeta(SharedPreferences prefs) {
    final raw = prefs.getString(_metaKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, (v as Map).cast<String, dynamic>()));
    } catch (_) {
      return {}; // corrupt cache: rebuild rather than crash the screen
    }
  }

  Future<void> _markDownloaded(Song song) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_prefsKey) ?? [];
    if (!ids.contains(song.id)) {
      ids.add(song.id);
      await prefs.setStringList(_prefsKey, ids);
    }
    final meta = _readMeta(prefs)..[song.id] = song.toJson();
    await prefs.setString(_metaKey, jsonEncode(meta));
  }

  Future<void> _unmarkDownloaded(String songId) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_prefsKey) ?? [];
    ids.remove(songId);
    await prefs.setStringList(_prefsKey, ids);
    final meta = _readMeta(prefs)..remove(songId);
    await prefs.setString(_metaKey, jsonEncode(meta));
  }

  /// Downloads a song, reporting 0.0-1.0 progress. Skips the network call
  /// entirely if the song is already downloaded (no unnecessary re-downloads).
  Future<void> downloadSong(
    Song song, {
    required void Function(double progress) onProgress,
    required void Function() onComplete,
    required void Function(String error) onError,
  }) async {
    if (await isDownloaded(song.id)) {
      // Backfill metadata for songs downloaded before it was cached.
      await _markDownloaded(song);
      onComplete();
      return;
    }
    if (song.audioPath.isEmpty) {
      onError('This song has no audio file attached.');
      return;
    }
    if (!_inFlight.add(song.id)) {
      // Another tile already has this download running; let it own the
      // callbacks and reset this caller's button instead of spinning forever.
      onError('That song is already downloading.');
      return;
    }

    File? tempFile;
    final client = http.Client();
    IOSink? sink;
    try {
      tempFile = File('${(await _downloadsDir()).path}/${song.id}.mp3.part');
      final request = http.Request('GET', Uri.parse(song.audioPath));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        onError('Download failed (${response.statusCode}). Check your connection and try again.');
        return;
      }

      final total = response.contentLength ?? 0;
      var received = 0;
      sink = tempFile.openWrite();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress(received / total);
      }
      await sink.flush();
      await sink.close();
      sink = null;

      // A dropped connection can end the stream early without throwing, so
      // compare against Content-Length before trusting the file.
      if (total > 0 && received != total) {
        throw Exception('incomplete transfer ($received of $total bytes)');
      }

      // Only move the file into place once fully written, so an
      // interrupted download never leaves a corrupt "downloaded" file.
      final finalFile = await localFile(song.id);
      await tempFile.rename(finalFile.path);
      await _markDownloaded(song);
      onComplete();
    } catch (e) {
      onError('Download interrupted: $e');
    } finally {
      // Close the sink before deleting, or the file stays locked and the
      // delete fails silently, leaving a stray .part behind.
      final temp = tempFile;
      try {
        await sink?.close();
      } catch (_) {
        // Already broken; the delete below is what matters.
      }
      if (temp != null && await temp.exists()) {
        try {
          await temp.delete();
        } catch (_) {
          // Best effort — a leftover .part is overwritten on the next attempt.
        }
      }
      client.close();
      _inFlight.remove(song.id);
    }
  }

  /// Removes only the local copy. The cloud original is never touched.
  Future<void> deleteDownload(String songId) async {
    final file = await localFile(songId);
    if (await file.exists()) await file.delete();
    await _unmarkDownloaded(songId);
  }
}
