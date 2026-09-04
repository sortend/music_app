import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single song, backed by a Firestore document under `songs/{songId}`.
class Song {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String coverUrl;
  final String audioPath; // Storage path, e.g. songs/{songId}.mp3
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

  factory Song.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Song(
      id: doc.id,
      title: data['title'] ?? 'Unknown title',
      artist: data['artist'] ?? 'Unknown artist',
      album: data['album'] ?? '',
      coverUrl: data['coverUrl'] ?? '',
      audioPath: data['audioPath'] ?? '',
      durationMs: (data['durationMs'] ?? 0) as int,
      createdAt: (data['createdAt'] is Timestamp)
          ? (data['createdAt'] as Timestamp).toDate()
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
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  /// Cheap searchable text blob used for simple client-side / prefix search.
  String get searchIndex => '$title $artist $album'.toLowerCase();
}
