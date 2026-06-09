import 'dart:convert';
import 'dart:typed_data';

/// Returns `true` if the URL is a Base64 data URI rather than a network URL.
/// Kept for backward compatibility with existing Firestore data.
bool isBase64DataUri(String url) => url.startsWith('data:');

/// Decodes a Base64 data URI into raw bytes.
/// Kept for backward compatibility with existing Firestore data.
///
/// Expects format: `data:<mime>;base64,<encoded>`
List<int> decodeBase64DataUri(String dataUri) {
  final commaIndex = dataUri.indexOf(',');
  if (commaIndex == -1) throw ArgumentError('Invalid data URI');
  return base64Decode(dataUri.substring(commaIndex + 1));
}

/// Top-level entry for [compute] — must stay synchronous and only use dart:convert.
Uint8List decodeBase64DataUriForIsolate(String dataUri) {
  return Uint8List.fromList(decodeBase64DataUri(dataUri));
}
