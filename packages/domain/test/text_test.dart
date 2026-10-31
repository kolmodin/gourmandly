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
    test('makes a key usable as a document ID', () {
      expect(keySlug('black pepper'), 'black-pepper');
      expect(keySlug('Black  Pepper'), 'black-pepper');
      expect(keySlug('salt/peppar'), 'salt-peppar');
      expect(keySlug('crème.fraîche'), 'crème-fraîche');
    });

    test('never yields a reserved document ID', () {
      expect(keySlug('.'), '-');
      expect(keySlug('..'), '-');
    });

    Glados(any.letters).test('never contains a slash', (text) {
      expect(keySlug('$text/$text').contains('/'), isFalse);
    });
  });

  group('checkDocumentId', () {
    test('combines key and measure', () {
      expect(
        const LineId('black pepper', BaseMeasure.mass).documentId,
        'black-pepper--mass',
      );
      expect(
        const LineId('garlic', NamedMeasure('klyftor')).documentId,
        'garlic--named:klyftor',
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
