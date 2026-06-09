import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Decodes common formats and re-encodes as JPEG so the backend can send
/// `image/jpeg` to Gemini (avoids wrong mime when gallery returns PNG/WebP).
Uint8List encodeImageBytesForGeminiOcr(Uint8List raw) {
  try {
    final decoded = img.decodeImage(raw);
    if (decoded == null) return raw;
    return Uint8List.fromList(img.encodeJpg(decoded, quality: 88));
  } catch (_) {
    return raw;
  }
}
