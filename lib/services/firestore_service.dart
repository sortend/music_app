import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/song.dart';

/// Handles all reads/writes of song metadata in Firestore.
///
/// Search is implemented client-side over the "recently added" style list
/// (fine for a personal library of a few hundred/thousand songs). If the
/// library grows very large later, swap this for Algolia/Firestore
/// full-text extensions without touching the rest of the app.
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _songs => _db.collection('songs');

  /// Live stream of all songs, newest first.
  Stream<List<Song>> streamAllSongs() {
    return _songs
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Song.fromFirestore(d)).toList());
  }

  Stream<List<Song>> streamRecentlyAdded({int limit = 10}) {
    return _songs
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Song.fromFirestore(d)).toList());
  }

  Future<List<Song>> searchSongs(String query) async {
    if (query.trim().isEmpty) return [];
    final q = query.toLowerCase();
    // Firestore has no native "contains" text search, so we pull the
    // (small, personal-library-sized) collection and filter client-side.
    final snap = await _songs.get();
    final all = snap.docs.map((d) => Song.fromFirestore(d)).toList();
    return all.where((s) => s.searchIndex.contains(q)).toList();
  }

  Future<void> addSong(Song song) async {
    await _songs.doc(song.id).set(song.toFirestore());
  }

  Future<void> deleteSong(String songId) async {
    await _songs.doc(songId).delete();
  }

  Future<Song?> getSong(String songId) async {
    final doc = await _songs.doc(songId).get();
    if (!doc.exists) return null;
    return Song.fromFirestore(doc);
  }
}
