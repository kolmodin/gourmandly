import 'dart:convert';

const _folds = {
  'à': 'a',
  'á': 'a',
  'â': 'a',
  'ã': 'a',
  'ä': 'a',
  'å': 'a',
  'ā': 'a',
  'æ': 'ae',
  'ç': 'c',
  'è': 'e',
  'é': 'e',
  'ê': 'e',
  'ë': 'e',
  'ē': 'e',
  'ì': 'i',
  'í': 'i',
  'î': 'i',
  'ï': 'i',
  'ī': 'i',
  'ñ': 'n',
  'ò': 'o',
  'ó': 'o',
  'ô': 'o',
  'õ': 'o',
  'ö': 'o',
  'ø': 'o',
  'ō': 'o',
  'œ': 'oe',
  'ß': 'ss',
  'ù': 'u',
  'ú': 'u',
  'û': 'u',
  'ü': 'u',
  'ū': 'u',
  'ý': 'y',
  'ÿ': 'y',
};

/// [text] without case or accents, so that `lok` finds `Lök`.
String foldText(String text) {
  final buffer = StringBuffer();
  for (final rune in text.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_folds[char] ?? char);
  }
  return buffer.toString();
}

/// The canonical spelling of an ingredient key.
String normalizeKey(String key) =>
    key.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

final _plain = RegExp(r'[\p{L}\p{N}]', unicode: true);

/// [key] as a document ID, readable and without losing anything: letters and
/// digits stay, spaces become `-`, and everything else is percent-encoded, so
/// `half and half` and `half-and-half` get IDs of their own. Firestore IDs
/// can't contain a slash, be `.` or `..`, or look like `__id__`. The Functions
/// have the same function, in `defaults.ts`.
String keySlug(String key) {
  final buffer = StringBuffer();
  for (final rune in normalizeKey(key).runes) {
    final char = String.fromCharCode(rune);
    if (char == ' ') {
      buffer.write('-');
    } else if (_plain.hasMatch(char)) {
      buffer.write(char);
    } else {
      for (final byte in utf8.encode(char)) {
        buffer.write(
          '%${byte.toRadixString(16).toUpperCase().padLeft(2, '0')}',
        );
      }
    }
  }
  return buffer.toString();
}
