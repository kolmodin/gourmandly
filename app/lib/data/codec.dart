import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:domain/domain.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';

// Reading is tolerant, as decision 003 requires: missing fields get defaults,
// unknown fields are ignored, and a field of the wrong type counts as missing.

typedef Json = Map<String, dynamic>;

final _epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

String? _string(Object? value) => value is String ? value : null;

int? _int(Object? value) =>
    value is num && value.isFinite ? value.toInt() : null;

DateTime? _time(Object? value) => switch (value) {
  Timestamp() => value.toDate().toUtc(),
  DateTime() => value.toUtc(),
  _ => null,
};

Iterable<String> _strings(Object? value) =>
    value is List ? value.whereType<String>() : const [];

Iterable<Json> _maps(Object? value) => value is List
    ? value.whereType<Map<dynamic, dynamic>>().map(Json.from)
    : const [];

Fraction? decodeFraction(Object? value) {
  if (value is! Map) return null;
  final numerator = _int(value['num']);
  final denominator = _int(value['den']) ?? 1;
  if (numerator == null || denominator == 0) return null;
  return Fraction(numerator, denominator);
}

Json encodeFraction(Fraction value) => {
  'num': value.numerator.toInt(),
  'den': value.denominator.toInt(),
};

Quantity decodeQuantity(Object? value) {
  if (value is! Map) return const Unspecified();
  final exact = decodeFraction(value);
  if (exact != null) return Exact(exact);
  final min = decodeFraction(value['min']);
  final max = decodeFraction(value['max']);
  return min != null && max != null ? Range(min, max) : const Unspecified();
}

Json? encodeQuantity(Quantity quantity) => switch (quantity) {
  Exact(:final value) => encodeFraction(value),
  Range(:final min, :final max) => {
    'min': encodeFraction(min),
    'max': encodeFraction(max),
  },
  Unspecified() => null,
};

Unit? decodeUnit(Object? value) => switch (_string(value)) {
  null || '' => null,
  final symbol => unitFromSymbol(symbol),
};

Ingredient decodeIngredient(Json data, int position) => Ingredient(
  id: _string(data['id']) ?? 'position-$position',
  name: _string(data['name']) ?? _string(data['text']) ?? '',
  key: _string(data['key']) ?? '',
  quantity: decodeQuantity(data['quantity']),
  unit: decodeUnit(data['unit']),
  text: _string(data['text']) ?? '',
  note: _string(data['note']),
  group: _string(data['group']),
);

IList<Ingredient> _ingredients(Object? value) => [
  for (final (position, data) in _maps(value).indexed)
    decodeIngredient(data, position),
].lock;

RecipeImage? _image(Object? value) {
  if (value is! Map) return null;
  final path = _string(value['storagePath']);
  if (path == null) return null;
  return RecipeImage(
    storagePath: path,
    sourceUrl: _string(value['sourceUrl']),
    origin: _string(value['origin']) == 'ai'
        ? ImageOrigin.ai
        : ImageOrigin.page,
  );
}

RecipeOriginal? _original(Object? value) {
  if (value is! Map) return null;
  return RecipeOriginal(
    language: _string(value['language']) ?? '',
    title: _string(value['title']) ?? '',
    ingredients: _ingredients(value['ingredients']),
    steps: _strings(value['steps']).toIList(),
  );
}

Recipe decodeRecipe(String id, Json data) => Recipe(
  id: id,
  title: _string(data['title']) ?? '',
  servings: _int(data['servings']) ?? 0,
  ingredients: _ingredients(data['ingredients']),
  tagIds: _strings(data['tagIds']).toIList(),
  steps: _strings(data['steps']).toIList(),
  language: _string(data['language']),
  original: _original(data['original']),
  sourceUrl: _string(data['sourceUrl']),
  image: _image(data['image']),
  totalTime: _int(data['totalTime']),
  lastCookedAt: _time(data['lastCookedAt']),
  timesCooked: _int(data['timesCooked']) ?? 0,
);

PlannedRecipe decodePlanned(String id, Json data) => PlannedRecipe(
  id: id,
  recipeId: _string(data['recipeId']) ?? '',
  servings: _int(data['servings']) ?? 0,
  addedAt: _time(data['addedAt']) ?? _epoch,
  addedBy: _string(data['addedBy']),
  excluded: _strings(data['excluded']).toISet(),
  done: _strings(data['done']).toISet(),
  shoppedAt: _time(data['shoppedAt']),
  cookingStartedAt: _time(data['cookingStartedAt']),
);

Json encodePlanned(PlannedRecipe entry) => {
  'recipeId': entry.recipeId,
  'servings': entry.servings,
  'addedAt': Timestamp.fromDate(entry.addedAt),
  'addedBy': ?entry.addedBy,
  'excluded': entry.excluded.toList(),
  'done': entry.done.toList(),
  if (entry.shoppedAt case final at?) 'shoppedAt': Timestamp.fromDate(at),
  if (entry.cookingStartedAt case final at?)
    'cookingStartedAt': Timestamp.fromDate(at),
};

ListItem decodeListItem(String id, Json data) => ListItem(
  id: id,
  name: _string(data['name']) ?? _string(data['text']) ?? '',
  addedAt: _time(data['addedAt']) ?? _epoch,
  addedBy: _string(data['addedBy']),
  key: _string(data['key']),
  quantity: decodeQuantity(data['quantity']),
  unit: decodeUnit(data['unit']),
);

Json encodeListItem(ListItem item) => {
  'name': item.name,
  'addedAt': Timestamp.fromDate(item.addedAt),
  'addedBy': ?item.addedBy,
  'key': ?item.key,
  'quantity': encodeQuantity(item.quantity),
  'unit': item.unit?.symbol,
};

Check? decodeCheck(Json data) {
  final key = _string(data['key']);
  if (key == null) return null;
  return Check(
    line: LineId(key, measureFromId(_string(data['dimension']) ?? 'none')),
    at: _time(data['checkedAt']) ?? _epoch,
    quantity: decodeFraction(data['checkedQuantity']),
    by: _string(data['checkedBy']),
  );
}

Json encodeCheck(Check check) => {
  'key': check.line.key,
  'dimension': check.line.measure.id,
  if (check.quantity case final quantity?)
    'checkedQuantity': encodeFraction(quantity),
  'checkedAt': Timestamp.fromDate(check.at),
  'checkedBy': ?check.by,
};

IMap<String, String> _memberNames(Object? value) => value is Map
    ? {
        for (final MapEntry(:key, :value) in value.entries)
          if (key is String && value is String) key: value,
      }.lock
    : const IMapConst({});

Tag decodeTag(String id, Json data) => Tag(
  id: id,
  name: _string(data['name']) ?? '',
  category: TagCategory.values.firstWhere(
    (category) => category.name == data['category'],
    orElse: () => TagCategory.other,
  ),
  key: _string(data['key']),
);

Kitchen decodeKitchen(String id, Json data) => Kitchen(
  id: id,
  name: _string(data['name']) ?? '',
  ownerId: _string(data['ownerId']) ?? '',
  memberIds: _strings(data['memberIds']).toIList(),
  memberNames: _memberNames(data['memberNames']),
  language: _string(data['language']) ?? 'en',
);
