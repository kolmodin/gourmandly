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

/// [key] as a document ID: Firestore IDs can't contain a slash and can't be
/// `.` or `..`.
String keySlug(String key) =>
    normalizeKey(key).replaceAll(RegExp(r'[\s/.]+'), '-');
