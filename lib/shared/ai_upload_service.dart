import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

Future<List<Map<String, dynamic>>> uploadAiImages({
  required List<XFile> files,
  required String feature,
  required String sessionId,
}) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null || files.isEmpty) return const [];

  final storage = FirebaseStorage.instance;
  final out = <Map<String, dynamic>>[];
  for (var i = 0; i < files.length; i++) {
    try {
      final file = files[i];
      final bytes = await file.readAsBytes();
      final lower = file.name.toLowerCase();
      final ext = lower.endsWith('.png')
          ? 'png'
          : lower.endsWith('.webp')
          ? 'webp'
          : 'jpg';
      final mime = ext == 'png'
          ? 'image/png'
          : ext == 'webp'
          ? 'image/webp'
          : 'image/jpeg';
      final safeSession = sessionId.isEmpty ? 'pending' : sessionId;
      final path =
          'ai_uploads/$uid/$feature/$safeSession/${DateTime.now().millisecondsSinceEpoch}_$i.$ext';
      final ref = storage.ref(path);
      await ref.putData(bytes, SettableMetadata(contentType: mime));
      final url = await ref.getDownloadURL();
      out.add({
        'type': 'image',
        'storagePath': path,
        'downloadUrl': url,
        'mimeType': mime,
      });
    } catch (e, st) {
      debugPrint('uploadAiImages failed for file[$i]: $e\n$st');
    }
  }
  return out;
}
