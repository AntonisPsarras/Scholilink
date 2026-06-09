import 'dart:typed_data';

import 'package:gal/gal.dart';

Future<void> saveImage(Uint8List bytes, String fileName) async {
  if (!await Gal.hasAccess()) {
    final granted = await Gal.requestAccess();
    if (!granted) {
      throw Exception('Permission denied: Access to gallery is required');
    }
  }

  final name = fileName.contains('.')
      ? fileName.substring(0, fileName.lastIndexOf('.'))
      : fileName;
  final safeName = name.trim().isEmpty ? 'image' : name.trim();

  try {
    await Gal.putImageBytes(bytes, name: safeName);
  } on GalException catch (e) {
    throw Exception('Could not save image to gallery: ${e.type}');
  }
}
