import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:just_audio/just_audio.dart';
import '../models/song.dart';
import '../services/storage_service.dart';
import '../services/firestore_service.dart';

/// Simple upload form. Intentionally minimal per the app's "no unnecessary
/// features" requirement — just enough to get a song's audio + cover +
/// metadata uploaded once, from any device.
class AdminUploadScreen extends StatefulWidget {
  const AdminUploadScreen({super.key});

  @override
  State<AdminUploadScreen> createState() => _AdminUploadScreenState();
}

class _AdminUploadScreenState extends State<AdminUploadScreen> {
  final _titleCtrl = TextEditingController();
  final _artistCtrl = TextEditingController();
  final _albumCtrl = TextEditingController();
  final _storage = StorageService();
  final _firestore = FirestoreService();

  File? _audioFile;
  File? _coverFile;
  bool _uploading = false;
  double _progress = 0;
  String? _error;

  @override
  void dispose() {
    // Previously leaked — controllers outlive the State otherwise.
    _titleCtrl.dispose();
    _artistCtrl.dispose();
    _albumCtrl.dispose();
    super.dispose();
  }

  String get _audioName =>
      _audioFile == null ? '' : _audioFile!.path.split(RegExp(r'[/\\]')).last;

  Future<void> _pickAudio() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.audio);
      final path = result?.files.single.path;
      if (path == null || !mounted) return;
      setState(() {
        _audioFile = File(path);
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not open the file picker: $e');
    }
  }

  Future<void> _pickCover() async {
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null || !mounted) return;
      setState(() {
        _coverFile = File(picked.path);
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not open the image picker: $e');
    }
  }

  Future<void> _upload() async {
    if (_titleCtrl.text.trim().isEmpty ||
        _artistCtrl.text.trim().isEmpty ||
        _audioFile == null) {
      setState(() => _error = 'Title, artist, and an audio file are required.');
      return;
    }
    if (!await _audioFile!.exists()) {
      if (mounted) {
        setState(() => _error = 'That audio file is no longer available. Pick it again.');
      }
      return;
    }
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() {
      _uploading = true;
      _error = null;
      _progress = 0;
    });

    final songId = const Uuid().v4();
    try {
      // Figure out duration locally before uploading, so it's saved once
      // with the song rather than recomputed by every listening device.
      final tempPlayer = AudioPlayer();
      Duration? duration;
      try {
        duration = await tempPlayer.setFilePath(_audioFile!.path);
      } catch (_) {
        // An unreadable header shouldn't block the upload; the player falls
        // back to the real duration at playback time.
      } finally {
        await tempPlayer.dispose();
      }

      final audioUrl = await _storage.uploadAudio(
        songId,
        _audioFile!,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );

      final coverUrl =
          _coverFile != null ? await _storage.uploadCover(songId, _coverFile!) : '';

      final song = Song(
        id: songId,
        title: _titleCtrl.text.trim(),
        artist: _artistCtrl.text.trim(),
        album: _albumCtrl.text.trim(),
        coverUrl: coverUrl,
        audioPath: audioUrl,
        durationMs: duration?.inMilliseconds ?? 0,
        createdAt: DateTime.now(),
      );
      await _firestore.addSong(song);

      messenger.showSnackBar(
        const SnackBar(content: Text('Song uploaded — it will appear on all your devices.')),
      );
      navigator.pop();
    } catch (e) {
      // Guarded: an upload can outlive the screen if the user backs out.
      if (mounted) setState(() => _error = 'Upload failed: $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload song')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(
              controller: _titleCtrl,
              enabled: !_uploading,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Title *'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _artistCtrl,
              enabled: !_uploading,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Artist *'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _albumCtrl,
              enabled: !_uploading,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(labelText: 'Album (optional)'),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              icon: const Icon(Icons.audiotrack),
              label: Text(
                _audioFile == null ? 'Choose audio file *' : 'Audio: $_audioName',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onPressed: _uploading ? null : _pickAudio,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.image_outlined),
              label: Text(_coverFile == null ? 'Choose cover image' : 'Cover selected'),
              onPressed: _uploading ? null : _pickCover,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ],
            const SizedBox(height: 24),
            if (_uploading) ...[
              LinearProgressIndicator(value: _progress > 0 ? _progress : null),
              const SizedBox(height: 8),
              const Text(
                'Uploading — keep this screen open until it finishes.',
                style: TextStyle(fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _uploading ? null : _upload,
              child: Text(_uploading ? 'Uploading…' : 'Upload'),
            ),
          ],
        ),
      ),
    );
  }
}
