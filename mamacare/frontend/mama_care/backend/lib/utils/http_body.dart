import 'dart:convert';

import 'package:shelf/shelf.dart';

class HttpError implements Exception {
  HttpError(this.status, this.message);

  final int status;
  final String message;
}

Future<Map<String, dynamic>> readJsonObject(Request req,
    {int maxBytes = 64 * 1024}) async {
  final raw = await req.readAsString();
  if (raw.length > maxBytes) {
    throw HttpError(413, 'Corps de requête trop volumineux');
  }
  final Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException {
    throw HttpError(400, 'JSON invalide');
  }
  if (decoded is! Map<String, dynamic>) {
    throw HttpError(400, 'JSON invalide');
  }
  return decoded;
}