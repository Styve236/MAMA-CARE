import 'dart:math';

import 'package:http/http.dart' as http;

import 'env.dart';

class StorageException implements Exception {
  StorageException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Client minimal de l'API Storage Supabase (bucket public).
///
/// Necessite SUPABASE_URL et SUPABASE_SERVICE_ROLE_KEY. La cle de service
/// n'est utilisee que cote serveur : elle ne transite jamais vers l'app.
class SupabaseStorage {
  SupabaseStorage._(this._url, this._key, this._bucket, this._client);

  static const String defaultBucket = 'avatars';
  static const int maxImageBytes = 3 * 1024 * 1024;
  static const int maxBase64Chars = 5 * 1024 * 1024;

  /// Types MIME acceptes, associes a l'extension du fichier stocke.
  static const Map<String, String> allowedContentTypes = {
    'image/jpeg': '.jpg',
    'image/png': '.png',
    'image/webp': '.webp',
  };

  final String _url;
  final String _key;
  final String _bucket;
  final http.Client _client;

  static SupabaseStorage? tryCreate() {
    final url = Env.get('SUPABASE_URL');
    final key = Env.get('SUPABASE_SERVICE_ROLE_KEY');
    if (url == null || url.isEmpty || key == null || key.isEmpty) return null;
    return SupabaseStorage._(
      url.replaceAll(RegExp(r'/+$'), ''),
      key,
      Env.get('SUPABASE_STORAGE_BUCKET') ?? defaultBucket,
      http.Client(),
    );
  }

  /// Chemin unique par utilisateur, non devinable et non reutilisable.
  static String buildPath(int userId, String extension) {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final salt = Random().nextInt(0x7fffffff).toRadixString(16).padLeft(8, '0');
    return 'user-$userId/$stamp-$salt$extension';
  }

  String publicUrl(String path) =>
      '$_url/storage/v1/object/public/$_bucket/$path';

  /// Recupere le chemin stocke dans une URL publique, ou null si l'URL
  /// ne pointe pas vers notre bucket.
  String? pathFromUrl(String url) {
    final marker = '/object/public/$_bucket/';
    final idx = url.indexOf(marker);
    if (idx < 0) return null;
    final path = url.substring(idx + marker.length);
    return path.isEmpty ? null : path;
  }

  Future<String> upload({
    required String path,
    required String contentType,
    required List<int> bytes,
  }) async {
    if (bytes.isEmpty) {
      throw StorageException('Image vide.');
    }
    if (bytes.length > maxImageBytes) {
      throw StorageException('Image trop volumineuse (3 Mo maximum).');
    }
    final response = await _client
        .post(
          Uri.parse('$_url/storage/v1/object/$_bucket/$path'),
          headers: {
            'authorization': 'Bearer $_key',
            'apikey': _key,
            'content-type': contentType,
            'x-upsert': 'true',
          },
          body: bytes,
        )
        .timeout(const Duration(seconds: 30));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StorageException(
          'Le stockage d image a echoue (${response.statusCode}).');
    }
    return publicUrl(path);
  }

  Future<void> remove(String path) async {
    final response = await _client
        .delete(Uri.parse('$_url/storage/v1/object/$_bucket/$path'), headers: {
          'authorization': 'Bearer $_key',
          'apikey': _key,
        })
        .timeout(const Duration(seconds: 30));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StorageException(
          'Suppression impossible (${response.statusCode}).');
    }
  }
}