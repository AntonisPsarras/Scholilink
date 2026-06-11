import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

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

String base64EncodeImageBytes(Uint8List bytes) => base64Encode(bytes);

/// Resize/re-encode on a background isolate when not on web.
Future<Uint8List> prepareImageBytesForAi(Uint8List raw) async {
  if (kIsWeb) {
    await Future<void>.delayed(Duration.zero);
    return encodeImageBytesForGeminiOcr(raw);
  }
  return compute(encodeImageBytesForGeminiOcr, raw);
}

/// Reads each file once, then [prepareImageBytesForAi] (single pass for upload + callable).
Future<List<Uint8List>> prepareAiImagesFromXFiles(List<XFile> files) async {
  final out = <Uint8List>[];
  for (final file in files) {
    final rawBytes = await file.readAsBytes();
    out.add(await prepareImageBytesForAi(rawBytes));
  }
  return out;
}

Future<String> base64EncodeImageBytesInIsolate(Uint8List jpegBytes) async {
  if (kIsWeb) {
    return base64EncodeImageBytes(jpegBytes);
  }
  return compute(base64EncodeImageBytes, jpegBytes);
}
