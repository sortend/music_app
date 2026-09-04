import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single song, backed by a Firestore document under `songs/{songId}`.
class Song {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String coverUrl;

  /// Public HTTPS URL of the audio file (Cloudinary). Named `audioPath` for
  /// backwards compatibility with documents written by earlier versions.
  final String audioPath;
  final int durationMs;
  final DateTime createdAt;

  Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.coverUrl,
    required this.audioPath,
    required this.durationMs,
    required this.createdAt,
  });

  factory Song.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    // A deleted-but-still-streamed doc has null data; fall back to an empty
    // map rather than throwing and killing the whole list.
    return Song.fromMap(doc.id, doc.data() ?? const {});
  }

  factory Song.fromMap(String id, Map<String, dynamic> data) {
    final createdAt = data['createdAt'];
    return Song(
      id: id,
      title: (data['title'] as String?)?.trim().isNotEmpty == true
          ? data['title'] as String
          : 'Unknown title',
      artist: (data['artist'] as String?)?.trim().isNotEmpty == true
          ? data['artist'] as String
          : 'Unknown artist',
      album: data['album'] as String? ?? '',
      coverUrl: data['coverUrl'] as String? ?? '',
      audioPath: data['audioPath'] as String? ?? '',
      // Firestore hands back numbers as int *or* double depending on how they
      // were written, so go through num rather than casting straight to int.
      durationMs: (data['durationMs'] as num?)?.toInt() ?? 0,
      createdAt: createdAt is Timestamp
          ? createdAt.toDate()
          : createdAt is int
              ? DateTime.fromMillisecondsSinceEpoch(createdAt)
              : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'artist': artist,
      'album': album,
      'coverUrl': coverUrl,
      'audioPath': audioPath,
      'durationMs': durationMs,
      // Written once on create; the server clock keeps ordering consistent
      // across devices with skewed local time.
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  /// Plain-JSON form (no [FieldValue] sentinels) for the local offline cache.
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'artist': artist,
      'album': album,
      'coverUrl': coverUrl,
      'audioPath': audioPath,
      'durationMs': durationMs,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  /// Cheap searchable text blob used for simple client-side / prefix search.
  String get searchIndex => '$title $artist $album'.toLowerCase();
}
