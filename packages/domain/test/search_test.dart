import 'package:domain/domain.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:glados/glados.dart';

import 'support/builders.dart';

const italian = Tag(id: 't1', name: 'italian', category: TagCategory.cuisine);
const thai = Tag(id: 't2', name: 'thai', category: TagCategory.cuisine);
const quick = Tag(id: 't3', name: 'quick', category: TagCategory.effort);
const chicken = Tag(id: 't4', name: 'chicken', category: TagCategory.meatFish);
const pork = Tag(id: 't5', name: 'pork', category: TagCategory.meatFish);
const vegetarian = Tag(
  id: 't6',
  name: 'vegetarian',
  category: TagCategory.diet,
);

final tags = [italian, thai, quick, chicken, pork, vegetarian].lock;

final carbonara = recipe(
  'carbonara',
  [ingredient('pork belly', name: 'pancetta'), ingredient('egg', name: 'ägg')],
  title: 'Spaghetti Carbonara',
  tagIds: ['t1', 't5'],
);
final padThai = recipe(
  'pad-thai',
  [ingredient('chicken breast', name: 'kycklingfilé')],
  title: 'Pad Thai',
  tagIds: ['t2', 't3', 't4'],
);
final soup = recipe(
  'soup',
  [ingredient('onion', name: 'gul lök')],
  title: 'Löksoppa',
  tagIds: ['t6', 't3'],
);

final all = [carbonara, padThai, soup].lock;

List<String> ids(Iterable<Recipe> recipes) => [for (final r in recipes) r.id];

List<String> search({
  String query = '',
  TagFilter filter = const TagFilter(),
}) => ids(searchRecipes(all, tags, query: query, filter: filter));

void main() {
  group('text search', () {
    test('an empty query finds everything', () {
      expect(search(), ['carbonara', 'pad-thai', 'soup']);
      expect(search(query: '   '), ['carbonara', 'pad-thai', 'soup']);
    });

    test('searches titles', () {
      expect(search(query: 'carbonara'), ['carbonara']);
    });

    test('ignores case and accents', () {
      expect(search(query: 'LOKSOPPA'), ['soup']);
      expect(search(query: 'lok'), ['soup']);
      expect(search(query: 'agg'), ['carbonara']);
    });

    test('matches parts of words', () {
      expect(search(query: 'kyckl'), ['pad-thai']);
    });

    test('searches ingredient names and keys', () {
      expect(search(query: 'pancetta'), ['carbonara']);
      expect(search(query: 'chicken breast'), ['pad-thai']);
    });

    test('searches tag names', () {
      expect(search(query: 'vegetarian'), ['soup']);
      expect(search(query: 'quick'), ['pad-thai', 'soup']);
    });

    test('every word has to match, in any field', () {
      expect(search(query: 'spaghetti italian'), ['carbonara']);
      expect(search(query: 'spaghetti thai'), isEmpty);
    });

    test('ignores tag IDs nobody knows', () {
      final orphan = recipe('x', [], title: 'X', tagIds: ['gone']);
      expect(ids(searchRecipes([orphan].lock, tags, query: 'x')), ['x']);
      expect(searchRecipes([orphan].lock, tags, query: 'gone'), isEmpty);
    });
  });

  group('tag filters', () {
    TagFilter filter(Map<TagCategory, CategoryFilter> categories) =>
        TagFilter(categories.lock);

    test('no selection filters nothing', () {
      expect(search(filter: filter({TagCategory.cuisine: AnyOf(ISet())})), [
        'carbonara',
        'pad-thai',
        'soup',
      ]);
    });

    test('within a category any selected tag matches', () {
      expect(
        search(
          filter: filter({
            TagCategory.meatFish: AnyOf({'t4', 't5'}.lock),
          }),
        ),
        ['carbonara', 'pad-thai'],
      );
    });

    test('across categories all must match', () {
      expect(
        search(
          filter: filter({
            TagCategory.meatFish: AnyOf({'t4', 't5'}.lock),
            TagCategory.effort: AnyOf({'t3'}.lock),
          }),
        ),
        ['pad-thai'],
      );
    });

    test('a category can be filtered to none', () {
      expect(search(filter: filter({TagCategory.meatFish: const NoTags()})), [
        'soup',
      ]);
    });

    test('none ignores tags of other categories', () {
      expect(search(filter: filter({TagCategory.cuisine: const NoTags()})), [
        'soup',
      ]);
    });

    test('combines with the text search', () {
      expect(
        search(
          query: 'lök',
          filter: filter({
            TagCategory.effort: AnyOf({'t3'}.lock),
          }),
        ),
        ['soup'],
      );
    });

    test('tagsIn lists the tags of one category', () {
      expect(tagsIn(tags, TagCategory.cuisine), [italian, thai]);
    });
  });

  Glados(any.letters).test('results are always a subset, in order', (query) {
    final found = ids(searchRecipes(all, tags, query: query));
    final expectedOrder = [
      for (final id in ids(all))
        if (found.contains(id)) id,
    ];
    expect(found, expectedOrder);
  });

  Glados2(any.letters, any.letters).test('more words never find more', (
    first,
    second,
  ) {
    final wide = ids(searchRecipes(all, tags, query: first));
    final narrow = ids(searchRecipes(all, tags, query: '$first $second'));
    expect(wide, containsAll(narrow));
  });
}
