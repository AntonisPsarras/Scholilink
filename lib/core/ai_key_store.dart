import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _geminiApiKeyStorageKey = 'gemini_api_key';

final aiKeyStoreProvider = Provider<AiKeyStore>((ref) {
  return const AiKeyStore(FlutterSecureStorage());
});

class AiKeyStore {
  const AiKeyStore(this._storage);

  final FlutterSecureStorage _storage;

  Future<String?> readGeminiApiKey() async {
    final value = await _storage.read(key: _geminiApiKeyStorageKey);
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> writeGeminiApiKey(String value) async {
    await _storage.write(key: _geminiApiKeyStorageKey, value: value.trim());
  }

  Future<void> clearGeminiApiKey() async {
    await _storage.delete(key: _geminiApiKeyStorageKey);
  }
}
