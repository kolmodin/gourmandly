// What a new kitchen starts with. Both lists can be edited in the app.

export type TagCategory =
  | "cuisine"
  | "diet"
  | "effort"
  | "meal"
  | "meatFish"
  | "other";

const defaultTagNames: Record<TagCategory, string[]> = {
  cuisine: [
    "asian",
    "chinese",
    "japanese",
    "korean",
    "thai",
    "vietnamese",
    "indian",
    "middle eastern",
    "mediterranean",
    "italian",
    "french",
    "spanish",
    "greek",
    "nordic",
    "american",
    "mexican",
  ],
  diet: ["vegetarian", "vegan", "pescetarian", "gluten-free", "dairy-free"],
  effort: ["quick", "everyday", "ambitious"],
  meal: [
    "breakfast",
    "lunch",
    "dinner",
    "starter",
    "side",
    "dessert",
    "baking",
    "snack",
    "drink",
  ],
  meatFish: ["chicken", "pork", "beef", "lamb", "game", "fish", "seafood"],
  other: [],
};

export interface DefaultTag {
  id: string;
  name: string;
  category: TagCategory;
  key: string;
}

export const defaultTags: DefaultTag[] = (
  Object.entries(defaultTagNames) as [TagCategory, string[]][]
).flatMap(([category, names]) =>
  names.map((name) => ({
    id: keySlug(`${category} ${name}`),
    name,
    category,
    key: `${category}.${name}`,
  })),
);

// A starting point; deliberately short until the list has been curated.
export const defaultStaples = [
  "water",
  "salt",
  "black pepper",
  "sugar",
  "olive oil",
  "rapeseed oil",
];

/** A key as a document ID, as in the app's `keySlug`. */
export function keySlug(key: string): string {
  return key
    .trim()
    .toLowerCase()
    .replace(/\s+/g, " ")
    .replace(/[\s/.]+/g, "-");
}
