import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'storage_service.dart';

enum DownloadState { notDownloaded, downloading, downloaded, failed }

/// Manages offline copies of songs on this device.
///
/// - Downloaded files live in the app's own document directory
///   (`<appDocs>/downloads/{songId}.mp3`) so they're private to the app
///   and cleaned up automatically if the app is uninstalled.
/// - "Which songs are downloaded" is tracked in SharedPreferences so the
///   app doesn't need to hit the network to know what's available offline.
/// - Deleting a download only removes the local file + local record; the
///   cloud original in Firebase Storage is untouched.
class DownloadService {
  final StorageService _storage = StorageService();
  static const _prefsKey = 'downloaded_song_ids';

  final Map<String, void Function(double)> _progressListeners = {};

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
    return file.exists(); // guards against a stale record if the file vanished
  }

  Future<Set<String>> downloadedSongIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_prefsKey) ?? []).toSet();
  }

  Future<void> _markDownloaded(String songId) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_prefsKey) ?? [];
    if (!ids.contains(songId)) {
      ids.add(songId);
      await prefs.setStringList(_prefsKey, ids);
    }
  }

  Future<void> _unmarkDownloaded(String songId) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_prefsKey) ?? [];
    ids.remove(songId);
    await prefs.setStringList(_prefsKey, ids);
  }

  /// Downloads a song, reporting 0.0-1.0 progress. Skips the network call
  /// entirely if the song is already downloaded (no unnecessary re-downloads).
  Future<void> downloadSong(
    String songId,
    String storagePath, {
    required void Function(double progress) onProgress,
    required void Function() onComplete,
    required void Function(String error) onError,
  }) async {
    if (await isDownloaded(songId)) {
      onComplete();
      return;
    }
    final tempFile = File('${(await _downloadsDir()).path}/$songId.mp3.part');
    try {
      final url = await _storage.getDownloadUrl(storagePath);
      final request = http.Request('GET', Uri.parse(url));
      final response = await http.Client().send(request);

      if (response.statusCode != 200) {
        onError('Download failed (${response.statusCode}). Check your connection and try again.');
        return;
      }

      final total = response.contentLength ?? 0;
      var received = 0;
      final sink = tempFile.openWrite();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress(received / total);
      }
      await sink.close();

      // Only move the file into place once fully written, so an
      // interrupted download never leaves a corrupt "downloaded" file.
      final finalFile = await localFile(songId);
      await tempFile.rename(finalFile.path);
      await _markDownloaded(songId);
      onComplete();
    } catch (e) {
      if (await tempFile.exists()) await tempFile.delete();
      onError('Download interrupted: $e');
    }
  }

  /// Removes only the local copy. The cloud original is never touched.
  Future<void> deleteDownload(String songId) async {
    final file = await localFile(songId);
    if (await file.exists()) await file.delete();
    await _unmarkDownloaded(songId);
  }
}
