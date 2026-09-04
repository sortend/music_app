import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../services/firestore_service.dart';
import '../services/player_service.dart';
import '../widgets/song_tile.dart';
import '../widgets/mini_player.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _firestore = FirestoreService();
  final _controller = TextEditingController();
  Timer? _debounce;
  List<Song> _results = [];
  bool _loading = false;
  String? _error;

  /// Guards against an earlier, slower query overwriting the results of a
  /// later one when typing quickly.
  int _queryToken = 0;

  void _onChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      _queryToken++;
      setState(() {
        _results = [];
        _loading = false;
        _error = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 250), () => _run(query));
    // Rebuild now so the clear button appears on the first keystroke rather
    // than only once the debounced search resolves.
    setState(() => _error = null);
  }

  Future<void> _run(String query) async {
    final token = ++_queryToken;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await _firestore.searchSongs(query);
      if (!mounted || token != _queryToken) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || token != _queryToken) return;
      setState(() {
        _loading = false;
        _error = 'Search failed: $e';
      });
    }
  }

  Future<void> _play(int index) async {
    final player = context.read<PlayerService>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await player.playQueue(_results, index);
    } catch (_) {
      final error = player.consumeError();
      if (error != null) {
        messenger.showSnackBar(SnackBar(content: Text(error)));
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: _onChanged,
          decoration: const InputDecoration(
            hintText: 'Search title, artist, album',
            border: InputBorder.none,
          ),
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              tooltip: 'Clear',
              onPressed: () {
                _controller.clear();
                _onChanged('');
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildResults()),
          const MiniPlayer(),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }
    if (_controller.text.trim().isEmpty) {
      return const Center(child: Text('Start typing to search your library'));
    }
    if (_results.isEmpty) return const Center(child: Text('No matches'));

    return ListView.builder(
      itemCount: _results.length,
      itemBuilder: (context, i) => SongTile(
        key: ValueKey(_results[i].id),
        song: _results[i],
        isOnline: true,
        onPlay: () => _play(i),
      ),
    );
  }
}
