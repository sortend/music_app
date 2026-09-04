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

  void _onChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      setState(() => _loading = true);
      final results = await _firestore.searchSongs(query);
      if (mounted) setState(() {
        _results = results;
        _loading = false;
      });
    });
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
          onChanged: _onChanged,
          decoration: const InputDecoration(
            hintText: 'Search title, artist, album',
            border: InputBorder.none,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _controller.text.isEmpty
                    ? const Center(child: Text('Start typing to search your library'))
                    : _results.isEmpty
                        ? const Center(child: Text('No matches'))
                        : ListView.builder(
                            itemCount: _results.length,
                            itemBuilder: (context, i) => SongTile(
                              song: _results[i],
                              isOnline: true,
                              onPlay: () => context
                                  .read<PlayerService>()
                                  .playQueue(_results, i),
                            ),
                          ),
          ),
          const MiniPlayer(),
        ],
      ),
    );
  }
}
