import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _geminiApiKeyStorageKey = 'gemini_api_key';

/// BYOK skips server spark deduction; Cloud Functions honor keys only when
/// `users/{uid}.subscriptionType` is `pro`.
bool isByokSubscriptionEligible(String? subscriptionType) {
  return subscriptionType?.trim().toLowerCase() == 'pro';
}

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

  /// Returns a stored key only for Pro accounts (matches server [assertByokProOnly]).
  Future<String?> readGeminiApiKeyIfEligible(String? subscriptionType) async {
    if (!isByokSubscriptionEligible(subscriptionType)) return null;
    return readGeminiApiKey();
  }

  Future<void> writeGeminiApiKey(String value) async {
    await _storage.write(key: _geminiApiKeyStorageKey, value: value.trim());
  }

  Future<void> clearGeminiApiKey() async {
    await _storage.delete(key: _geminiApiKeyStorageKey);
  }
}
