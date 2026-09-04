import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/song.dart';

/// Handles all reads/writes of song metadata in Firestore.
///
/// Search is implemented client-side (fine for a personal library of a few
/// hundred/thousand songs). If the library grows very large later, swap this
/// for Algolia/Firestore full-text extensions without touching the rest of
/// the app.
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _songs => _db.collection('songs');

  /// Search reads the whole collection, so a naive implementation billed a
  /// full-collection read per keystroke. Cached briefly and shared across
  /// instances instead.
  static const _searchCacheTtl = Duration(minutes: 2);
  static List<Song>? _searchCache;
  static DateTime? _searchCacheAt;

  /// Live stream of all songs, newest first.
  Stream<List<Song>> streamAllSongs() {
    return _songs
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Song.fromFirestore).toList());
  }

  Stream<List<Song>> streamRecentlyAdded({int limit = 10}) {
    return _songs
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(Song.fromFirestore).toList());
  }

  Future<List<Song>> searchSongs(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];
    final all = await _allSongs();
    return all.where((s) => s.searchIndex.contains(q)).toList();
  }

  Future<List<Song>> _allSongs() async {
    final cache = _searchCache;
    final cachedAt = _searchCacheAt;
    if (cache != null &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < _searchCacheTtl) {
      return cache;
    }
    // Firestore has no native "contains" text search, so we pull the
    // (small, personal-library-sized) collection and filter client-side.
    final snap = await _songs.orderBy('createdAt', descending: true).get();
    final all = snap.docs.map(Song.fromFirestore).toList();
    _searchCache = all;
    _searchCacheAt = DateTime.now();
    return all;
  }

  Future<void> addSong(Song song) async {
    await _songs.doc(song.id).set(song.toFirestore());
    _invalidateSearchCache(); // otherwise a new song is unsearchable for 2 min
  }

  Future<void> deleteSong(String songId) async {
    await _songs.doc(songId).delete();
    _invalidateSearchCache();
  }

  Future<Song?> getSong(String songId) async {
    final doc = await _songs.doc(songId).get();
    if (!doc.exists) return null;
    return Song.fromFirestore(doc);
  }

  static void _invalidateSearchCache() {
    _searchCache = null;
    _searchCacheAt = null;
  }
}
