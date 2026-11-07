import 'package:domain/domain.dart';
import 'package:glados/glados.dart';

void main() {
  group('foldText', () {
    test('ignores case and accents', () {
      expect(foldText('Lök'), 'lok');
      expect(foldText('KYCKLINGFILÉ'), 'kycklingfile');
      expect(foldText('Crème fraîche'), 'creme fraiche');
      expect(foldText('Åäö'), 'aao');
    });

    test('expands ligatures', () {
      expect(foldText('Æbleskiver'), 'aebleskiver');
      expect(foldText('Œuf'), 'oeuf');
      expect(foldText('Weißbier'), 'weissbier');
    });

    Glados(any.letters).test('is idempotent', (text) {
      expect(foldText(foldText(text)), foldText(text));
    });
  });

  group('normalizeKey', () {
    test('lowercases, trims and collapses whitespace', () {
      expect(normalizeKey('  Black   Pepper '), 'black pepper');
    });

    Glados(any.letters).test('is idempotent', (text) {
      expect(normalizeKey(normalizeKey(text)), normalizeKey(text));
    });
  });

  group('keySlug', () {
    // The same cases as functions/src/defaults.test.ts: the app and the
    // Functions must agree.
    test('makes a key usable as a document ID', () {
      expect(keySlug('black pepper'), 'black-pepper');
      expect(keySlug('Black  Pepper'), 'black-pepper');
      expect(keySlug('salt/peppar'), 'salt%2Fpeppar');
      expect(keySlug('crème fraîche'), 'crème-fraîche');
      expect(keySlug('st. agur'), 'st%2E-agur');
      expect(keySlug('half-and-half'), 'half%2Dand%2Dhalf');
    });

    test('never yields a reserved document ID', () {
      expect(keySlug('.'), '%2E');
      expect(keySlug('..'), '%2E%2E');
      expect(keySlug('__id__'), '%5F%5Fid%5F%5F');
    });

    test('keeps keys that differ only in punctuation apart', () {
      expect(keySlug('half and half'), isNot(keySlug('half-and-half')));
      expect(keySlug('st. agur'), isNot(keySlug('st agur')));
    });

    Glados(any.letters).test('never contains a slash', (text) {
      expect(keySlug('$text/$text').contains('/'), isFalse);
    });

    Glados2(any.nonEmptyLetterOrDigits, any.nonEmptyLetterOrDigits).test(
      'is one-to-one on normalized keys',
      (a, b) {
        final keys = ['$a $b', '$a-$b', '$a.$b', '$a/$b', '$a%2D$b'];
        expect(keys.map(keySlug).toSet(), hasLength(keys.length));
      },
    );
  });

  group('checkDocumentId', () {
    test('combines key and measure', () {
      expect(
        const LineId('black pepper', BaseMeasure.mass).documentId,
        'black-pepper--mass',
      );
      expect(
        const LineId('garlic', NamedMeasure('klyftor')).documentId,
        'garlic--named%3Aklyftor',
      );
    });

    test('a named unit with a slash is still a valid ID', () {
      expect(
        const LineId(
          'tomato',
          NamedMeasure('st/förp'),
        ).documentId.contains('/'),
        isFalse,
      );
    });

    test('differs between measures of one key', () {
      expect(
        const LineId('flour', BaseMeasure.mass).documentId,
        isNot(const LineId('flour', BaseMeasure.volume).documentId),
      );
    });
  });
}
