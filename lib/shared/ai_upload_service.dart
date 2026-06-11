import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

Future<List<Map<String, dynamic>>> uploadAiImages({
  required List<Uint8List> imageBytes,
  required String feature,
  required String sessionId,
}) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null || imageBytes.isEmpty) return const [];

  final storage = FirebaseStorage.instance;
  final out = <Map<String, dynamic>>[];
  for (var i = 0; i < imageBytes.length; i++) {
    try {
      final bytes = imageBytes[i];
      const ext = 'jpg';
      const mime = 'image/jpeg';
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
      debugPrint('uploadAiImages failed for image[$i]: $e\n$st');
    }
  }
  return out;
}
