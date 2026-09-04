import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Handles file hosting via Cloudinary instead of Firebase Storage
/// (Firebase Storage now requires the paid Blaze plan; Cloudinary's free
/// tier — 25GB storage, 25GB bandwidth/month — covers a personal music
/// library comfortably with no card required).
///
/// Uses Cloudinary's "unsigned upload" flow so the app can upload directly
/// without a backend server. This requires a free Cloudinary account with
/// an unsigned upload preset — see README.md "Cloudinary setup".
///
/// Cloudinary returns a permanent public URL at upload time, so that URL is
/// stored directly as `audioPath`/`coverUrl` in Firestore — there is no
/// separate "resolve a download URL" step anywhere in the app.
class StorageService {
  // Replace these with your own values from cloudinary.com (Dashboard for
  // the cloud name; Settings > Upload > Upload presets for the preset).
  static const String cloudName = 'pg9y2gtu';
  static const String uploadPreset = 'music_app_upload';

  static bool get isConfigured =>
      cloudName.isNotEmpty &&
      uploadPreset.isNotEmpty &&
      !cloudName.startsWith('REPLACE_WITH') &&
      !uploadPreset.startsWith('REPLACE_WITH');

  Future<String> _upload(
    File file,
    String resourceType,
    String publicId, {
    void Function(double progress)? onProgress,
  }) async {
    if (!isConfigured) {
      throw Exception(
        'Cloudinary is not configured. Set cloudName and uploadPreset in '
        'lib/services/storage_service.dart (see README.md).',
      );
    }

    final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/$resourceType/upload');
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = uploadPreset
      ..fields['public_id'] = publicId
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    // Cloudinary's simple upload API doesn't expose byte-level progress
    // without a lot of extra plumbing, so we show "in progress" rather than
    // a precise percentage.
    onProgress?.call(0.1);

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw Exception('Cloudinary upload failed (${response.statusCode}): ${response.body}');
    }

    onProgress?.call(1.0);

    // secure_url is a permanent HTTPS link to the uploaded file.
    Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (e) {
      throw Exception('Could not parse the Cloudinary response: $e');
    }
    final url = decoded is Map<String, dynamic> ? decoded['secure_url'] : null;
    if (url is! String || url.isEmpty) {
      throw Exception('Cloudinary response did not include a secure_url');
    }
    return url;
  }

  /// Cloudinary treats audio files under its "video" resource type.
  Future<String> uploadAudio(
    String songId,
    File file, {
    void Function(double progress)? onProgress,
  }) {
    return _upload(file, 'video', 'songs/$songId', onProgress: onProgress);
  }

  Future<String> uploadCover(String songId, File file) {
    return _upload(file, 'image', 'covers/$songId');
  }
}
