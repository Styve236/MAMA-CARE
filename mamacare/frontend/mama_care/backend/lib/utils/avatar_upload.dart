import 'dart:convert';

import 'package:shelf/shelf.dart';

import '../config/database.dart';
import 'http_body.dart';
import 'supabase_storage.dart';

const _jsonHeaders = {'content-type': 'application/json'};

Response _jsonError(int status, String message) =>
    Response(status, body: jsonEncode({'error': message}), headers: _jsonHeaders);

/// Lit un body JSON contenant une image en base64 et renvoie ses octets.
///
/// Accepte un base64 nu ou un data URL complet
/// (data:image/jpeg;base64,...), tolere les espaces et newlines.
({List<int> bytes, String contentType})? _decodeImage(Map<String, dynamic> body) {
  final contentType =
      (body['contentType'] as String?)?.trim().toLowerCase() ?? 'image/jpeg';
  final extension = SupabaseStorage.allowedContentTypes[contentType];
  if (extension == null) return null;

  var payload = (body['dataBase64'] as String?) ?? '';
  final comma = payload.indexOf(',');
  if (payload.startsWith('data:') && comma >= 0) {
    payload = payload.substring(comma + 1);
  }
  payload = payload.replaceAll(RegExp(r'\s'), '');
  if (payload.isEmpty) return null;

  List<int> bytes;
  try {
    bytes = base64Decode(payload);
  } on FormatException {
    return null;
  }
  if (bytes.isEmpty) return null;
  return (bytes: bytes, contentType: contentType);
}

/// POST /avatar : enregistre la photo de profil de l'utilisateur courant.
///
/// [table] vaut 'patients' ou 'doctors'. L'ancienne photo est supprimee
/// apres coup, sans faire echouer la requete si la suppression rate.
Future<Response> handleAvatarUpload(
  Request req, {
  required String table,
  required int userId,
}) async {
  final storage = SupabaseStorage.tryCreate();
  if (storage == null) {
    return _jsonError(
        503, 'Stockage d images non configure sur le serveur.');
  }

  final Map<String, dynamic> body;
  try {
    body = await readJsonObject(req,
        maxBytes: SupabaseStorage.maxBase64Chars);
  } on HttpError catch (error) {
    return _jsonError(error.status, error.message);
  }

  final image = _decodeImage(body);
  if (image == null) {
    return _jsonError(
        400, 'Image invalide. Formats acceptes : JPEG, PNG et WebP.');
  }
  if (image.bytes.length > SupabaseStorage.maxImageBytes) {
    return _jsonError(413, 'Image trop volumineuse (3 Mo maximum).');
  }

  final extension =
      SupabaseStorage.allowedContentTypes[image.contentType]!;
  final path = SupabaseStorage.buildPath(userId, extension);

  final String publicUrl;
  try {
    publicUrl = await storage.upload(
      path: path,
      contentType: image.contentType,
      bytes: image.bytes,
    );
  } on StorageException catch (error) {
    return _jsonError(502, error.message);
  } catch (_) {
    return _jsonError(502, 'Le stockage d image est indisponible.');
  }

  final db = Database();
  await db.connect();
  String? previousUrl;
  try {
    final current = await db.query(
      'SELECT avatar_url FROM $table WHERE user_id = @uid',
      substitutionValues: {'uid': userId},
    );
    if (current.isEmpty) {
      return _jsonError(404, 'Profil introuvable.');
    }
    previousUrl = current.first.toColumnMap()['avatar_url']?.toString();

    await db.query(
      'UPDATE $table SET avatar_url = @url, updated_at = NOW() '
      'WHERE user_id = @uid',
      substitutionValues: {'url': publicUrl, 'uid': userId},
    );
  } catch (_) {
    return _jsonError(500, 'Enregistrement de la photo impossible.');
  } finally {
    await db.close();
  }

  final previousPath = previousUrl == null || previousUrl.isEmpty
      ? null
      : storage.pathFromUrl(previousUrl);
  if (previousPath != null && previousPath != path) {
    try {
      await storage.remove(previousPath);
    } catch (_) {
      // L'ancienne photo reste en ligne, sans consequence pour la nouvelle.
    }
  }

  return Response.ok(jsonEncode({'avatar_url': publicUrl}),
      headers: _jsonHeaders);
}

/// DELETE /avatar : retire la photo de profil et vide la colonne.
Future<Response> handleAvatarDelete(
  String table,
  int userId,
) async {
  final db = Database();
  await db.connect();
  String? currentUrl;
  try {
    final current = await db.query(
      'SELECT avatar_url FROM $table WHERE user_id = @uid',
      substitutionValues: {'uid': userId},
    );
    if (current.isEmpty) {
      return _jsonError(404, 'Profil introuvable.');
    }
    currentUrl = current.first.toColumnMap()['avatar_url']?.toString();
    await db.query(
      'UPDATE $table SET avatar_url = NULL, updated_at = NOW() '
      'WHERE user_id = @uid',
      substitutionValues: {'uid': userId},
    );
  } catch (_) {
    return _jsonError(500, 'Suppression de la photo impossible.');
  } finally {
    await db.close();
  }

  final storage = SupabaseStorage.tryCreate();
  final path = currentUrl == null || currentUrl.isEmpty || storage == null
      ? null
      : storage.pathFromUrl(currentUrl);
  if (path != null) {
    try {
      await storage!.remove(path);
    } catch (_) {
      // La colonne est deja videe, le fichier orphelin ne gene pas.
    }
  }

  return Response.ok(jsonEncode({'avatar_url': null}), headers: _jsonHeaders);
}