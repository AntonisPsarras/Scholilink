import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

class StorageService {
  static const int maxUploadBytes = 10 * 1024 * 1024;

  final FirebaseStorage _storage;
  final _uuid = const Uuid();

  StorageService() : _storage = _resolveStorage();

  static FirebaseStorage _resolveStorage() {
    final app = Firebase.app();
    final bucket = app.options.storageBucket;
    if (bucket != null &&
        bucket.isNotEmpty &&
        !bucket.startsWith('YOUR_')) {
      final gsUri = bucket.startsWith('gs://') ? bucket : 'gs://$bucket';
      return FirebaseStorage.instanceFor(app: app, bucket: gsUri);
    }
    return FirebaseStorage.instance;
  }

  /// Normalizes a file extension for Storage paths and content types.
  static String normalizeImageExt(String filename) {
    final ext = filename.contains('.')
        ? filename.split('.').last.toLowerCase()
        : 'jpg';
    return switch (ext) {
      'jpeg' => 'jpg',
      'png' || 'webp' || 'gif' => ext,
      _ => 'jpg',
    };
  }

  static void ensureWithinUploadLimit(int byteLength) {
    if (byteLength >= maxUploadBytes) {
      throw StateError('upload_too_large');
    }
  }

  static String imageContentType(String ext) {
    return switch (ext.toLowerCase()) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      _ => 'image/jpeg',
    };
  }

  static String audioContentType(String ext) {
    return switch (ext.toLowerCase()) {
      'wav' => 'audio/wav',
      'm4a' => 'audio/mp4',
      'webm' => 'audio/webm',
      _ => 'audio/mpeg',
    };
  }

  Reference _mediaRef(
    String folder,
    String fileName, {
    required String ownerUid,
    String? scopeId,
  }) {
    if (scopeId != null) {
      return _storage
          .ref()
          .child(folder)
          .child(ownerUid)
          .child(scopeId)
          .child(fileName);
    }
    return _storage.ref().child(folder).child(ownerUid).child(fileName);
  }

  /// Uploads image bytes to Firebase Storage and returns the download URL.
  ///
  /// When [scopeId] is set, path is `folder/ownerUid/scopeId/uuid.ext`
  /// (classroom or chat id). Otherwise path is `folder/ownerUid/uuid.ext`.
  Future<String> uploadImageBytes(
    Uint8List bytes,
    String folder, {
    String ext = 'jpg',
    required String ownerUid,
    String? scopeId,
  }) async {
    final fileName = '${_uuid.v4()}.$ext';
    final ref = _mediaRef(
      folder,
      fileName,
      ownerUid: ownerUid,
      scopeId: scopeId,
    );

    ensureWithinUploadLimit(bytes.length);

    final snapshot = await ref
        .putData(bytes, SettableMetadata(contentType: imageContentType(ext)))
        .whenComplete(() => null);
    return await snapshot.ref.getDownloadURL();
  }

  /// Uploads voice recording bytes to Firebase Storage and returns the download URL.
  ///
  /// When [scopeId] is set, path is `folder/ownerUid/scopeId/uuid.ext`
  /// (classroom or chat id). Otherwise path is `folder/ownerUid/uuid.ext`.
  Future<String> uploadVoiceBytes(
    Uint8List bytes,
    String folder, {
    String ext = 'webm',
    required String ownerUid,
    String? scopeId,
  }) async {
    final fileName = '${_uuid.v4()}.$ext';
    final ref = _mediaRef(
      folder,
      fileName,
      ownerUid: ownerUid,
      scopeId: scopeId,
    );

    ensureWithinUploadLimit(bytes.length);

    final snapshot = await ref
        .putData(bytes, SettableMetadata(contentType: audioContentType(ext)))
        .whenComplete(() => null);
    return await snapshot.ref.getDownloadURL();
  }
}
