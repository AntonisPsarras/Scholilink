import 'dart:typed_data';
import 'file_saver_stub.dart'
    if (dart.library.js_interop) 'file_saver_web.dart'
    if (dart.library.io) 'file_saver_mobile.dart'
    as platform;

Future<void> saveImageToGallery(Uint8List bytes, String fileName) async {
  return platform.saveImage(bytes, fileName);
}
