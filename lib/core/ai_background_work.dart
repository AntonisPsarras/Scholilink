import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute, kIsWeb;

/// Runs [fn] in a background isolate when not on web; on web yields first then runs on the main isolate.
Future<R> runAiIsolate<Q extends Object?, R extends Object?>(
  R Function(Q) fn,
  Q message,
) async {
  if (kIsWeb) {
    await Future<void>.delayed(Duration.zero);
    return fn(message);
  }
  return compute(fn, message);
}

/// Builds the `history` payload for the smart-notes `chatWithAi` callable (matches prior notifier structure).
List<Map<String, dynamic>> buildSmartNotesCallableHistory(
  Map<String, dynamic> args,
) {
  final rawItems = args['items'] as List<dynamic>;
  final items = rawItems.cast<Map<String, dynamic>>();
  final history = <Map<String, dynamic>>[
    {
      'role': 'user',
      'parts': [
        {
          'text':
              'You are an expert educational AI. Always return a valid JSON array of objects with title, content, and bulletPoints. All content must be in Greek.',
        },
      ],
    },
    {
      'role': 'model',
      'parts': [
        {'text': 'Κατανοητό. Θα απαντώ πάντα σε μορφή JSON στα Ελληνικά.'},
      ],
    },
  ];

  for (final item in items) {
    final prompt = item['prompt']! as String;
    final cards = item['cards']! as List<dynamic>;
    history.add({
      'role': 'user',
      'parts': [
        {'text': prompt},
      ],
    });
    history.add({
      'role': 'model',
      'parts': [
        {'text': jsonEncode(cards)},
      ],
    });
  }

  return history;
}

/// Strips markdown fences, [jsonDecode]s, and returns encodable card maps (same semantics as the old notifier).
List<Map<String, dynamic>> decodeSmartNotesAiResponseJson(String responseText) {
  var clean = responseText.trim();
  if (clean.startsWith('```json')) {
    clean = clean.substring(7);
    if (clean.endsWith('```')) {
      clean = clean.substring(0, clean.length - 3);
    }
  } else if (clean.startsWith('```')) {
    clean = clean.substring(3);
    if (clean.endsWith('```')) {
      clean = clean.substring(0, clean.length - 3);
    }
  }
  clean = clean.trim();

  final decoded = jsonDecode(clean);
  if (decoded is! List) {
    throw const FormatException('Smart notes: expected top-level JSON array');
  }
  return [for (final e in decoded) Map<String, dynamic>.from(e as Map)];
}

/// Builds the `history` payload for the study-buddy `chatWithAi` callable.
List<Map<String, dynamic>> buildStudyBuddyCallableHistory(
  Map<String, dynamic> args,
) {
  final systemUser = args['systemUser']! as String;
  final rawTurns = args['turns'] as List<dynamic>;
  final turns = rawTurns.cast<Map<String, dynamic>>();

  final history = <Map<String, dynamic>>[
    {
      'role': 'user',
      'parts': [
        {'text': systemUser},
      ],
    },
    {
      'role': 'model',
      'parts': [
        {
          'text':
              'Κατανοητό. Είμαι έτοιμος να σε βοηθήσω ως Σωκρατικός δάσκαλος.',
        },
      ],
    },
  ];

  for (final t in turns) {
    final isUser = t['isUser']! as bool;
    final text = t['text']! as String;
    final imageParts = (t['images'] as List<dynamic>? ?? [])
        .whereType<String>()
        .map(
          (b64) => {
            'inlineData': {'mimeType': 'image/jpeg', 'data': b64},
          },
        )
        .toList();
    history.add({
      'role': isUser ? 'user' : 'model',
      'parts': [
        {'text': text},
        ...imageParts,
      ],
    });
  }

  return history;
}

/// Encodes a list of Uint8List images into a list of base64 strings in the background.
List<String> encodeImagesToBase64(List<Uint8List> images) {
  return [for (final bytes in images) base64Encode(bytes)];
}
